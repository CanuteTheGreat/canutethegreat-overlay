# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

DESCRIPTION="Proton Authenticator, open source 2FA (TOTP) app (official binary build)"
HOMEPAGE="https://proton.me/authenticator"
SRC_URI="https://proton.me/download/authenticator/linux/ProtonAuthenticator_${PV}_amd64.deb"
S=${WORKDIR}

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	net-libs/webkit-gtk:4.1
	x11-libs/gtk+:3
"

QA_PREBUILT="usr/bin/proton-authenticator"

src_unpack() {
	unpack_deb ${A}
}

src_install() {
	dobin usr/bin/proton-authenticator

	# upstream's desktop file is named "Proton Authenticator.desktop" (with a space)
	newmenu "usr/share/applications/Proton Authenticator.desktop" proton-authenticator.desktop

	local d
	for d in 32x32 128x128; do
		doicon -s ${d%x*} usr/share/icons/hicolor/${d}/apps/proton-authenticator.png
	done
	# "256x256@2" is a 256px image for HiDPI of 128; install it as a plain 256px icon
	newicon -s 256 "usr/share/icons/hicolor/256x256@2/apps/proton-authenticator.png" proton-authenticator.png
}
