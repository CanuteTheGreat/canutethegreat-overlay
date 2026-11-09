# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )
inherit distutils-r1

DESCRIPTION="Proton AG core library (sessions, SRP login, keyring loader) used by Proton VPN"
HOMEPAGE="https://github.com/ProtonVPN/python-proton-core"
SRC_URI="https://github.com/ProtonVPN/python-proton-core/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"
S="${WORKDIR}/python-proton-core-${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="test" # needs the Proton API (live servers)

RDEPEND="
	dev-python/aiohttp[${PYTHON_USEDEP}]
	dev-python/bcrypt[${PYTHON_USEDEP}]
	dev-python/pyopenssl[${PYTHON_USEDEP}]
	dev-python/python-gnupg[${PYTHON_USEDEP}]
	dev-python/requests[${PYTHON_USEDEP}]
"
