# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="Linux desktop client for GeForce NOW, using Electron"
HOMEPAGE="https://github.com/hmlendea/gfn-electron"
SRC_URI="
	amd64? ( https://github.com/hmlendea/gfn-electron/releases/download/v${PV}/geforcenow-electron_${PV}_linux_x64.zip )
	arm64? ( https://github.com/hmlendea/gfn-electron/releases/download/v${PV}/geforcenow-electron_${PV}_linux_arm64.zip )
"

S=${WORKDIR}

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="bindist mirror strip"

RDEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/libva
	media-libs/mesa[gbm(+)]
	net-print/cups
	sys-apps/dbus
	x11-libs/cairo
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/pango
"
BDEPEND="app-arch/unzip"
QA_PREBUILT="opt/${PN}/*"

src_install() {
	insinto /opt/${PN}
	doins -r "${S}"/*
	domenu "${S}"/com.github.hmlendea.geforcenow-electron.desktop
	fperms +x /opt/${PN}/geforcenow-electron /opt/${PN}/chrome_crashpad_handler
	fperms 4711 /opt/${PN}/chrome-sandbox
	dosym -r /opt/${PN}/geforcenow-electron /usr/bin/geforcenow
}
