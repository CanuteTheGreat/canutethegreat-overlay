# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="Service wrapper (OpenRC supervise-daemon + systemd unit) for a remotely-managed Cloudflare tunnel connector (net-vpn/cloudflared)"
HOMEPAGE="https://git.canutethegreat.com/CanuteTheGreat/ctg-infrastructure"
S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RDEPEND="net-vpn/cloudflared"

src_install() {
	newinitd "${FILESDIR}"/ctg-cloudflared.initd ctg-cloudflared
	newconfd "${FILESDIR}"/ctg-cloudflared.confd ctg-cloudflared
	systemd_newunit "${FILESDIR}"/ctg-cloudflared.service ctg-cloudflared.service
}

pkg_postinst() {
	elog "The tunnel token is never packaged: write it to /etc/conf.d/ctg-cloudflared (TUNNEL_TOKEN=...), mode 0600 root, then"
	elog "  rc-update add ctg-cloudflared default && rc-service ctg-cloudflared start"
}
