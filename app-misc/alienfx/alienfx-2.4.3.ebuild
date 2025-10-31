# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
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
	>=dev-python/pyusb-1.2.1[${PYTHON_USEDEP}]
	gtk? (
		dev-python/pygobject:3[${PYTHON_USEDEP},cairo]
		x11-libs/gtk+:3
	)
"

# Note: Upstream uses 'from builtins import' from python-future package,
# but these are unnecessary for Python 3 and the package works without it.
# dev-python/future is also not available in Gentoo as Python 2 is EOL.

BDEPEND="
	dev-python/setuptools[${PYTHON_USEDEP}]
"

DOCS=( README.md CONTRIBUTING.md )

python_prepare_all() {
	# Remove automatic udev rules installation from setup.py
	# as we'll handle it properly through the ebuild
	# Delete lines 80-92 (the udev rules copying code after setup())
	sed -i -e '80,92d' setup.py || die "Failed to patch setup.py"

	# Fix GTK UI to not require python-future package
	# Replace old_div() calls with Python 3 native division
	# old_div(a, b) -> a // b for floor division
	# old_div(float(x), y) -> float(x) / y for true division
	python3 - << 'EOF' || die "Failed to patch action_renderer.py"
import re

with open('alienfx/ui/gtkui/action_renderer.py', 'r') as f:
    content = f.read()

# Remove the import
content = re.sub(r'from past\.utils import old_div\n', '', content)

# Replace old_div with floor division or true division
# For float division: old_div(float(x), y) -> float(x) / y
content = re.sub(r'old_div\(float\(([^)]+)\),\s*([^)]+)\)',
                 r'float(\1) / \2', content)

# For everything else: old_div(a, b) -> a // b
# Use a more permissive pattern that handles multi-line
content = re.sub(r'old_div\(([^,]+),\s*([^)]+)\)',
                 r'(\1) // (\2)', content, flags=re.MULTILINE)

with open('alienfx/ui/gtkui/action_renderer.py', 'w') as f:
    f.write(content)
EOF

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
