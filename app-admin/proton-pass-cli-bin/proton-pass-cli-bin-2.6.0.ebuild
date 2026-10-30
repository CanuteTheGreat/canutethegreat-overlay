# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Proton Pass command-line interface (official binary build)"
HOMEPAGE="https://protonpass.github.io/pass-cli/ https://github.com/protonpass/pass-cli"
SRC_URI="
	amd64? ( https://proton.me/download/pass-cli/${PV}/pass-cli-linux-x86_64 -> ${P}-amd64 )
	arm64? ( https://proton.me/download/pass-cli/${PV}/pass-cli-linux-aarch64 -> ${P}-arm64 )
"
S=${WORKDIR}

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="bindist mirror strip"

RDEPEND="sys-libs/glibc"

QA_PREBUILT="usr/bin/pass-cli"

src_unpack() {
	:
}

src_install() {
	newbin "${DISTDIR}/${P}-${ARCH}" pass-cli
}
