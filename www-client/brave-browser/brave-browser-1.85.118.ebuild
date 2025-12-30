# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
PYTHON_REQ_USE="ncurses"

CHROMIUM_LANGS="
	af am ar bg bn ca cs da de el en-GB en-US es es-419 et fa fi fil fr gu he hi
	hr hu id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr sv
	sw ta te th tr uk ur vi zh-CN zh-TW
"

inherit check-reqs chromium-2 desktop flag-o-matic llvm-r1 multiprocessing ninja-utils pax-utils python-any-r1 qmake-utils readme.gentoo-r1 toolchain-funcs xdg-utils

DESCRIPTION="Privacy-focused browser based on Chromium with built-in ad blocking"
HOMEPAGE="https://brave.com/"

if [[ ${PV} == *9999 ]]; then
	EGIT_REPO_URI="https://github.com/brave/brave-browser.git"
	inherit git-r3
else
	BRAVE_TAG="${PV}"
	SRC_URI="https://github.com/brave/brave-browser/archive/v${BRAVE_TAG}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm64"
	S="${WORKDIR}/${PN}-${BRAVE_TAG}"
fi

LICENSE="MPL-2.0"
SLOT="0"
IUSE="+component-build cups cpu_flags_arm_neon debug +hangouts kerberos libcxx +lto +official +pax-kernel pgo +proprietary-codecs pulseaudio +rewards +js-optimize screencast selinux +system-toolchain tor vaapi vpn +wallet +widevine"

REQUIRED_USE="
	component-build? ( !official )
	libcxx? ( || ( system-toolchain clang ) )
	pgo? ( official )
	x64-macos? ( !system-toolchain )
	!system-toolchain? ( clang )
"

COMMON_DEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	app-arch/bzip2:=
	cups? ( >=net-print/cups-1.7.0:= )
	dev-libs/expat:=
	dev-libs/glib:2
	dev-libs/libxml2:=[icu]
	dev-libs/libxslt:=
	dev-libs/nspr:=
	>=dev-libs/nss-3.26:=
	dev-libs/re2:=
	>=media-libs/alsa-lib-1.0.19:=
	media-libs/fontconfig:=
	media-libs/freetype:=
	>=media-libs/harfbuzz-3.0.0:=[icu(-)]
	media-libs/libjpeg-turbo:=
	media-libs/libpng:=
	media-libs/libwebp:=
	media-libs/mesa:=[gbm(+)]
	>=media-libs/openh264-1.6.0:=
	pulseaudio? ( media-libs/libpulse:= )
	sys-apps/dbus:=
	sys-apps/pciutils:=
	sys-libs/zlib:=[minizip]
	virtual/udev
	x11-libs/cairo:=
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3[X]
	x11-libs/libdrm:=
	x11-libs/libX11:=
	x11-libs/libxcb:=
	x11-libs/libXcomposite:=
	x11-libs/libXcursor:=
	x11-libs/libXdamage:=
	x11-libs/libXext:=
	x11-libs/libXfixes:=
	x11-libs/libXi:=
	x11-libs/libXrandr:=
	x11-libs/libXrender:=
	x11-libs/libXScrnSaver:=
	x11-libs/libXtst:=
	x11-libs/pango:=
	kerberos? ( virtual/krb5 )
	vaapi? ( >=media-libs/libva-2.7:=[X] )
	screencast? ( media-video/pipewire:= )
	selinux? ( sec-policy/selinux-chromium )
"
RDEPEND="${COMMON_DEPEND}
	virtual/ttf-fonts
	selinux? ( sec-policy/selinux-chromium )
"
DEPEND="${COMMON_DEPEND}
	!www-client/brave-bin
"
BDEPEND="
	${PYTHON_DEPS}
	$(python_gen_any_dep '
		dev-python/setuptools[${PYTHON_USEDEP}]
	')
	>=dev-build/gn-0.2193
	dev-lang/perl
	>=dev-util/gperf-3.1
	>=dev-util/ninja-1.7.2
	>=net-libs/nodejs-24.0.0[ssl]
	>=sys-devel/bison-3.8.2
	sys-devel/flex
	virtual/pkgconfig
	clang? (
		sys-devel/clang:=
		sys-devel/lld
		pgo? ( sys-libs/compiler-rt-sanitizers[profile] )
	)
"

if ! has chromium ${INHERITED}; then
	BDEPEND+=" $(llvm_gen_dep '
		sys-devel/clang:${LLVM_SLOT}
		sys-devel/llvm:${LLVM_SLOT}
		clang? (
			sys-devel/lld:${LLVM_SLOT}
			pgo? ( sys-libs/compiler-rt-sanitizers:${LLVM_SLOT}[profile] )
		)
	')"
fi

# Chromium/Brave is extremely resource intensive
# RAM: 8GB (minimum), 16GB+ (recommended)
# Disk: 100GB+ free space for build
CHECKREQS_MEMORY="16G"
CHECKREQS_DISK_BUILD="100G"

DISABLE_AUTOFORMATTING="yes"
DOC_CONTENTS="
Some web pages may require additional fonts to display properly.
Try installing some of the following packages if some characters
are not displayed properly:
- media-fonts/arphicfonts
- media-fonts/droid
- media-fonts/ipamonafont
- media-fonts/noto
- media-fonts/ja-ipafonts
- media-fonts/takao-fonts
- media-fonts/wqy-microhei
- media-fonts/wqy-zenhei

To fix broken icons on the Downloads page, you should install an icon
theme that covers the XDG icon naming specification, e.g. package x11-themes/adwaita-icon-theme.
"

python_check_deps() {
	python_has_version "dev-python/setuptools[${PYTHON_USEDEP}]"
}

needs_lld() {
	# https://bugs.gentoo.org/918897#c32
	tc-ld-is-lld || use clang
}

llvm_check_deps() {
	if ! has_version -b "sys-devel/clang:${LLVM_SLOT}" ; then
		einfo "sys-devel/clang:${LLVM_SLOT} is missing! Cannot use LLVM slot ${LLVM_SLOT} ..." >&2
		return 1
	fi

	if use clang && ! has_version -b "sys-devel/lld:${LLVM_SLOT}" ; then
		einfo "sys-devel/lld:${LLVM_SLOT} is missing! Cannot use LLVM slot ${LLVM_SLOT} ..." >&2
		return 1
	fi

	if use pgo ; then
		if ! has_version -b "sys-libs/compiler-rt-sanitizers:${LLVM_SLOT}[profile]" ; then
			einfo "sys-libs/compiler-rt-sanitizers:${LLVM_SLOT}[profile] is missing! Cannot use LLVM slot ${LLVM_SLOT} ..." >&2
			return 1
		fi
	fi

	einfo "Using LLVM slot ${LLVM_SLOT} to build" >&2
}

pkg_pretend() {
	check-reqs_pkg_pretend
}

pkg_setup() {
	check-reqs_pkg_setup
	python-any-r1_pkg_setup
	chromium_suid_sandbox_check_kernel_config
	llvm-r1_pkg_setup
}

src_unpack() {
	if [[ ${PV} == *9999 ]]; then
		git-r3_src_unpack
	else
		default
	fi
}

src_prepare() {
	# Apply Chromium patches if available
	# Most Chromium patches should apply to Brave
	default

	# Create .gclient configuration for Brave
	cat > .gclient <<-EOF || die
	solutions = [
	  {
	    "name": "src/brave",
	    "url": "https://github.com/brave/brave-core.git",
	    "managed": False,
	    "custom_deps": {},
	    "custom_vars": {},
	  },
	]
	EOF

	# Respect user's CC, CXX, AR, NM, RANLIB
	tc-export AR CC CXX NM RANLIB

	# Prevent automagic dependencies on zstd
	sed -i -e '/zstd/d' build/linux/unbundle/BUILD.gn || die

	mkdir -p third_party/node/linux/node-linux-x64/bin || die
	ln -s "${EPREFIX}"/usr/bin/node third_party/node/linux/node-linux-x64/bin/node || die

	# Brave-specific preparations
	pushd brave >/dev/null || die
	# Apply any Brave-specific patches here
	popd >/dev/null || die

	# Remove bundled libraries
	python_fix_shebang build/landmines.py
	python_fix_shebang tools/protoc_wrapper/protoc_wrapper.py
	python_fix_shebang third_party/depot_tools/
}

src_configure() {
	# Set up build environment
	tc-export AR CC CXX NM

	# Use system toolchain if requested
	if use system-toolchain; then
		# Ensure we're using system compiler
		export CC="${CC:-gcc}"
		export CXX="${CXX:-g++}"
		export AR="${AR:-ar}"
		export NM="${NM:-nm}"
		export RANLIB="${RANLIB:-ranlib}"
	fi

	if use clang; then
		export CC=clang
		export CXX=clang++
		export AR=llvm-ar
		export NM=llvm-nm
		export RANLIB=llvm-ranlib
		strip-unsupported-flags
	fi

	local myconf_gn=""

	# GN bootstrap variables
	myconf_gn+=" custom_toolchain=\"//build/toolchain/linux/unbundle:default\""
	myconf_gn+=" host_toolchain=\"//build/toolchain/linux/unbundle:default\""

	myconf_gn+=" is_official_build=$(usex official true false)"
	myconf_gn+=" use_thin_lto=$(usex lto true false)"
	myconf_gn+=" is_debug=$(usex debug true false)"
	myconf_gn+=" use_cups=$(usex cups true false)"
	myconf_gn+=" use_kerberos=$(usex kerberos true false)"
	myconf_gn+=" use_pulseaudio=$(usex pulseaudio true false)"
	myconf_gn+=" use_vaapi=$(usex vaapi true false)"
	myconf_gn+=" rtc_use_pipewire=$(usex screencast true false)"
	myconf_gn+=" enable_hangout_services_extension=$(usex hangouts true false)"
	myconf_gn+=" enable_widevine=$(usex widevine true false)"
	myconf_gn+=" use_system_zlib=true"
	myconf_gn+=" use_system_freetype=true"
	myconf_gn+=" use_system_harfbuzz=true"
	myconf_gn+=" use_system_libjpeg=true"
	myconf_gn+=" use_system_libpng=true"
	myconf_gn+=" use_system_libwebp=true"
	myconf_gn+=" enable_nacl=false"
	myconf_gn+=" optimize_webui=$(usex js-optimize true false)"
	myconf_gn+=" ffmpeg_branding=\"Chrome\""
	myconf_gn+=" proprietary_codecs=$(usex proprietary-codecs true false)"
	myconf_gn+=" is_component_build=$(usex component-build true false)"
	myconf_gn+=" use_allocator=\"none\""
	myconf_gn+=" symbol_level=$(usex debug 2 0)"
	myconf_gn+=" v8_symbol_level=$(usex debug 2 0)"
	myconf_gn+=" is_clang=$(usex clang true false)"
	myconf_gn+=" use_lld=$(usex clang true false)"
	myconf_gn+=" treat_warnings_as_errors=false"
	myconf_gn+=" use_custom_libcxx=$(usex libcxx true false)"

	# Brave-specific options
	myconf_gn+=" brave_chromium_build=true"
	myconf_gn+=" brave_google_api_endpoint=\"\""
	myconf_gn+=" brave_google_api_key=\"\""
	myconf_gn+=" brave_infura_project_id=\"\""
	myconf_gn+=" brave_services_key=\"\""
	myconf_gn+=" brave_stats_api_key=\"\""
	myconf_gn+=" brave_stats_updater_url=\"\""

	# Brave optional components
	myconf_gn+=" brave_rewards_enabled=$(usex rewards true false)"
	myconf_gn+=" brave_wallet_enabled=$(usex wallet true false)"
	myconf_gn+=" enable_tor=$(usex tor true false)"
	myconf_gn+=" enable_brave_vpn=$(usex vpn true false)"

	# Set flags
	if use official; then
		myconf_gn+=" is_official_build=true"
		append-cppflags -DOFFICIAL_BUILD
	fi

	# Architecture-specific settings
	if use arm64; then
		myconf_gn+=" target_cpu=\"arm64\""
		if use cpu_flags_arm_neon; then
			myconf_gn+=" arm_use_neon=true"
		fi
	else
		myconf_gn+=" target_cpu=\"x64\""
	fi

	einfo "Configuring Brave with GN arguments:"
	einfo "${myconf_gn}"

	# Set up build directory
	set -- gn gen out/Release --args="${myconf_gn}"
	echo "$@"
	"$@" || die "GN configuration failed"
}

src_compile() {
	# Build Brave
	eninja -C out/Release chrome chrome_sandbox chromedriver
}

src_install() {
	local BRAVE_HOME="/usr/$(get_libdir)/brave-browser"

	exeinto "${BRAVE_HOME}"
	doexe out/Release/brave || die

	if use suid; then
		newexe out/Release/chrome_sandbox chrome-sandbox
		fperms 4755 "${BRAVE_HOME}/chrome-sandbox"
	fi

	doexe out/Release/chromedriver || die

	# Install resources
	insinto "${BRAVE_HOME}"
	doins out/Release/*.pak
	doins out/Release/*.bin

	# Install V8 snapshots
	if [[ -f out/Release/snapshot_blob.bin ]]; then
		doins out/Release/snapshot_blob.bin
	fi

	# Install locales
	insinto "${BRAVE_HOME}/locales"
	doins out/Release/locales/*.pak

	# Install resources directory
	if [[ -d out/Release/resources ]]; then
		insinto "${BRAVE_HOME}/resources"
		doins -r out/Release/resources/*
	fi

	# Install MEI Preload
	if [[ -d out/Release/MEIPreload ]]; then
		insinto "${BRAVE_HOME}/MEIPreload"
		doins -r out/Release/MEIPreload/*
	fi

	# Install WidevineCdm
	if use widevine && [[ -d out/Release/WidevineCdm ]]; then
		insinto "${BRAVE_HOME}/WidevineCdm"
		doins -r out/Release/WidevineCdm/*
	fi

	# Install icons
	local size
	for size in 24 48 64 128 256; do
		newicon -s ${size} "brave/app/theme/brave/product_logo_${size}.png" brave-browser.png
	done

	# Install desktop file
	make_desktop_entry \
		brave-browser \
		"Brave Web Browser" \
		brave-browser \
		"Network;WebBrowser" \
		"MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;\nStartupWMClass=brave-browser"

	# Install wrapper script
	dodir /usr/bin
	cat > "${ED}/usr/bin/brave-browser" <<-EOF || die
		#!/bin/sh
		exec ${BRAVE_HOME}/brave "\$@"
	EOF
	fperms +x /usr/bin/brave-browser

	# Install man page
	doman brave/app/resources/manpage.1.in

	readme.gentoo_create_doc
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update
	readme.gentoo_print_elog

	if use component-build; then
		ewarn
		ewarn "You have enabled the 'component-build' USE flag."
		ewarn "This is only intended for development and debugging."
		ewarn "You may experience crashes and other issues."
		ewarn
	fi

	if ! use official; then
		ewarn
		ewarn "You are using an unofficial build of Brave."
		ewarn "Some features may not work as expected."
		ewarn
	fi

	if use pax-kernel; then
		elog
		elog "For PaX users:"
		elog "If you experience problems with Brave, you may need to disable"
		elog "some PaX features. Please see:"
		elog "https://wiki.gentoo.org/wiki/Chromium#PaX"
		elog
	fi
}
