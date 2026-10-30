# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

DESCRIPTION="Proton Pass desktop password manager (official binary build)"
HOMEPAGE="https://proton.me/pass"
SRC_URI="https://proton.me/download/pass/linux/proton-pass_${PV}_amd64.deb"
S=${WORKDIR}

# Proton's own code is GPL-3 (ProtonMail/WebClients); the Electron/Chromium runtime
# it ships (LICENSES.chromium.html) adds the permissive licenses below.
LICENSE="GPL-3 Apache-2.0 BSD BSD-2 Boost-1.0 CC-BY-3.0 CC-BY-4.0 FTL IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL SSLeay Unicode-3.0 Unicode-DFS-2015 ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	app-crypt/libsecret
	app-misc/ca-certificates
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa[gbm(+)]
	net-print/cups
	sys-apps/dbus
	sys-libs/glibc
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3[X]
	x11-libs/libdrm
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libXtst
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libxshmfence
	x11-libs/pango
	x11-misc/xdg-utils
"

QA_PREBUILT="opt/proton-pass/*"
QA_DESKTOP_FILE="usr/share/applications/proton-pass.desktop"

src_unpack() {
	unpack_deb ${A}
}

src_install() {
	local dest=/opt/proton-pass
	insinto "${dest}"
	doins -r usr/lib/proton-pass/.
	# doins drops the exec bits: restore them on the real executables
	fperms +x "${dest}/Proton Pass" "${dest}/chrome_crashpad_handler"
	fperms 4711 "${dest}/chrome-sandbox"
	[[ -f usr/lib/proton-pass/libffmpeg.so ]] && fperms +x "${dest}/libffmpeg.so"

	# Upstream's /usr/bin/proton-pass is a symlink to the binary; use a wrapper that
	# honours ${XDG_CONFIG_HOME:-~/.config}/proton-pass-flags.conf and picks Wayland when available.
	exeinto /usr/bin
	doexe "${FILESDIR}/proton-pass"

	domenu usr/share/applications/proton-pass.desktop
	# Upstream ships the SVG logo as pixmaps/proton-pass.png (wrong extension)
	newicon -s scalable usr/share/pixmaps/proton-pass.png proton-pass.svg
	newicon -s 512 usr/lib/proton-pass/resources/assets/logo.png proton-pass.png
	dodoc usr/share/doc/proton-pass/copyright
}

pkg_postinst() {
	xdg_pkg_postinst
	elog "Extra command-line flags are read from"
	elog "  \${XDG_CONFIG_HOME:-~/.config}/proton-pass-flags.conf"
	elog "(whitespace-separated, '#' comments). --ozone-platform-hint=auto is the default."
	elog "The setuid chrome-sandbox needs USER_NS/PID_NS/NET_NS/SECCOMP in the kernel."
}
