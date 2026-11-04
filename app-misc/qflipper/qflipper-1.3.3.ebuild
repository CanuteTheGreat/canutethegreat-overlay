# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit qmake-utils udev xdg

# 3rdparty/nanopb is a git submodule (not in GitHub's release tarball)
NANOPB_COMMIT="13666952914f3cf43a70c6b9738a7dc0dd06a6dc"

DESCRIPTION="Desktop application and CLI for updating and managing Flipper Zero devices"
HOMEPAGE="https://flipperzero.one https://github.com/flipperdevices/qFlipper"
SRC_URI="
	https://github.com/flipperdevices/qFlipper/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/nanopb/nanopb/archive/${NANOPB_COMMIT}.tar.gz -> nanopb-${NANOPB_COMMIT}.tar.gz
"
S="${WORKDIR}/qFlipper-${PV}"

LICENSE="GPL-3 ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

DEPEND="
	dev-libs/libusb:1
	dev-qt/qtbase:6=[concurrent,gui,network,widgets]
	dev-qt/qtdeclarative:6=
	dev-qt/qtserialport:6=
	dev-qt/qtsvg:6=
	dev-qt/qt5compat:6=
	virtual/zlib:=
"
RDEPEND="${DEPEND}
	virtual/udev
"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	# Qt >= 6.9 needs operator== for QVariant-wrapped types (pentoo-overlay,
	# upstream issue flipperdevices/qFlipper#213)
	"${FILESDIR}/${P}-qt6.9-operator-eq.patch"
)

src_prepare() {
	default

	rmdir 3rdparty/nanopb || die
	mv "${WORKDIR}/nanopb-${NANOPB_COMMIT}" 3rdparty/nanopb || die

	# no .git in the tarball: git describe/rev-parse would yield "unknown"
	sed -i \
		-e 's|^GIT_VERSION = .*|GIT_VERSION = '"${PV}"'\nHAS_VERSION = 0|' \
		-e 's|^GIT_COMMIT = .*|GIT_COMMIT = release\nHAS_COMMIT = 0|' \
		-e 's|^GIT_TIMESTAMP = .*|GIT_TIMESTAMP = 0\nHAS_TIMESTAMP = 0|' \
		qflipper_common.pri || die

	# uaccess only: the seat user gets access, no group ownership games
	sed -i -e 's/, GROUP="dialout"//' installer-assets/udev/42-flipperzero.rules || die

	# upstream's Categories lacks the trailing ';'
	sed -i -e 's/^Categories=.*/Categories=Utility;/' \
		installer-assets/appimage/qFlipper.desktop || die
}

src_configure() {
	eqmake6 qFlipper.pro PREFIX="${EPREFIX}/usr" CONFIG+=release \
		DEFINES+=DISABLE_APPLICATION_UPDATES
}

src_install() {
	emake INSTALL_ROOT="${D}" install

	# installed by upstream into $PREFIX/lib/udev; use the eclass location
	rm -r "${ED}/usr/lib/udev" || die
	udev_dorules installer-assets/udev/42-flipperzero.rules

	dodoc README.md
}

pkg_postinst() {
	xdg_pkg_postinst
	udev_reload
}

pkg_postrm() {
	xdg_pkg_postrm
	udev_reload
}
