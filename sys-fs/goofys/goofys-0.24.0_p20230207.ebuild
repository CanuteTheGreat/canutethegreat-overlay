# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

# Snapshot from master branch (v0.24.0 lacks go.mod/go.sum)
# Last commit: 2023-02-07 "Fix FusePanicLogger.BatchForget redeclared in this block"
COMMIT="350ff312abaa1abcf21c5a06e143c7edffe9e2f4"

DESCRIPTION="High-performance POSIX-ish Amazon S3 file system written in Go"
HOMEPAGE="https://github.com/kahing/goofys"
SRC_URI="https://github.com/kahing/${PN}/archive/${COMMIT}.tar.gz -> ${P}.tar.gz
	https://files.canutethegreat.com/gentoo/distfiles/${P}-deps.tar.xz"

LICENSE="Apache-2.0 BSD BSD-2 MIT MPL-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RDEPEND="sys-fs/fuse:0"
DEPEND="${RDEPEND}"

RESTRICT="test"  # Tests require S3 credentials

S="${WORKDIR}/${PN}-${COMMIT}"

src_compile() {
	ego build -ldflags "-X main.version=${PV}" -o ${PN}
}

src_install() {
	dobin ${PN}
	dodoc README.md README-azure.md
}
