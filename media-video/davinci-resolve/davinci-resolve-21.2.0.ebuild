# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit davinci-resolve udev xdg

KEYWORDS="~amd64"

pkg_postinst() {
	xdg_pkg_postinst
	udev_reload
	davinci-resolve_postinst_msg
}

pkg_postrm() {
	xdg_pkg_postrm
	udev_reload
}
