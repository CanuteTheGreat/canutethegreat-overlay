# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker

DESCRIPTION="Nextcloud Whiteboard websocket server (upstream tag v1.5.0 + production npm deps, repacked from the ctg Debian package)"
HOMEPAGE="https://github.com/nextcloud/whiteboard"
# the deb is built by ctg-infrastructure packaging/nextcloud-whiteboard from the pinned upstream tag (arch=all: JS only)
SRC_URI="https://git.canutethegreat.com/api/packages/CanuteTheGreat/debian/pool/stable/main/nextcloud-whiteboard_${PV}-0ctg1_all.deb -> ${P}.deb"
S="${WORKDIR}"

LICENSE="AGPL-3+"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
RESTRICT="mirror strip"

RDEPEND="
	>=net-libs/nodejs-18
"

src_unpack() { unpack_deb "${DISTDIR}/${P}.deb"; }

src_install() {
	insinto /usr/lib/nextcloud-whiteboard
	doins -r usr/lib/nextcloud-whiteboard/.
	# the .deb ships it gzipped
	gzip -dc usr/share/doc/nextcloud-whiteboard/LICENSE.AGPL.gz > "${T}"/LICENSE.AGPL || die
	dodoc "${T}"/LICENSE.AGPL
	newinitd "${FILESDIR}"/nextcloud-whiteboard.initd nextcloud-whiteboard
	newconfd "${FILESDIR}"/nextcloud-whiteboard.confd nextcloud-whiteboard
	keepdir /etc/nextcloud-whiteboard
}

pkg_postinst() {
	elog "Secrets are never packaged: chown root:www-data + chmod 0750 /etc/nextcloud-whiteboard, write /etc/nextcloud-whiteboard/env (root:www-data 0640) with JWT_SECRET_KEY, NEXTCLOUD_URL, PORT"
	elog "then: rc-update add nextcloud-whiteboard default && rc-service nextcloud-whiteboard start"
}
