# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit fcaps go-module systemd tmpfiles flag-o-matic

DESCRIPTION="A self-hosted lightweight software forge (built from the upstream source tarball)"
HOMEPAGE="https://forgejo.org/ https://codeberg.org/forgejo/forgejo"
SRC_URI="https://codeberg.org/forgejo/forgejo/releases/download/v${PV}/forgejo-src-${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-src-${PV}"

LICENSE="Apache-2.0 BSD BSD-2 ISC MIT MPL-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+acct pam +sqlite pie"
# the source tarball already carries the compiled web assets and the vendored Go modules
RESTRICT="test"

DEPEND="
	acct? (
		acct-group/git
		acct-user/git[gitea]
	)
	pam? ( sys-libs/pam )
"
RDEPEND="${DEPEND}
	>=dev-vcs/git-2.34.1
	!www-apps/gitea
"
BDEPEND=">=dev-lang/go-1.26.9"

DOCS=( custom/conf/app.example.ini CONTRIBUTING.md README.md )
FILECAPS=( -m 711 cap_net_bind_service+ep usr/bin/forgejo )

src_prepare() {
	default
	local sedcmds=(
		-e "s#^ROOT =#ROOT = ${EPREFIX}/var/lib/gitea/gitea-repositories#"
		-e "s#^ROOT_PATH =#ROOT_PATH = ${EPREFIX}/var/log/forgejo#"
		-e "s#^APP_DATA_PATH = data#APP_DATA_PATH = ${EPREFIX}/var/lib/gitea/data#"
		-e "s#^HTTP_ADDR = 0.0.0.0#HTTP_ADDR = 127.0.0.1#"
		-e "s#^MODE = console#MODE = file#"
		-e "s#^LEVEL = Trace#LEVEL = Info#"
		-e "s#^LOG_SQL = true#LOG_SQL = false#"
		-e "s#^DISABLE_ROUTER_LOG = false#DISABLE_ROUTER_LOG = true#"
	)
	sed -i "${sedcmds[@]}" custom/conf/app.example.ini || die
	use sqlite && { sed -i -e "s#^DB_TYPE = .*#DB_TYPE = sqlite3#" custom/conf/app.example.ini || die; }
}

src_configure() {
	# bug 832756: -fPIE conflicts with Go's own -buildmode=pie
	filter-flags -fPIE
	filter-ldflags -fPIE -pie
}

src_compile() {
	local tags=( bindata $(usev pam) $(usex sqlite 'sqlite sqlite_unlock_notify' '') )
	local settings=(
		"-X forgejo.org/modules/setting.CustomConf=${EPREFIX}/etc/forgejo/app.ini"
		"-X forgejo.org/modules/setting.CustomPath=${EPREFIX}/var/lib/gitea/custom"
		"-X forgejo.org/modules/setting.AppWorkPath=${EPREFIX}/var/lib/gitea"
	)
	local goflags=""
	use pie && goflags="-buildmode=pie"
	# -j1: upstream's Makefile races between targets (the Go compiler is still parallel)
	env DRONE_TAG="${PV}" LDFLAGS="-extldflags \"${LDFLAGS}\" ${settings[*]}" TAGS="${tags[*]}" \
		emake -j1 EXTRA_GOFLAGS="${goflags}" STRIP=0 backend
}

src_install() {
	newbin gitea forgejo
	einstalldocs

	newconfd "${FILESDIR}/forgejo.confd" forgejo
	newinitd "${FILESDIR}/forgejo.initd" forgejo
	systemd_newunit "${FILESDIR}/forgejo.service" forgejo.service
	newtmpfiles - forgejo.conf <<-EOF
		d /run/forgejo 0755 git git
	EOF

	insinto /etc/forgejo
	newins custom/conf/app.example.ini app.ini
	if use acct; then
		fowners root:git /etc/forgejo/{,app.ini}
		fperms g+w,o-rwx /etc/forgejo/{,app.ini}
		diropts -m0750 -o git -g git
		keepdir /var/lib/gitea /var/lib/gitea/custom /var/lib/gitea/data /var/log/forgejo
	fi
}

pkg_postinst() {
	fcaps_pkg_postinst
	tmpfiles_process forgejo.conf
	elog "Forgejo reads /etc/forgejo/app.ini and keeps its data in /var/lib/gitea (user/group git)."
	elog "OpenRC: rc-update add forgejo default; systemd: systemctl enable --now forgejo."
	elog "Back up the database and /var/lib/gitea before every major version bump (v15 -> v16 -> v17 migrate the schema)."
}
