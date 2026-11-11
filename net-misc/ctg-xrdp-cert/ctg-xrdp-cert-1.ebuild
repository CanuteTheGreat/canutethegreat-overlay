# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Issue/renew the xrdp TLS certificate from a private home CA (daily cron)"
HOMEPAGE="https://git.canutethegreat.com/CanuteTheGreat/canutethegreat-overlay"
S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	dev-libs/openssl
	net-misc/xrdp
	sys-process/cronie
"

src_install() {
	dosbin "${FILESDIR}"/ctg-xrdp-cert
	exeinto /etc/cron.daily
	newexe "${FILESDIR}"/ctg-xrdp-cert.cron ctg-xrdp-cert
}

pkg_postinst() {
	# Idempotent: only (re)issues when the leaf is missing, near expiry or SANs changed.
	"${EROOT}"/usr/sbin/ctg-xrdp-cert || ewarn "ctg-xrdp-cert failed; run it by hand"
}
