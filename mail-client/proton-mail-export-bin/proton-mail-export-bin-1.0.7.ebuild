# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Proton Mail Export Tool (CLI) to back up a Proton Mail account (official binary build)"
HOMEPAGE="https://proton.me/support/proton-mail-export-tool https://github.com/ProtonMail/proton-mail-export"
SRC_URI="https://github.com/ProtonMail/proton-mail-export/releases/download/v${PV}/proton-mail-export-cli-linux_x86_64.tar.gz -> ${P}.tar.gz"
S=${WORKDIR}

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	sys-devel/gcc:*
	sys-libs/glibc
"

QA_PREBUILT="opt/proton-mail-export/*"

src_install() {
	# the CLI finds proton-mail-export.so through RUNPATH=$ORIGIN, so keep them together
	exeinto /opt/proton-mail-export
	doexe proton-mail-export-cli proton-mail-export.so
	dosym ../../opt/proton-mail-export/proton-mail-export-cli /usr/bin/proton-mail-export-cli
}
