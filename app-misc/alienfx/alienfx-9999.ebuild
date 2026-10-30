# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_14 )
DISTUTILS_USE_PEP517=setuptools

inherit distutils-r1 udev git-r3

DESCRIPTION="CLI and GUI utility to control lighting effects on Alienware computers"
HOMEPAGE="https://github.com/trackmastersteve/alienfx"
EGIT_REPO_URI="https://github.com/trackmastersteve/alienfx.git"

LICENSE="GPL-3"
SLOT="0"
IUSE="gtk"

RDEPEND="
	dev-libs/libusb:1
	>=dev-python/pyusb-1.2.1[${PYTHON_USEDEP}]
	gtk? (
		dev-python/pygobject:3[${PYTHON_USEDEP},cairo]
		x11-libs/gtk+:3
	)
"

# Note: Upstream uses 'from builtins import' from python-future package,
# but these are unnecessary for Python 3 and the package works without it.
# dev-python/future is also not available in Gentoo as Python 2 is EOL.

DOCS=( README.md CONTRIBUTING.md )

python_prepare_all() {
	# Drop setup.py's own udev rule installation (written to /etc at
	# build time, bypasses the sandbox); the ebuild installs it below.
	sed -i -e '/^# Copy the udev rules file/,$d' setup.py || die

	# Upstream's rules make the USB node world-writable (MODE 666) and, for
	# the Alpha ASM100, chmod 666 files in sysfs. Hand access to the
	# logged-in seat user instead (uaccess ACL set by systemd-logind or
	# elogind) and drop the sysfs chmod rule.
	local rules=alienfx/data/etc/udev/rules.d/10-alienfx.rules
	sed -i -e '/RUN+="\/bin\/chmod/d' \
		-e 's/MODE:="666", GROUP="users"/TAG+="uaccess"/' "${rules}" || die
	if grep -qE 'MODE|chmod|GROUP=' "${rules}"; then
		die "${rules} still sets a mode/group"
	fi

	distutils-r1_python_prepare_all
}

python_install_all() {
	distutils-r1_python_install_all

	# Install udev rules
	udev_dorules alienfx/data/etc/udev/rules.d/10-alienfx.rules

	# Install man page
	doman docs/man/alienfx.1

	if ! use gtk; then
		# Remove GTK files if gtk USE flag is not enabled
		rm "${ED}"/usr/bin/alienfx-gtk || die
		rm -r "${ED}"/usr/lib*/python*/site-packages/alienfx/ui/gtkui || die
	fi
}

pkg_postinst() {
	udev_reload

	elog "AlienFX has been installed."
	elog ""
	elog "After installation, you may need to reload udev rules:"
	elog "  # udevadm control --reload-rules"
	elog "  # udevadm trigger"
	elog ""
	elog "You may need to re-plug your USB device or reboot for the"
	elog "udev rules to take effect."
	elog ""
	elog "The udev rules grant access with TAG+=\"uaccess\": only the user"
	elog "logged in at the local seat can use the controller (needs"
	elog "systemd-logind or elogind). No device node is world-writable."
	elog "The Alienware Alpha ASM100 (alienware-wmi, sysfs) rule was removed;"
	elog "use the kernel's LED/hwmon interfaces or your own rule for it."
	elog ""
	elog "Configuration files are stored in \$XDG_CONFIG_HOME/alienfx"
	elog "or ~/.config/alienfx if XDG_CONFIG_HOME is not set."
	elog ""
	if use gtk; then
		elog "GUI version is available as 'alienfx-gtk'"
		elog ""
	fi
	elog "For CLI usage, see: man alienfx"
	elog ""
	elog "If your device is not yet supported, run 'alienfx' and follow"
	elog "the zonescan procedure to determine correct zone codes."
	elog "Please consider contributing your findings upstream!"
}

pkg_postrm() {
	udev_reload
}
