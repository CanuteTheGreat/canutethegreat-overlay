# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
DISTUTILS_USE_PEP517=setuptools

inherit distutils-r1 udev

DESCRIPTION="CLI and GUI utility to control lighting effects on Alienware computers"
HOMEPAGE="https://github.com/trackmastersteve/alienfx"
SRC_URI="https://github.com/trackmastersteve/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="gtk"

RDEPEND="
	dev-libs/libusb:1
	dev-python/pkg-resources[${PYTHON_USEDEP}]
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

PATCHES=( "${FILESDIR}"/${P}-no-python-future.patch )

python_prepare_all() {
	# Drop setup.py's own udev rule installation (written to /etc at
	# build time, bypasses the sandbox); the ebuild installs it below.
	sed -i -e '/^# Copy the udev rules file/,$d' \
		-e '/^from pkg_resources import/d' setup.py || die

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
