# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="goofys mount of the B2 bucket ctg-media at /mnt/ctg-media for the Jellyfin/Plex containers (OpenRC + systemd)"
HOMEPAGE="https://git.canutethegreat.com/CanuteTheGreat/ctg-infrastructure"
S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RDEPEND="net-fs/goofys"

src_install() {
	newinitd "${FILESDIR}"/ctg-media-mount.initd ctg-media-mount
	newconfd "${FILESDIR}"/ctg-media-mount.confd ctg-media-mount
	systemd_dounit "${FILESDIR}"/ctg-media-mount.service
	keepdir /mnt/ctg-media
}

pkg_postinst() {
	elog "No credentials are packaged: put the B2 key (profile [default]) in /root/.aws/credentials, 0600."
	elog "Set ctg_uid/ctg_gid in /etc/conf.d/ctg-media-mount to the media server's account, then: rc-update add ctg-media-mount default"
}
