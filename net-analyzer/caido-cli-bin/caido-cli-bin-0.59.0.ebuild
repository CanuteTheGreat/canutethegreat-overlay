# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Caido web security auditing toolkit, headless CLI/server (official binary build)"
HOMEPAGE="https://caido.io https://github.com/caido/caido"
SRC_URI="
	amd64? ( https://caido.download/releases/v${PV}/caido-cli-v${PV}-linux-x86_64.tar.gz -> ${P}-amd64.tar.gz )
	arm64? ( https://caido.download/releases/v${PV}/caido-cli-v${PV}-linux-aarch64.tar.gz -> ${P}-arm64.tar.gz )
"
S="${WORKDIR}"

# Proprietary, free to use; ToS at https://caido.io/terms
LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="bindist mirror strip"

RDEPEND="|| ( sys-devel/gcc llvm-runtimes/libgcc )"

QA_PREBUILT="usr/bin/caido-cli"

src_install() {
	dobin caido-cli
}

pkg_postinst() {
	elog "Run 'caido-cli' (web UI on http://127.0.0.1:8080 by default); see 'caido-cli --help'."
	elog "Caido is proprietary software; see https://caido.io/terms"
}
