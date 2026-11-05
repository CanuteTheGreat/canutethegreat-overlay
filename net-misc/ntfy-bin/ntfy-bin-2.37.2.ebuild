# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="Send push notifications to your phone via PUT/POST (server + client, upstream binary)"
HOMEPAGE="https://ntfy.sh/ https://github.com/binwiederhier/ntfy"
SRC_URI="
	amd64? ( https://github.com/binwiederhier/ntfy/releases/download/v${PV}/ntfy_${PV}_linux_amd64.tar.gz )
	arm64? ( https://github.com/binwiederhier/ntfy/releases/download/v${PV}/ntfy_${PV}_linux_arm64.tar.gz )
"
S="${WORKDIR}"

LICENSE="|| ( Apache-2.0 GPL-2 )"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="strip"
QA_PREBUILT="usr/bin/ntfy"

RDEPEND="
	acct-group/ntfy
	acct-user/ntfy
	!net-misc/ntfy
"

src_install() {
	local d="${WORKDIR}/ntfy_${PV}_linux_$(usex amd64 amd64 arm64)"
	dobin "${d}/ntfy"
	dodoc "${d}/README.md"

	insinto /etc/ntfy
	doins "${d}/server/server.yml" "${d}/client/client.yml"

	systemd_dounit "${d}/server/ntfy.service"
	systemd_douserunit "${d}/client/user/ntfy-client.service"
	newinitd "${FILESDIR}/ntfy.initd" ntfy
	newconfd "${FILESDIR}/ntfy.confd" ntfy

	diropts -m0750 -o ntfy -g ntfy
	keepdir /var/lib/ntfy /var/cache/ntfy /var/log/ntfy
}

pkg_postinst() {
	elog "Server config: /etc/ntfy/server.yml (all options commented out; set base-url, cache-file, auth-file under /var/lib/ntfy)."
	elog "Client config: /etc/ntfy/client.yml, or ~/.config/ntfy/client.yml for the per-user ntfy-client service."
}
