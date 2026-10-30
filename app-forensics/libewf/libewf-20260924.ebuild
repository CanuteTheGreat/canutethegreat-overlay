# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Implementation of the EWF (SMART and EnCase) image format"
HOMEPAGE="https://github.com/libyal/libewf"
SRC_URI="https://github.com/libyal/libewf/releases/download/${PV}/libewf-experimental-${PV}.tar.gz"
S="${WORKDIR}/libewf-${PV}"

LICENSE="LGPL-3+"
SLOT="0/3"
KEYWORDS="~amd64 ~x86"
IUSE="debug fuse +ssl static-libs +uuid"

RDEPEND="
	app-arch/bzip2
	virtual/zlib:=
	fuse? ( sys-fs/fuse:3 )
	ssl? ( dev-libs/openssl:= )
	uuid? ( sys-apps/util-linux )
"
DEPEND="${RDEPEND}"

DOCS=( AUTHORS NEWS README )

src_configure() {
	local myeconfargs=(
		$(use_enable debug debug-output)
		$(use_enable debug verbose-output)
		$(use_enable static-libs static)
		$(use_with fuse libfuse)
		$(use_with ssl openssl)
		$(use_with uuid libuuid)
		--enable-wide-character-type
		--with-bzip2
		--with-zlib
		# the bundled libyal libraries are used (libbfio, libhmac, ...)
	)
	econf "${myeconfargs[@]}"
}

src_install() {
	default
	find "${ED}" -name '*.la' -delete || die
}
