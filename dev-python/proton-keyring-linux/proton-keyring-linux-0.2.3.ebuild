# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )
inherit distutils-r1

DESCRIPTION="Proton keyring backend for Linux (Secret Service / libsecret)"
HOMEPAGE="https://github.com/ProtonVPN/python-proton-keyring-linux"
SRC_URI="https://github.com/ProtonVPN/python-proton-keyring-linux/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"
S="${WORKDIR}/python-proton-keyring-linux-${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="test"

RDEPEND="
	dev-python/keyring[${PYTHON_USEDEP}]
	dev-python/proton-core[${PYTHON_USEDEP}]
	dev-python/secretstorage[${PYTHON_USEDEP}]
	gnome-base/gnome-keyring
"
