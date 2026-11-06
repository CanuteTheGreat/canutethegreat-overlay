# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
inherit meson python-any-r1 systemd tmpfiles

DESCRIPTION="Reliable PostgreSQL backup and restore (parallel, incremental, S3/B2/SFTP repositories)"
HOMEPAGE="https://pgbackrest.org/ https://github.com/pgbackrest/pgbackrest"
SRC_URI="https://github.com/pgbackrest/pgbackrest/archive/release/${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-release-${PV}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+ssh systemd +zstd"
# upstream's test suite drives containers of many PostgreSQL versions
RESTRICT="test"

DEPEND="
	app-arch/bzip2
	app-arch/lz4
	dev-db/postgresql:*
	dev-libs/libxml2:=
	dev-libs/openssl:=
	virtual/zlib:=
	ssh? ( net-libs/libssh2 )
	systemd? ( sys-apps/systemd )
	zstd? ( app-arch/zstd:= )
"
RDEPEND="${DEPEND}
	acct-group/postgres
	acct-user/postgres
"
BDEPEND="
	$(python_gen_any_dep 'dev-python/pyyaml[${PYTHON_USEDEP}]')
	virtual/pkgconfig
"

python_check_deps() {
	python_has_version "dev-python/pyyaml[${PYTHON_USEDEP}]"
}

pkg_setup() {
	python-any-r1_pkg_setup
}

src_configure() {
	local emesonargs=(
		$(meson_feature ssh libssh2)
		$(meson_feature systemd libsystemd)
		$(meson_feature zstd libzstd)
	)
	meson_src_configure
}

src_install() {
	meson_src_install

	# conf: both /etc/pgbackrest.conf and /etc/pgbackrest/pgbackrest.conf are read by pgbackrest
	diropts -m0750 -o postgres -g postgres
	keepdir /etc/pgbackrest/conf.d /var/log/pgbackrest /var/spool/pgbackrest /var/lib/pgbackrest
	insinto /etc/pgbackrest
	newins - pgbackrest.conf.example <<-EOF
		# Minimal example; see https://pgbackrest.org/configuration.html
		[global]
		repo1-path=/var/lib/pgbackrest
		repo1-retention-full=2
		log-path=/var/log/pgbackrest
		spool-path=/var/spool/pgbackrest

		[main]
		pg1-path=/var/lib/postgresql/data
	EOF

	# TLS server (only needed for remote repositories / backup hosts); not enabled by default
	newinitd "${FILESDIR}/pgbackrest.initd" pgbackrest
	newconfd "${FILESDIR}/pgbackrest.confd" pgbackrest
	systemd_dounit "${FILESDIR}/pgbackrest.service"
	newtmpfiles - pgbackrest.conf <<-EOF
		d /var/spool/pgbackrest 0750 postgres postgres -
		d /var/log/pgbackrest 0750 postgres postgres -
	EOF
}

pkg_postinst() {
	tmpfiles_process pgbackrest.conf
	elog "pgbackrest runs as the postgres user. Edit /etc/pgbackrest.conf (or /etc/pgbackrest/pgbackrest.conf)."
	elog "The pgbackrest service (TLS server) is only needed for remote repository hosts and is not enabled."
}
