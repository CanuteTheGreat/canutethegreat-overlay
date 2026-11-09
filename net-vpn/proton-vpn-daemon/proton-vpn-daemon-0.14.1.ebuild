# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )
inherit distutils-r1 systemd

DESCRIPTION="Proton VPN daemon: per-app split tunneling service (D-Bus, eBPF)"
HOMEPAGE="https://github.com/ProtonVPN/proton-vpn-daemon"
SRC_URI="https://github.com/ProtonVPN/proton-vpn-daemon/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="test"

RDEPEND="
	dev-python/dbus-fast[${PYTHON_USEDEP}]
	dev-python/packaging[${PYTHON_USEDEP}]
	dev-python/proton-vpn-api-core-bin[${PYTHON_USEDEP}]
	dev-python/psutil[${PYTHON_USEDEP}]
	dev-python/python-systemd[${PYTHON_USEDEP}]
	dev-util/bcc[python,${PYTHON_USEDEP}]
	net-vpn/wireguard-tools
	sys-apps/dbus
	sys-apps/systemd
"

python_install_all() {
	distutils-r1_python_install_all
	insinto /usr/share/dbus-1/system.d
	newins rpmbuild/SOURCES/dbus.conf me.proton.vpn.split_tunneling.conf
	insinto /usr/share/dbus-1/system-services
	newins rpmbuild/SOURCES/dbus.service me.proton.vpn.split_tunneling.service
	# the unit starts `python3 -m proton.vpn.daemon`: pin it to the interpreter the modules were installed for
	sed -e "s|/usr/bin/python3|${PYTHON}|" rpmbuild/SOURCES/systemd.service > "${T}/me.proton.vpn.split_tunneling.service" || die
	systemd_dounit "${T}/me.proton.vpn.split_tunneling.service"
}

pkg_postinst() {
	elog "Enable the split tunneling service: systemctl enable --now me.proton.vpn.split_tunneling.service"
}
