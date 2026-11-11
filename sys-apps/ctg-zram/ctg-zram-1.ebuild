# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="OpenRC zram swap service for azkaban guests"
HOMEPAGE="https://git.canutethegreat.com/CanuteTheGreat/canutethegreat-overlay"
S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	sys-apps/openrc
	sys-apps/util-linux
	sys-apps/kmod
"

src_install() {
	newinitd "${FILESDIR}"/ctg-zram.initd ctg-zram
}
