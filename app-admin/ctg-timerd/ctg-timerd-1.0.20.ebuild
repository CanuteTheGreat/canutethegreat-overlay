# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="OpenRC stand-in for systemd timers (used by the ctg-ops / yes-site init scripts)"
HOMEPAGE="https://git.canutethegreat.com/CanuteTheGreat/ctg-infrastructure"
SRC_URI="https://git.canutethegreat.com/api/packages/CanuteTheGreat/generic/ctg-timerd/${PV}/ctg-timerd-${PV}.tar.gz"
S="${WORKDIR}/ctg-timerd-${PV}"
KEYWORDS="~amd64 ~arm64"
LICENSE="all-rights-reserved"
RESTRICT="mirror"
SLOT="0"

RDEPEND="dev-lang/python"

src_install() {
	local f="${S}/packaging/gentoo/ctg-ops/ctg-timerd"
	dobin "${f}"
	keepdir /var/lib/ctg-timerd
}
