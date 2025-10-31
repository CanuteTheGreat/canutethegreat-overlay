# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CHROMIUM_LANGS="
	af am ar bg bn ca cs da de el en-GB es es-419 et fa fi fil fr gu he hi hr hu
	id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr sv sw ta te
	th tr uk ur vi zh-CN zh-TW
"

inherit chromium-2 desktop pax-utils unpacker xdg

DESCRIPTION="Privacy-focused browser based on Chromium with built-in ad blocking"
HOMEPAGE="https://brave.com/"

MY_PV="${PV/_rc/-rc.}"
BRAVE_PN="${PN/-bin/}-browser"

SRC_BASE="https://github.com/brave/brave-browser/releases/download/v${MY_PV}/"
SRC_URI="
	amd64? ( ${SRC_BASE}${BRAVE_PN}_${MY_PV}_amd64.deb )
	arm64? ( ${SRC_BASE}${BRAVE_PN}_${MY_PV}_arm64.deb )
"

S="${WORKDIR}"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+keyring selinux"
RESTRICT="bindist mirror"

RDEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa[gbm(+)]
	net-print/cups
	sys-apps/dbus
	sys-libs/glibc
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3[X]
	x11-libs/libdrm
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXcursor
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libxkbcommon
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXScrnSaver
	x11-libs/libxshmfence
	x11-libs/libXtst
	x11-libs/pango
	keyring? ( app-crypt/libsecret )
	selinux? ( sec-policy/selinux-chromium )
"

QA_PREBUILT="
	opt/brave.com/brave/*.so
	opt/brave.com/brave/brave
	opt/brave.com/brave/chrome_crashpad_handler
	opt/brave.com/brave/chrome-management-service
"

pkg_pretend() {
	# Protect against people using autounmask overzealously
	use amd64 || use arm64 || die "Unsupported architecture"
}

pkg_setup() {
	chromium_suid_sandbox_check_kernel_config
}

src_unpack() {
	unpack_deb ${A}
}

src_prepare() {
	# Remove cron job
	rm -r etc || die "Failed to remove cron job"

	# Remove packages that are not needed
	rm -r usr/share/menu || die "Failed to remove menu"

	# Fix desktop file
	pushd usr/share/applications >/dev/null || die
	sed -e 's|^Exec=/usr/bin/brave-browser-stable|Exec=brave-bin|' \
		-e 's|^Icon=.*|Icon=brave-bin|' \
		-e '/^StartupWMClass/d' \
		-i brave-browser.desktop || die "Failed to fix desktop file"
	mv brave-browser{,-stable}.desktop || die "Failed to rename desktop file"
	popd >/dev/null || die

	# Modify wrapper
	pushd usr/bin >/dev/null || die
	sed -e 's|brave-browser-stable|brave-bin|g' \
		-e 's|/usr/bin/brave-browser|/opt/brave.com/brave/brave|g' \
		-i brave-browser-stable || die "Failed to modify wrapper"
	popd >/dev/null || die

	# Rename directories
	mv usr/share/doc/{brave-browser,${PF}} || die "Failed to rename doc directory"

	pushd opt/brave.com/brave >/dev/null || die

	# Remove unnecessary files
	rm -r cron || die "Failed to remove cron directory"

	# Remove SUID sandbox if kernel doesn't support it
	if ! use kernel_linux || ! has_version 'sys-kernel/linux-headers[-hardened]'; then
		rm chrome-sandbox 2>/dev/null || true
	fi

	# Fix permissions for brave-sandbox if it exists (removed in newer versions)
	if [[ -f brave-sandbox ]]; then
		chmod 4755 brave-sandbox || die "Failed to chmod brave-sandbox"
	fi

	popd >/dev/null || die

	default
}

src_install() {
	# Install the main application
	insinto /opt/brave.com
	doins -r opt/brave.com/brave

	# Install wrapper
	exeinto /opt/brave.com/brave
	doexe opt/brave.com/brave/brave
	if [[ -f opt/brave.com/brave/brave-sandbox ]]; then
		doexe opt/brave.com/brave/brave-sandbox
	fi
	doexe opt/brave.com/brave/chrome_crashpad_handler
	if [[ -f opt/brave.com/brave/chrome-management-service ]]; then
		doexe opt/brave.com/brave/chrome-management-service
	fi

	# Install additional executables
	if [[ -f opt/brave.com/brave/libvulkan.so.1 ]]; then
		doexe opt/brave.com/brave/libvulkan.so.1
	fi

	# Install libraries
	exeinto /opt/brave.com/brave
	doexe opt/brave.com/brave/lib*.so*

	# Create wrapper script
	dodir /usr/bin
	cat > "${ED}"/usr/bin/brave-bin <<-EOF || die
		#!/bin/sh
		# Copyright 1999-2025 Gentoo Authors
		# Distributed under the terms of the GNU General Public License v2

		# Allow users to override command-line options
		if [[ -f ~/.config/brave-flags.conf ]]; then
		   BRAVE_FLAGS="\$(grep -v '^#' ~/.config/brave-flags.conf | tr '\n' ' ')"
		fi

		# Launch Brave
		exec /opt/brave.com/brave/brave "\${BRAVE_FLAGS}" "\$@"
	EOF
	fperms +x /usr/bin/brave-bin

	# Install icons
	local size
	for size in 16 24 32 48 64 128 256; do
		newicon -s ${size} "opt/brave.com/brave/product_logo_${size}.png" brave-bin.png
	done

	# Install desktop file
	domenu usr/share/applications/brave-browser-stable.desktop

	# Install documentation (decompress changelog)
	pushd usr/share/doc/${PF} >/dev/null || die
	gunzip changelog.gz || die "Failed to decompress changelog"
	popd >/dev/null || die
	dodoc -r usr/share/doc/${PF}/*

	# Install man page (decompress first)
	pushd usr/share/man/man1 >/dev/null || die
	gunzip brave-browser-stable.1.gz || die "Failed to decompress man page"
	popd >/dev/null || die
	doman usr/share/man/man1/brave-browser-stable.1

	# Fix sandbox permissions if file exists (removed in newer versions)
	if [[ -f opt/brave.com/brave/brave-sandbox ]]; then
		fperms 4755 /opt/brave.com/brave/brave-sandbox || die
	fi

	pax-mark -m "${ED}"/opt/brave.com/brave/brave
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update

	elog
	elog "Brave has been installed."
	elog
	elog "If you experience any problems with Brave, please report them at:"
	elog "https://github.com/brave/brave-browser/issues"
	elog
	elog "You can customize Brave's command-line options by creating a"
	elog "~/.config/brave-flags.conf file with your preferred flags, one per line."
	elog
	elog "Example flags:"
	elog "  --enable-features=VaapiVideoDecoder  # Enable VA-API video decoding"
	elog "  --disable-gpu-driver-bug-workarounds # Disable GPU driver bug workarounds"
	elog

	if use keyring; then
		elog "You have enabled the 'keyring' USE flag."
		elog "Brave will store passwords in your system keyring (GNOME Keyring, KWallet, etc.)"
		elog
	fi
}
