# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker xdg-utils

DESCRIPTION="Powerful modern download accelerator and organizer for Windows and Mac"
HOMEPAGE="https://www.freedownloadmanager.org/"
SRC_URI="https://files2.freedownloadmanager.org/6/latest/${PN}.deb"

LICENSE="FDM"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+gstreamer"
RESTRICT="bindist mirror strip"

# Dependencies based on runtime requirements
RDEPEND="
	>=dev-libs/openssl-1.1.1:0=
	>=media-video/ffmpeg-4.0:0=
	>=net-libs/libtorrent-rasterbar-1.2.0:0=
	x11-misc/xdg-utils
	gstreamer? (
		media-libs/gst-plugins-base:1.0
		media-libs/gst-plugins-good:1.0
	)
	media-libs/fontconfig
	media-libs/freetype
	sys-apps/dbus
	sys-libs/zlib
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXext
	x11-libs/libXi
"

BDEPEND="
	app-arch/xz-utils
"

S="${WORKDIR}"

QA_PREBUILT="opt/freedownloadmanager/*"

src_unpack() {
	unpack_deb "${DISTDIR}/${PN}.deb"
}

src_prepare() {
	default

	# Fix desktop file paths
	sed -i \
		-e 's|/opt/freedownloadmanager/fdm|fdm|g' \
		-e 's|Icon=freedownloadmanager|Icon=freedownloadmanager|g' \
		-e '/^Exec=/a\StartupWMClass=Free Download Manager' \
		usr/share/applications/freedownloadmanager.desktop || die "sed failed"
}

src_install() {
	# Install main application files
	insinto /opt
	doins -r opt/freedownloadmanager

	# Make binaries executable
	fperms +x /opt/freedownloadmanager/fdm
	fperms +x /opt/freedownloadmanager/fdmextension

	# Create symlink for main executable
	dosym -r /opt/freedownloadmanager/fdm /usr/bin/fdm

	# Install desktop file
	domenu usr/share/applications/freedownloadmanager.desktop

	# Install icons with proper sizes
	local size
	for size in 16 22 24 32 48 64 128 256; do
		if [[ -f "opt/freedownloadmanager/icon${size}.png" ]]; then
			newicon -s ${size} opt/freedownloadmanager/icon${size}.png freedownloadmanager.png
		fi
	done

	# Fallback icon installation if specific sizes aren't available
	if [[ -f "opt/freedownloadmanager/icon.png" ]]; then
		newicon -s 256 opt/freedownloadmanager/icon.png freedownloadmanager.png
	fi

	# Install additional resources if present
	if [[ -d "opt/freedownloadmanager/translations" ]]; then
		insinto /opt/freedownloadmanager
		doins -r opt/freedownloadmanager/translations
	fi

	# Install documentation
	if [[ -d "usr/share/doc/${PN}" ]]; then
		dodoc usr/share/doc/${PN}/* || true
	fi
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update

	elog "Free Download Manager has been installed."
	elog ""
	elog "This is a binary package. The source code for FDM 6.x"
	elog "is not publicly available. For open-source alternatives,"
	elog "consider aria2, uGet, or other download managers."
	elog ""

	if use gstreamer; then
		elog "GStreamer support is enabled for media preview functionality."
		elog "If you experience issues with video/audio preview, ensure"
		elog "appropriate GStreamer codec packages are installed."
	else
		elog "GStreamer support is disabled. Media preview will not work."
		elog "Enable the 'gstreamer' USE flag if you need this feature."
	fi
	elog ""
	elog "Browser integration requires installing the appropriate"
	elog "extension from your browser's extension store."
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
