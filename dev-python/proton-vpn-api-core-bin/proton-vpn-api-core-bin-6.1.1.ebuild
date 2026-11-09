# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
inherit python-r1 systemd unpacker

DESCRIPTION="Proton VPN API core (prebuilt: python + Rust platform library, kill switch, protun service)"
HOMEPAGE="https://github.com/ProtonVPN/python-proton-vpn-api-core https://protonvpn.com/support/official-linux-vpn-debian"
# Binary on purpose: 6.x links a Rust library (platform.abi3.so) and two services whose crates
# ("proton" private cargo registry, dependencies/protun) are not in the public source tarball,
# so it cannot be built from source. Proton publishes this exact .deb in its own apt repo.
SRC_URI="https://repo.protonvpn.com/debian/dists/stable/main/binary-amd64/python3-proton-vpn-api-core_${PV}_amd64.deb"
S="${WORKDIR}"

# python is GPL-3 (debian/copyright); the Rust parts are Proton's, source not public.
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="-* ~amd64"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"
RESTRICT="mirror strip"
QA_PREBUILT="usr/libexec/* usr/lib*/python3*/site-packages/proton/vpn/platform.abi3.so"

RDEPEND="
	${PYTHON_DEPS}
	net-libs/libnftnl
	net-libs/libmnl
	net-misc/networkmanager[introspection]
	net-vpn/networkmanager-openvpn
	sys-apps/systemd
	sys-auth/polkit
	sys-apps/dbus
	dev-python/cryptography[${PYTHON_USEDEP}]
	dev-python/dbus-fast[${PYTHON_USEDEP}]
	dev-python/distro[${PYTHON_USEDEP}]
	dev-python/fido2[${PYTHON_USEDEP}]
	dev-python/jinja2[${PYTHON_USEDEP}]
	dev-python/packaging[${PYTHON_USEDEP}]
	dev-python/pycairo[${PYTHON_USEDEP}]
	dev-python/pygobject[${PYTHON_USEDEP}]
	dev-python/pynacl[${PYTHON_USEDEP}]
	dev-python/proton-core[${PYTHON_USEDEP}]
	dev-python/sentry-sdk[${PYTHON_USEDEP}]
"

src_unpack() {
	unpack_deb "${DISTDIR}/python3-proton-vpn-api-core_${PV}_amd64.deb"
}

src_install() {
	local src=usr/lib/python3/dist-packages/proton
	# the egg-info carries the entry points (proton_loader_killswitch: default/wireguard/firewall) the app loads at runtime
	local meta=usr/lib/python3/dist-packages/proton_vpn_api_core-${PV}.egg-info
	install_module() {
		insinto "$(python_get_sitedir)"
		doins -r "${src}" "${meta}"
		# the abi3 library is loaded as a module: keep it executable
		fperms 0755 "$(python_get_sitedir)/proton/vpn/platform.abi3.so"
		python_optimize "${ED}$(python_get_sitedir)/proton"
	}
	python_foreach_impl install_module

	exeinto /usr/libexec
	doexe usr/libexec/proton-vpn-kill-switch-service usr/libexec/nm-protun-service usr/libexec/proton-vpn-disable-kill-switch

	# NetworkManager looks for VPN plugin descriptions in $(libdir)/NetworkManager/VPN and /etc/NetworkManager/VPN
	insinto /etc/NetworkManager/VPN
	doins usr/lib/NetworkManager/VPN/nm-protun.name
	insinto /usr/share/dbus-1/system.d
	doins usr/share/dbus-1/system.d/*.conf
	insinto /usr/share/dbus-1/system-services
	doins usr/share/dbus-1/system-services/*.service
	insinto /usr/share/polkit-1/actions
	doins usr/share/polkit-1/actions/*.policy
	systemd_dounit lib/systemd/system/proton-vpn-kill-switch-boot.service
}
