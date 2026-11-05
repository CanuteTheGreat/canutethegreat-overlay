# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Command line interface for WordPress (upstream phar)"
HOMEPAGE="https://wp-cli.org/ https://github.com/wp-cli/wp-cli"
SRC_URI="https://github.com/wp-cli/wp-cli/releases/download/v${PV}/${P}.phar"
S="${WORKDIR}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
RESTRICT="strip test"

RDEPEND="
	dev-lang/php:*[cli,curl,phar,mysqli,zip,xml,ssl,iconv]
"

src_unpack() {
	cp "${DISTDIR}/${P}.phar" "${WORKDIR}/wp.phar" || die
}

src_install() {
	exeinto /usr/share/${PN}
	doexe wp.phar
	# thin launcher: the phar needs php's phar stream wrapper, so call php explicitly (no binfmt/phar auto-detection needed)
	cat > wp <<-EOF || die
		#!/bin/sh
		exec php ${EPREFIX}/usr/share/${PN}/wp.phar "\$@"
	EOF
	dobin wp
}
