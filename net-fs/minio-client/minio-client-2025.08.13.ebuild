# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

# Upstream tag RELEASE.2025-08-13T08-35-41Z (PV = its date). The MinIO server/client projects are ARCHIVED upstream: no more
# releases or security fixes and the binary downloads at dl.min.io are gone, so this is the last tag, built from source.
# Go dependencies: vendor tarball made by .ci/make-go-vendor.sh, published as an asset of the "distfiles" release of this overlay.
MY_TAG="RELEASE.2025-08-13T08-35-41Z"
MY_COMMIT="7394ce0dd2a80935aded936b09fa12cbb3cb8096"

DESCRIPTION="MinIO Client (mc): ls/cp/mirror/... for S3-compatible object stores (last upstream release)"
HOMEPAGE="https://github.com/minio/mc"
SRC_URI="
	https://github.com/minio/mc/archive/${MY_TAG}.tar.gz -> ${P}.tar.gz
	https://git.canutethegreat.com/CanuteTheGreat/canutethegreat-overlay/releases/download/distfiles/${P}-vendor.tar.xz
"
S="${WORKDIR}/mc-${MY_TAG}"

LICENSE="AGPL-3 Apache-2.0 BSD BSD-2 MIT MPL-2.0 ISC"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="mc-symlink"
RESTRICT="test"

# /usr/bin/mc is Midnight Commander's
RDEPEND="mc-symlink? ( !app-misc/mc )"
BDEPEND=">=dev-lang/go-1.23"

src_compile() {
	local ldflags="-s -w
		-X github.com/minio/mc/cmd.Version=${MY_TAG#RELEASE.}
		-X github.com/minio/mc/cmd.ReleaseTag=${MY_TAG}
		-X github.com/minio/mc/cmd.CommitID=${MY_COMMIT}
		-X github.com/minio/mc/cmd.ShortCommitID=${MY_COMMIT:0:12}"
	ego build -mod=vendor -trimpath -ldflags "${ldflags//$'\n'/ }" -o mcli
}

src_install() {
	# "mcli" like Debian/Fedora; USE=mc-symlink also provides the upstream name
	dobin mcli
	use mc-symlink && dosym mcli /usr/bin/mc
	einstalldocs
}
