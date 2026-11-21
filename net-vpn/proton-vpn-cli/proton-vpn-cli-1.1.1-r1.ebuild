# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )
inherit distutils-r1

DESCRIPTION="Proton VPN command line client (protonvpn)"
HOMEPAGE="https://github.com/ProtonVPN/proton-vpn-cli"
SRC_URI="https://github.com/ProtonVPN/proton-vpn-cli/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE="systemd"
RESTRICT="test"

# split tunneling: the daemon is a systemd service (python-systemd, sd units); OpenRC systems run without it
RDEPEND="
	dev-python/click[${PYTHON_USEDEP}]
	dev-python/dbus-fast[${PYTHON_USEDEP}]
	dev-python/packaging[${PYTHON_USEDEP}]
	dev-python/proton-core[${PYTHON_USEDEP}]
	dev-python/proton-keyring-linux[${PYTHON_USEDEP}]
	dev-python/proton-vpn-api-core-bin[${PYTHON_USEDEP}]
	dev-python/tabulate[${PYTHON_USEDEP}]
	systemd? ( net-vpn/proton-vpn-daemon[${PYTHON_USEDEP}] )
"
