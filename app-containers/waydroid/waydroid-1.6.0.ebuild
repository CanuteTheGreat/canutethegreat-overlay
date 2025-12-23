# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )

inherit linux-info python-single-r1 systemd xdg

DESCRIPTION="Container-based approach to boot a full Android system on Linux"
HOMEPAGE="https://waydro.id/ https://github.com/waydroid/waydroid"
SRC_URI="https://github.com/waydroid/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+apparmor clipboard +nftables +openrc systemd"

REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
	|| ( openrc systemd )
"

RDEPEND="
	${PYTHON_DEPS}
	app-containers/lxc[apparmor?,seccomp]
	$(python_gen_cond_dep '
		dev-python/dbus-python[${PYTHON_USEDEP}]
		>=dev-python/gbinder-1.1.2[${PYTHON_USEDEP}]
		dev-python/pygobject:3[${PYTHON_USEDEP}]
		clipboard? ( >=dev-python/pyclip-0.7.0[${PYTHON_USEDEP},wayland] )
	')
	>=dev-libs/gbinder-1.1.21
	>=dev-libs/libglibutil-1.0.67
	net-dns/dnsmasq
	nftables? ( net-firewall/nftables )
	!nftables? ( net-firewall/iptables )
"

BDEPEND="${PYTHON_DEPS}"

# Kernel configuration requirements for Waydroid
# All options use ~ prefix (warnings only, do not block installation)
# Note: ASHMEM was removed in kernel 5.18 and replaced by MEMFD_CREATE
CONFIG_CHECK="
	~ANDROID_BINDER_IPC
	~ANDROID_BINDERFS
	~MEMFD_CREATE
	~PSI
	~BLK_DEV_LOOP
	~NETFILTER_XT_MATCH_COMMENT
	~NETFILTER_XT_TARGET_CHECKSUM
	~NETFILTER_XT_TARGET_MASQUERADE
"

# Warning messages for kernel options
WARNING_ANDROID_BINDER_IPC="CONFIG_ANDROID_BINDER_IPC is REQUIRED! Enable: Device Drivers -> Android -> Android Binder IPC Driver"
WARNING_ANDROID_BINDERFS="CONFIG_ANDROID_BINDERFS is REQUIRED! Enable: Device Drivers -> Android -> Android Binderfs filesystem"
WARNING_MEMFD_CREATE="CONFIG_MEMFD_CREATE is REQUIRED! (replacement for deprecated ASHMEM)"
WARNING_PSI="CONFIG_PSI (Pressure Stall Information) is recommended for Waydroid"
WARNING_BLK_DEV_LOOP="CONFIG_BLK_DEV_LOOP is required for loop device support (build as module or built-in)"
WARNING_NETFILTER_XT_MATCH_COMMENT="CONFIG_NETFILTER_XT_MATCH_COMMENT is recommended for container networking"
WARNING_NETFILTER_XT_TARGET_CHECKSUM="CONFIG_NETFILTER_XT_TARGET_CHECKSUM is recommended for container networking"
WARNING_NETFILTER_XT_TARGET_MASQUERADE="CONFIG_NETFILTER_XT_TARGET_MASQUERADE is recommended for container networking"

pkg_setup() {
	linux-info_pkg_setup
	python-single-r1_pkg_setup
}

src_install() {
	local mymakeflags=(
		DESTDIR="${ED}"
		PREFIX="/usr"
		USE_NFTABLES="$(usex nftables 1 0)"
		USE_SYSTEMD="$(usex systemd 1 0)"
	)

	emake "${mymakeflags[@]}" install

	if use apparmor; then
		emake "${mymakeflags[@]}" install_apparmor
	fi

	# Fix Python shebang to use the selected interpreter
	python_fix_shebang "${ED}/usr/lib/waydroid"

	# Install OpenRC init script
	if use openrc; then
		newinitd "${FILESDIR}/waydroid.initd" waydroid
	fi

	# Remove systemd files if not using systemd
	if ! use systemd; then
		rm -rf "${ED}/usr/lib/systemd" || die
	fi

	einstalldocs
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "Waydroid has been installed successfully."
	elog ""
	ewarn "=== KERNEL CONFIGURATION REQUIRED ==="
	ewarn ""
	ewarn "Waydroid requires specific kernel options. Enable these in your kernel config:"
	ewarn ""
	ewarn "  Device Drivers --->"
	ewarn "    Android --->"
	ewarn "      <*> Android Binder IPC Driver        (CONFIG_ANDROID_BINDER_IPC)"
	ewarn "      <*> Android Binderfs filesystem      (CONFIG_ANDROID_BINDERFS)"
	ewarn ""
	ewarn "  General setup --->"
	ewarn "    <*> Memfd support                      (CONFIG_MEMFD_CREATE)"
	ewarn "    [*] Pressure stall information         (CONFIG_PSI)"
	ewarn ""
	ewarn "  Device Drivers --->"
	ewarn "    Block devices --->"
	ewarn "      <M> Loopback device support          (CONFIG_BLK_DEV_LOOP)"
	ewarn ""
	ewarn "=== Optional Kernel Parameters ==="
	ewarn "These are usually NOT required with binderfs, but may help if issues occur:"
	ewarn ""
	ewarn "  psi=1                                    (if CONFIG_PSI_DEFAULT_DISABLED=y)"
	ewarn "  binder.devices=binder,hwbinder,vndbinder (only if binderfs fails)"
	ewarn ""
	elog "=== Initial Setup ==="
	elog "1. Rebuild your kernel with the options above and reboot."
	elog ""
	elog "2. Initialize Waydroid as root:"
	elog "   # waydroid init"
	elog ""
	elog "   For Google Apps support, use:"
	elog "   # waydroid init -s GAPPS"
	elog ""
	elog "=== Starting the Service ==="
	if use systemd; then
		elog "With systemd:"
		elog "   # systemctl enable --now waydroid-container.service"
	fi
	if use openrc; then
		elog "With OpenRC:"
		elog "   # rc-update add waydroid default"
		elog "   # rc-service waydroid start"
	fi
	elog ""
	elog "=== Running Waydroid ==="
	elog "As a regular user in a Wayland session:"
	elog "   $ waydroid session start"
	elog ""
	elog "Or use the full UI:"
	elog "   $ waydroid show-full-ui"
	elog ""
	elog "=== Important Notes ==="
	elog "- Waydroid ONLY works in Wayland sessions (not X11)"
	elog "- Intel and AMD GPUs work out of the box"
	elog "- NVIDIA GPUs require software rendering (limited support)"
	if ! use nftables; then
		ewarn ""
		ewarn "You have disabled nftables support. Make sure iptables"
		ewarn "is properly configured for Waydroid networking."
	fi
	if use apparmor; then
		elog ""
		elog "AppArmor profiles have been installed. You may need to"
		elog "reload AppArmor profiles or reboot for them to take effect."
	fi
	elog ""
	elog "For more information, visit: https://docs.waydro.id/"
	ewarn ""
	ewarn "Note: For full notification support with images, gbinder-python 1.3.0+"
	ewarn "is recommended. If you experience crashes with notifications, consider"
	ewarn "upgrading gbinder-python when a newer version becomes available."
}

pkg_postrm() {
	xdg_pkg_postrm
}
