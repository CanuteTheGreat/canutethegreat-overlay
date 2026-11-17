# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )
inherit desktop distutils-r1 xdg

DESCRIPTION="Proton VPN GTK4 desktop app (GNOME): connect, kill switch, split tunneling"
HOMEPAGE="https://github.com/ProtonVPN/proton-vpn-gtk-app https://protonvpn.com/"
SRC_URI="https://github.com/ProtonVPN/proton-vpn-gtk-app/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="test"

RDEPEND="
	gui-libs/gtk:4[introspection]
	gnome-base/librsvg
	net-misc/networkmanager[introspection]
	x11-libs/libnotify[introspection]
	dev-python/dbus-python[${PYTHON_USEDEP}]
	dev-python/distro[${PYTHON_USEDEP}]
	dev-python/packaging[${PYTHON_USEDEP}]
	dev-python/proton-core[${PYTHON_USEDEP}]
	dev-python/proton-keyring-linux[${PYTHON_USEDEP}]
	dev-python/proton-vpn-api-core-bin[${PYTHON_USEDEP}]
	dev-python/pycairo[${PYTHON_USEDEP}]
	dev-python/pygobject[${PYTHON_USEDEP}]
	dev-python/requests[${PYTHON_USEDEP}]
	net-vpn/proton-vpn-daemon[${PYTHON_USEDEP}]
"
BDEPEND="sys-devel/gettext"

src_install() {
	distutils-r1_src_install
	domenu rpmbuild/SOURCES/proton.vpn.app.gtk.desktop
	insinto /usr/share/icons/hicolor/scalable/apps
	doins rpmbuild/SOURCES/proton-vpn-logo.svg
}
