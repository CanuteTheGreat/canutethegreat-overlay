# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CHROMIUM_LANGS="
	af am ar az bg bn bs ca cs da de el en-GB es es-419 et fa fi fil fr gu he
	hi hr hu id it ja ka kk km kn ko lo lt lv mk ml mn mr ms my nb nl pl pt-BR
	pt-PT ro ru si sk sl sq sr sr-Latn sv sw ta te th tr uk ur uz vi zh-CN
	zh-TW
"

inherit chromium-2 desktop pax-utils unpacker xdg

DESCRIPTION="Privacy-focused web browser based on Chromium (official binary build)"
HOMEPAGE="https://brave.com/"
SRC_URI="
	amd64? ( https://github.com/brave/brave-browser/releases/download/v${PV}/brave-browser_${PV}_amd64.deb )
	arm64? ( https://github.com/brave/brave-browser/releases/download/v${PV}/brave-browser_${PV}_arm64.deb )
"
S=${WORKDIR}

# Brave's own code is MPL-2.0, the rest is the Chromium code base.
LICENSE="MPL-2.0 Apache-2.0 BSD BSD-2 Boost-1.0 CC-BY-3.0 CC-BY-4.0 FTL IJG ISC"
LICENSE+=" LGPL-2 LGPL-2.1 MIT MPL-1.1 Ms-PL SSLeay Unicode-3.0 Unicode-DFS-2015 ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
IUSE="qt6 selinux"
RESTRICT="bindist mirror strip"

RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	app-crypt/libsecret
	app-misc/ca-certificates
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	>=dev-libs/nss-3.26
	media-libs/alsa-lib
	media-libs/mesa[gbm(+)]
	net-print/cups
	sys-apps/dbus
	sys-libs/glibc
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	|| (
		x11-libs/gtk+:3[X]
		gui-libs/gtk:4[X]
	)
	x11-libs/libdrm
	>=x11-libs/libX11-1.5.0
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libxshmfence
	x11-libs/pango
	x11-misc/xdg-utils
	qt6? ( dev-qt/qtbase:6[gui,widgets] )
	selinux? ( sec-policy/selinux-chromium )
"

QA_PREBUILT="*"
QA_DESKTOP_FILE="usr/share/applications/.*\\.desktop"
BRAVE_HOME="opt/brave.com/brave"

pkg_pretend() {
	# Protect against people using autounmask overzealously
	use amd64 || use arm64 || die "${PN} only works on supported architectures (amd64, arm64)."
}

pkg_setup() {
	chromium_suid_sandbox_check_kernel_config
}

src_unpack() {
	:
}

src_install() {
	dodir /
	cd "${ED}" || die
	unpacker

	# Debian cron job and doc directory; only the unversioned one has content.
	rm -r etc/cron.daily "${BRAVE_HOME}"/cron || die
	rmdir usr/share/doc/brave-browser-stable || die
	mv usr/share/doc/brave-browser "usr/share/doc/${PF}" || die
	gzip -d "usr/share/doc/${PF}/changelog.gz" || die

	gzip -d usr/share/man/man1/brave-browser-stable.1.gz || die
	rm usr/share/man/man1/brave-browser.1.gz || die
	dosym brave-browser-stable.1 usr/share/man/man1/brave-browser.1

	# AppStream data belongs in metainfo
	mkdir -p usr/share/metainfo || die
	mv usr/share/appdata/brave-browser.appdata.xml usr/share/metainfo/ || die
	rmdir usr/share/appdata || die

	pushd "${BRAVE_HOME}/locales" >/dev/null || die
	chromium_remove_language_paks
	popd >/dev/null || die

	rm "${BRAVE_HOME}/libqt5_shim.so" || die
	if ! use qt6; then
		rm "${BRAVE_HOME}/libqt6_shim.so" || die
	fi

	local size
	for size in 16 24 32 48 64 128 256; do
		newicon -s ${size} "${BRAVE_HOME}/product_logo_${size}.png" brave-browser.png
	done

	# Chromium's setuid sandbox helper must be root-owned and mode 4711.
	fperms 4711 "/${BRAVE_HOME}/chrome-sandbox"

	# Replace the upstream symlink with a wrapper that honours
	# ~/.config/brave-flags.conf; the desktop files already Exec it.
	rm usr/bin/brave-browser-stable || die
	exeinto /usr/bin
	doexe "${FILESDIR}/brave-browser-stable"
	dosym brave-browser-stable /usr/bin/brave-browser
	dosym brave-browser-stable /usr/bin/brave

	pax-mark m "${BRAVE_HOME}/brave"
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "Brave reads extra command-line flags from"
	elog "  \${XDG_CONFIG_HOME:-~/.config}/brave-flags.conf"
	elog "(whitespace-separated; lines starting with '#' are comments), e.g."
	elog "  --ozone-platform-hint=auto"
	elog "The setuid chrome-sandbox needs USER_NS/PID_NS/NET_NS/SECCOMP in the kernel."
}
