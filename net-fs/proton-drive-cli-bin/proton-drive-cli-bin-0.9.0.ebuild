# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Proton Drive command-line interface (official binary build)"
HOMEPAGE="https://proton.me/support/drive-cli https://github.com/ProtonDriveApps/sdk/tree/main/cli"
SRC_URI="
	amd64? ( https://proton.me/download/drive/cli/${PV}/linux-x64/proton-drive -> ${P}-amd64 )
	arm64? ( https://proton.me/download/drive/cli/${PV}/linux-arm64/proton-drive -> ${P}-arm64 )
"
S=${WORKDIR}

# MIT SDK; the single-file executable also embeds a Bun runtime and bundled npm modules
LICENSE="MIT"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
# stripping corrupts Bun's appended JS payload
RESTRICT="bindist mirror strip"

RDEPEND="sys-libs/glibc"

QA_PREBUILT="usr/bin/proton-drive"

src_unpack() {
	:
}

src_install() {
	newbin "${DISTDIR}/${P}-${ARCH}" proton-drive
}
