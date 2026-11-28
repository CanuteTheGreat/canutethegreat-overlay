# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="Caido web security auditing toolkit, desktop app (official binary build)"
HOMEPAGE="https://caido.io https://github.com/caido/caido"
SRC_URI="https://caido.download/releases/v${PV}/caido-desktop-v${PV}-linux-x86_64.tar.gz"
S="${WORKDIR}/caido-desktop-x64-linux"

# Caido itself is proprietary (free + paid tiers, ToS at https://caido.io/terms);
# the Electron/Chromium runtime adds the permissive licenses below.
LICENSE="all-rights-reserved Apache-2.0 BSD BSD-2 Boost-1.0 CC-BY-3.0 CC-BY-4.0 FTL IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL SSLeay Unicode-3.0 Unicode-DFS-2015 ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa[gbm(+)]
	net-print/cups
	sys-apps/dbus
	|| ( sys-devel/gcc llvm-runtimes/libgcc )
	x11-libs/cairo
	x11-libs/gtk+:3[X]
	x11-libs/libdrm
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/pango
	x11-misc/xdg-utils
"

QA_PREBUILT="opt/caido/*"

src_install() {
	local dest=/opt/caido
	insinto "${dest}"
	doins -r .
	# doins drops exec bits: restore them
	fperms +x "${dest}"/{caido,chrome_crashpad_handler} "${dest}/resources/bin/caido-cli"
	fperms 4711 "${dest}/chrome-sandbox"

	exeinto /usr/bin
	doexe "${FILESDIR}/caido"

	domenu "${FILESDIR}/caido.desktop"

	local s
	for s in 16 32 128 256 512; do
		newicon -s ${s} "resources/icons/icon_${s}x${s}.png" caido.png
	done
	newicon -s scalable resources/icons/original.svg caido.svg
}

pkg_postinst() {
	xdg_pkg_postinst
	elog "Extra flags: \${XDG_CONFIG_HOME:-~/.config}/caido-flags.conf"
	elog "The setuid chrome-sandbox needs USER_NS/PID_NS/NET_NS/SECCOMP in the kernel."
	elog "Caido is proprietary software; see https://caido.io/terms"
}
