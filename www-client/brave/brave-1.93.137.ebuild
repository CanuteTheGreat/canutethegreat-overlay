# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# PACKAGING NOTES
#
# Brave = brave-core (MPL-2.0) on top of a *specific* Chromium release. Upstream drives the
# build with `npm run init` (gclient sync of Chromium + ~12 extra git repos + npm install),
# which needs the network. Here that is replaced by plain distfiles:
#
#  * chromium-${CHROMIUM_PV}-linux.tar.xz  - the very tarball ::gentoo's www-client/chromium
#    uses (chromium-linux-tarballs CI). Brave pins the exact Chromium version in
#    brave-core/package.json (config.projects.chrome.tag); a Brave bump normally only builds
#    cleanly when ::gentoo already packages that Chromium *and* a chromium-patches-<n> exists
#    for it, so PV <-> CHROMIUM_PV <-> PATCH_V move together.
#  * brave-core-${PV}.tar.xz               - `git archive` of brave-core at tag v${PV}.
#  * brave-deps-${PV}.tar.xz               - brave-core/DEPS git deps + npm node_modules for the
#    web-UI build; generated reproducibly by .ci/make-brave-distfiles.sh (see README).
#
# Everything ::gentoo's chromium does for system clang/lld/rust/bindgen, the unbundling list
# and the GN toolchain wiring is reused. Differences:
#  * Brave's own patches (brave-core/patches, applied with GNU patch instead of gclient's git
#    patcher) go on top of the pristine tree, before the Gentoo ones.
#  * No USE=official: Brave's official build asserts that private service keys are set
#    (brave_services_key, sync/stats/wallet/rewards keys). We build with Brave's public
#    defaults only (is_official_build=false, no keys), so Brave services that need a key are
#    inert. No PGO: Brave/Chromium profile data is fetched by a gclient hook.
#  * No bundled toolchain, no headless-only/ppc64/arm64 (Brave's ffmpeg Chrome-branding
#    configs are only patched for x64/arm64; only amd64 is tested).
#  * Bundled in-tree libraries that MUST stay bundled are listed in keeplibs (copied from
#    chromium); the Brave-owned trees (brave/third_party, brave/vendor) are moved out of the way
#    while remove_bundled_libraries.py runs.

CHROMIUM_PV="151.0.7922.169"
PATCH_V="151-3"
COPIUM_COMMIT="3c7e56fb4523b43b47595bb3a22f77178fc76293"
GN_MIN_VER=0.2374
NODE_VER="24.12.0"
GO_MIN_VER="1.25.0"
ESBUILD_VER="0.25.1"
# Brave builds its wasm modules (skus, ...) with cargo + wasm-bindgen/wasm-pack from vendored crates, and
# needs a cargo+rustc with the wasm32-unknown-unknown std at //third_party/rust-toolchain. Official
# rust-bin has no wasm std, so the matching official rust-std tarball is added on top of a copy of rust-bin.
WASM_RUST_VER="1.94.1"
ROLLUP_VER="4.57.1" # currently manual.

CHROMIUM_LANGS="af am ar bg bn ca cs da de el en-GB es es-419 et fa fi fil fr gu he
	hi hr hu id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr
	sv sw ta te th tr uk ur vi zh-CN zh-TW"

LLVM_COMPAT=( 21 )
PYTHON_COMPAT=( python3_{11..14} )
PYTHON_REQ_USE="xml(+)"
RUST_MIN_VER=1.91.0
RUST_NEEDS_LLVM="yes please"
RUST_REQ_USE="rustfmt" # Upstream run rustfmt on bindgen output, so we need it to be available.

inherit check-reqs chromium-2 desktop flag-o-matic llvm-r1 ninja-utils pax-utils
inherit python-any-r1 readme.gentoo-r1 rust toolchain-funcs xdg-utils

DESCRIPTION="Privacy-focused web browser built from the Brave and Chromium source"
HOMEPAGE="https://brave.com/ https://github.com/brave/brave-core"

# Private Forgejo release (owner overlay only; nothing is published publicly). Portage cannot fetch
# from a private repo without credentials: either set a FETCHCOMMAND/token for git.canutethegreat.com
# or drop the two files into DISTDIR by hand (see the overlay README).
BRAVE_DIST_URI="https://git.canutethegreat.com/CanuteTheGreat/gentoo-submissions/releases/download/brave-${PV}"
SRC_URI="
	https://github.com/chromium-linux-tarballs/chromium-tarballs/releases/download/${CHROMIUM_PV}/chromium-${CHROMIUM_PV}-linux.tar.xz
	https://deps.gentoo.zip/www-client/chromium/rollup-wasm-node-${ROLLUP_VER}.tgz
	https://gitlab.com/Matt.Jolly/chromium-patches/-/archive/${PATCH_V}/chromium-patches-${PATCH_V}.tar.bz2
	https://codeberg.org/selfisekai/copium/archive/${COPIUM_COMMIT}.tar.gz
		-> chromium-patches-copium-${COPIUM_COMMIT:0:10}.tar.gz
	${BRAVE_DIST_URI}/brave-core-${PV}.tar.xz
	${BRAVE_DIST_URI}/brave-deps-${PV}.tar.xz
	https://static.rust-lang.org/dist/rust-std-${WASM_RUST_VER}-wasm32-unknown-unknown.tar.xz
"
S="${WORKDIR}/chromium-${CHROMIUM_PV}"

# Brave itself: MPL-2.0. Chromium's licence set as generated for ::gentoo's chromium
# (chromium-tools get-chromium-licences.py), plus what brave-core adds: its vendored crates and
# git deps (bitcoin-core MIT, argon2 Apache-2.0/CC0, ethash Apache-2.0, librustzcash MIT/Apache,
# tweetnacl public-domain) and the npm packages bundled into WebUI resources (MIT/ISC/Apache/BSD/0BSD).
LICENSE="MPL-2.0 Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Base64 Boost-1.0 CC-BY-3.0 CC-BY-4.0 Clear-BSD FFT2D FTL"
LICENSE+=" IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 Ms-PL PSF-2 SGI-B-2.0 SSLeay SunSoft Unicode-3.0"
LICENSE+=" Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB libtiff openssl 0BSD CC0-1.0 public-domain"

SLOT="0"
KEYWORDS="~amd64"

IUSE_SYSTEM_LIBS="+system-harfbuzz +system-zstd"
IUSE="+X ${IUSE_SYSTEM_LIBS} cups debug gtk4 kerberos pax-kernel pulseaudio qt6 +screencast selinux +vaapi +wayland +widevine"
# bindist: the ffmpeg in the tree is built with proprietary codecs (Brave patches the Chrome-branding configs).
RESTRICT="bindist mirror test"  # private distfile host: never mirror

REQUIRED_USE="
	|| ( X wayland )
	screencast? ( wayland )
"

COMMON_X_DEPEND="
	x11-libs/libXcomposite:=
	x11-libs/libXcursor:=
	x11-libs/libXdamage:=
	x11-libs/libXfixes:=
	>=x11-libs/libXi-1.6.0:=
	x11-libs/libXrandr:=
	x11-libs/libXrender:=
	x11-libs/libXtst:=
	x11-libs/libxshmfence:=
"

# sys-libs/zlib: https://bugs.gentoo.org/930365; -ng is not compatible.
COMMON_SNAPSHOT_DEPEND="
	>=dev-libs/libxml2-2.12.4:=[icu]
	dev-libs/icu:=
	dev-libs/nspr:=
	>=dev-libs/nss-3.26:=
	dev-libs/libxslt:=
	media-libs/fontconfig:=
	>=media-libs/freetype-2.11.0-r1:=
	system-harfbuzz? ( >=media-libs/harfbuzz-3:0=[icu(-)] )
	media-libs/libjpeg-turbo:=
	system-zstd? ( >=app-arch/zstd-1.5.5:= )
	>=media-libs/libwebp-0.4.0:=
	media-libs/mesa:=[gbm(+)]
	>=media-libs/openh264-2.6.0:=
	sys-libs/zlib:=
	dev-libs/glib:2
	>=media-libs/alsa-lib-1.0.19:=
	media-video/pipewire:=
	pulseaudio? ( media-libs/libpulse:= )
	sys-apps/pciutils:=
	kerberos? ( virtual/krb5 )
	vaapi? ( >=media-libs/libva-2.7:=[X?,wayland?] )
	X? (
		x11-base/xorg-proto:=
		x11-libs/libX11:=
		x11-libs/libxcb:=
		x11-libs/libXext:=
	)
	x11-libs/libxkbcommon:=
	wayland? (
		dev-libs/libffi:=
		dev-libs/wayland:=
	)
"

COMMON_DEPEND="
	${COMMON_SNAPSHOT_DEPEND}
	app-arch/bzip2:=
	dev-libs/expat:=
	net-misc/curl[ssl]
	sys-apps/dbus:=
	media-libs/flac:=
	sys-libs/zlib:=[minizip]
	>=app-accessibility/at-spi2-core-2.46.0:2
	media-libs/mesa:=[X?,wayland?]
	virtual/udev
	x11-libs/cairo:=
	x11-libs/gdk-pixbuf:2
	x11-libs/pango:=
	cups? ( >=net-print/cups-1.3.11:= )
	qt6? ( dev-qt/qtbase:6[gui,widgets] )
	X? ( ${COMMON_X_DEPEND} )
"
RDEPEND="${COMMON_DEPEND}
	|| (
		x11-libs/gtk+:3[X?,wayland?]
		gui-libs/gtk:4[X?,wayland?]
	)
	qt6? ( dev-qt/qtbase:6[X?,wayland?] )
	virtual/ttf-fonts
	selinux? ( sec-policy/selinux-chromium )
"
DEPEND="${COMMON_DEPEND}
	media-video/pipewire
	gtk4? ( gui-libs/gtk:4[X?,wayland?] )
	!gtk4? ( x11-libs/gtk+:3[X?,wayland?] )
"

BDEPEND="
	${COMMON_SNAPSHOT_DEPEND}
	${PYTHON_DEPS}
	$(python_gen_any_dep '
		dev-python/setuptools[${PYTHON_USEDEP}]
	')
	>=app-arch/gzip-1.7
	qt6? ( dev-qt/qtbase:6 )
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}
		llvm-core/llvm:${LLVM_SLOT}
		llvm-core/lld:${LLVM_SLOT}
	')
	>=dev-util/bindgen-0.72.1
	>=dev-build/gn-${GN_MIN_VER}
	>=dev-lang/go-${GO_MIN_VER}
	app-alternatives/ninja
	dev-lang/perl
	>=dev-util/gperf-3.2
	dev-util/esbuild:${ESBUILD_VER}
	dev-lang/rust-bin:${WASM_RUST_VER}[rustfmt]
	dev-vcs/git
	>=net-libs/nodejs-${NODE_VER}[inspector,npm]
	sys-apps/hwdata
	>=sys-devel/bison-2.4.3
	sys-devel/flex
	virtual/pkgconfig
	x11-misc/xdg-utils
"

if ! has chromium_pkg_die ${EBUILD_DEATH_HOOKS}; then
	EBUILD_DEATH_HOOKS+=" chromium_pkg_die";
fi

DISABLE_AUTOFORMATTING="yes"
DOC_CONTENTS="
Brave and www-client/brave-bin keep their profile in the same directory
(~/.config/BraveSoftware/Brave-Browser). Do not run both at once and do not
downgrade (e.g. from brave-bin to an older source build) with a profile in use.

Some web pages may require additional fonts to display properly.
Try installing some of the following packages if some characters
are not displayed properly:
- media-fonts/noto
- media-fonts/ja-ipafonts
- media-fonts/wqy-microhei

To make password storage work with your desktop environment you may
have install one of the supported credentials management applications:
- app-crypt/libsecret (GNOME)
- kde-frameworks/kwallet (KDE)

Command line flags can be put into ~/.config/brave-flags.conf (one per line).

This build uses Brave's public defaults only: it carries no Brave
service keys, so features that need them (e.g. the Brave Search API
integrations, Rewards, Sync server auth, wallet RPC proxies) are inert.
"

python_check_deps() {
	python_has_version "dev-python/setuptools[${PYTHON_USEDEP}]"
}

pre_build_checks() {
	# Chromium-scale build: bugs #471810, #541816, #914220.
	# Measured on a no-LTO build, see the submission README for numbers.
	local base_disk=12 # chromium source ~9G unpacked + brave-core/deps
	local extra_disk=25 # out/Release
	local memory=4
	if tc-is-lto; then
		memory=$((memory * 2 + 1))
		extra_disk=$((extra_disk + 10))
	fi
	local CHECKREQS_MEMORY="${memory}G"
	local CHECKREQS_DISK_BUILD="$((base_disk + extra_disk))G"
	check-reqs_${EBUILD_PHASE_FUNC}
}

pkg_pretend() {
	if [[ ${MERGE_TYPE} != binary ]]; then
		pre_build_checks
	fi
}

pkg_setup() {
	if [[ ${MERGE_TYPE} != binary ]]; then
		pre_build_checks

		local want_lto="false"
		tc-is-lto && want_lto="true"

		llvm-r1_pkg_setup
		rust_pkg_setup

		if tc-ld-is-mold; then
			ewarn "Mold is currently not supported, it will not be used"
		fi

		# The linux:unbundle toolchain in GN grabs CC, CXX, CPP (etc) from the environment
		AR=llvm-ar
		CPP="${CHOST}-clang++-${LLVM_SLOT} -E"
		NM=llvm-nm
		CC="${CHOST}-clang-${LLVM_SLOT}"
		CXX="${CHOST}-clang++-${LLVM_SLOT}"

		# LTO in Chromium means LLVM ThinLTO
		use_lto="false"
		if [[ "${want_lto}" == "true" ]]; then
			use_lto="true"
			# We can rely on GN to do this for us; without this builds
			# take significantly longer with LTO enabled.
			filter-lto
		fi
		export use_lto

		# Required for Split LTO units and other nightly-only rustc flags Chromium passes.
		export RUSTC_BOOTSTRAP=1

		if ver_test $(gn --version || die) -lt ${GN_MIN_VER}; then
			die "dev-build/gn >= ${GN_MIN_VER} is required to build this Chromium"
		fi

		if tc-ld-is-lld; then
			local lld_ver=$(ld.lld --version | awk '{split($2,a,"."); print a[1]}' || die "Failed to check lld version")
			if [[ ${lld_ver} -lt ${LLVM_SLOT} ]]; then
				die "Your lld version (${lld_ver}) is too old for the selected LLVM slot (${LLVM_SLOT})."
			fi
		fi
	fi

	chromium_suid_sandbox_check_kernel_config
}

src_unpack() {
	unpack chromium-${CHROMIUM_PV}-linux.tar.xz
	unpack chromium-patches-${PATCH_V}.tar.bz2
	unpack chromium-patches-copium-${COPIUM_COMMIT:0:10}.tar.gz
	unpack brave-core-${PV}.tar.xz
	unpack brave-deps-${PV}.tar.xz
	unpack rollup-wasm-node-${ROLLUP_VER}.tgz
	unpack rust-std-${WASM_RUST_VER}-wasm32-unknown-unknown.tar.xz
}

remove_compiler_builtins() {
	# We can't use the bundled compiler builtins with the system toolchain
	local pattern='    configs += [ "//build/config/clang:compiler_builtins" ]'
	local target='build/config/compiler/BUILD.gn'

	local tmpfile
	tmpfile=$(mktemp) || die "Failed to create temporary file."

	if awk -v pat="${pattern}" '
	BEGIN { match_found = 0 }
	d > 0 { d--; next }
	$0 == pat { match_found = 1; d = 2; prev = ""; next }
	NR > 1 { print prev }
	{ prev = $0 }
	END {
		if (d == 0) { print prev }
		if (match_found == 0) { exit 1 }
	}
	' "${target}" > "${tmpfile}"; then
		mv "${tmpfile}" "${target}"
	else
		rm -f "${tmpfile}"
		die "Awk patch failed: Pattern not found in ${target}."
	fi
}

# Brave's patches are one-file git diffs, generated against a full Chromium checkout (and, for the
# subdirectories, against the matching third_party repo); brave-core's own util.js applies them
# with `git apply` per directory. Same layout here, with GNU patch. The Linux tarball carries
# neither android/ nor ios/ nor chrome/test/data, so patches for files below those are skipped;
# a missing file anywhere else is a real error.
apply_brave_patches_in() { # <patch dir> (cwd = matching Chromium directory)
	local p f missing skipped=0
	for p in "${1}"/*.patch; do
		missing=
		while read -r f; do
			if [[ ! -e ${f} ]]; then
				if [[ ${f} =~ ^(chrome/android/|ios/|chrome/test/data/|.*/android/) ]]; then
					missing=skip
				else
					die "${p##*/}: target ${f} is missing"
				fi
			fi
		done < <(sed -n 's|^--- a/||p' "${p}")
		if [[ -n ${missing} ]]; then
			(( skipped++ ))
			continue
		fi
		eapply "${p}"
	done
	einfo "skipped ${skipped} Brave patches for android/ios/test-data files absent from the Linux tarball"
}

apply_brave_patches() {
	local pdir="${S}/brave/patches" rel
	apply_brave_patches_in "${pdir}"
	for rel in v8 third_party/ffmpeg third_party/catapult third_party/devtools-frontend/src \
			third_party/search_engines_data/resources; do
		[[ -d ${pdir}/${rel} ]] || continue
		pushd "${S}/${rel}" >/dev/null || die
		apply_brave_patches_in "${pdir}/${rel}"
		popd >/dev/null || die
	done
}

src_prepare() {
	# Calling this here supports resumption via FEATURES=keepwork
	python_setup

	# Brave tree: brave-core lives in src/brave, its extra deps are laid over it.
	mv "${WORKDIR}/brave-core-${PV}" brave || die
	cp -a "${WORKDIR}/brave-deps-${PV}/." brave/ || die
	rm -r "${WORKDIR}/brave-deps-${PV}" || die

	# Rollup (see chromium ebuild): needed before patching.
	einfo "Moving rollup wasm-node package into place ..."
	mkdir -p third_party/devtools-frontend/src/node_modules/@rollup/wasm-node ||
		die "Failed to create node_modules/@rollup/wasm-node"
	mv "${WORKDIR}"/package/* third_party/devtools-frontend/src/node_modules/@rollup/wasm-node ||
		die "Failed to move rollup package"

	apply_brave_patches

	local PATCHES=(
		"${WORKDIR}/chromium-patches-${PATCH_V}/common/"
		"${WORKDIR}/copium/cr143-libsync-__BEGIN_DECLS.patch"
		"${WORKDIR}/copium/cr149-unbundle-minizip-undo-unicode.patch"
	)

	# Automate conditional application of chromium-patches (toolchain/, llvm/lt-N/ ...).
	shopt -s nullglob
	local -A slot_map=( [llvm]="${LLVM_SLOT}" [rust]="${RUST_SLOT}" )
	local category category_name category_patches constraint_dir dir_name
	for category in "${WORKDIR}/chromium-patches-${PATCH_V}"/*/; do
		category_name="${category%/}"
		category_name="${category_name##*/}"
		[[ ${category_name} == ppc64le || ${category_name} == common ]] && continue
		category_patches=( "${category}"*.patch )
		[[ ${#category_patches[@]} -gt 0 ]] && PATCHES+=( "${category}" )
		for constraint_dir in "${category}"*/; do
			dir_name="${constraint_dir%/}"
			dir_name="${dir_name##*/}"
			if [[ "${dir_name}" =~ ^lt-(.*)$ && -v slot_map[${category_name}] ]]; then
				ver_test "${slot_map[${category_name}]}" -lt "${BASH_REMATCH[1]}" &&
					PATCHES+=( "${constraint_dir}" )
			fi
		done
	done
	shopt -u nullglob

	# Upstream 151.0.7922.169 already has the icui18n_hidden_visibility group in unbundle/icu.gn
	# that cr131-unbundle-icu-target.patch adds: applying it would define the group twice.
	if grep -q 'group("icui18n_hidden_visibility")' build/linux/unbundle/icu.gn; then
		rm "${WORKDIR}/chromium-patches-${PATCH_V}/common/cr131-unbundle-icu-target.patch" || die
	fi

	remove_compiler_builtins

	# We can't rely on the eselect'd Rust to actually include rustfmt, so we'll point to the selected slot specifically.
	local suffix=""
	if [[ "${RUST_TYPE}" == "binary" ]]; then
		suffix="-bin-${RUST_SLOT}"
	else
		suffix="-${RUST_SLOT}"
	fi
	sed -i "s|/bin/rustfmt|/bin/rustfmt${suffix}|g" build/rust/rust_bindgen_generator.gni ||
		die "Failed to update rustfmt path"

	default

	# //brave:create_dist (deb/rpm/zip packaging, not built here) depends on //chrome/installer/linux,
	# whose BUILD.gn cannot even be loaded with use_sysroot=false (rebase_path of an empty sysroot).
	sed -i '/"\/\/chrome\/installer\/linux:\$linux_channel",/d' brave/BUILD.gn || die

	# What `brave/build/util/version.py update` does (it wants a git checkout): keep the
	# upstream chrome/VERSION as chrome/VERSION.chromium and store the Brave version in
	# MINOR/BUILD/PATCH of chrome/VERSION (MAJOR stays the Chromium milestone).
	cp chrome/VERSION chrome/VERSION.chromium || die
	sed -i -e "s/^MINOR=.*/MINOR=$(ver_cut 1)/" -e "s/^BUILD=.*/BUILD=$(ver_cut 2)/" \
		-e "s/^PATCH=.*/PATCH=$(ver_cut 3)/" chrome/VERSION || die

	# Brave hook `brave_version_gni`: //brave/build/version.gni from chrome/VERSION{,.chromium}.
	pushd brave >/dev/null || die
	${EPYTHON} build/util/version.py gen ../chrome/VERSION || die "Failed to generate brave version.gni"

	# Brave's branding step (`branding.update()` in build/commands/lib/branding.js): overlays the
	# Brave strings (.grd/.xtb), theme, logos and vector icons onto the Chromium tree. Run Brave's
	# own code rather than re-implementing the file map; it locates the tree through
	# <root>/src/brave, so give it a src symlink. Needs only node + the vendored node_modules.
	ln -s "${S##*/}" "${WORKDIR}/src" || die
	node --input-type=module -e \
		'import branding from "./build/commands/lib/branding.js"; branding.update()' ||
		die "Brave branding step failed"
	popd >/dev/null || die

	# Sanity check esbuild version before we start removing files.
	local esbuild_js="${S}/third_party/devtools-frontend/src/node_modules/esbuild/lib/main.js"
	local found
	found=$(awk -F'"' '/if \(binaryVersion !==/ {print $2}' "${esbuild_js}")
	if [[ "${found}" != "${ESBUILD_VER}" ]]; then
		die "esbuild version mismatch: expected ${ESBUILD_VER}, found ${found}"
	fi

	elog "Removing bundled binaries from source tree ..."
	# Purge bundled ELF files from the Chromium tree. brave/ is excluded here: its node_modules
	# are handled below.
	${EPYTHON} "${FILESDIR}/bin-finder.py" --elf "${S}" | awk '{print $1}' |
		grep -v -F "${S}/brave/" | xargs rm -f || die "Failed to remove bundled binaries"

	# And now we restore any that we actually need, from the host system
	local esbuild_path="${S}/third_party/devtools-frontend/src/third_party/esbuild"
	local -A restore_list=(
		["/usr/bin/esbuild-${ESBUILD_VER}"]="${esbuild_path}/esbuild"
		["/usr/bin/gperf"]="${S}/third_party/gperf/cipd/bin/gperf"
		["/usr/bin/node"]="${S}/third_party/node/linux/node-linux-x64/bin/node"
	)
	local src dst
	for src in "${!restore_list[@]}"; do
		dst="${restore_list[${src}]}"
		if [[ -f "${src}" ]]; then
			einfo "Symlinking ${src} ..."
			mkdir -p "$(dirname "${dst}")" || die "Failed to create directory for ${dst}"
			ln -s "${src}" "${dst}" || die "Failed to symlink ${dst} from ${src}"
		else
			die "Expected to find ${src} to restore ${dst}, but it does not exist."
		fi
	done

	# adjust python interpreter version
	sed -i -e "s|\(^script_executable = \).*|\1\"${EPYTHON}\"|g" .gn || die

	# Use the system copy of hwdata's usb.ids
	sed 's|//third_party/usb_ids/src/usb.ids|/usr/share/hwdata/usb.ids|g' \
		-i services/device/public/cpp/usb/BUILD.gn || die "Failed to set system usb.ids path"

	# remove_bundled_libraries.py walks the source tree and looks for paths containing the substring 'third_party'
	# whitelist matches use the right-most matching path component, so we need to whitelist from that point down.
	# These are the libraries that MUST stay bundled (same list as ::gentoo chromium-151).
	local keeplibs=(
		base/third_party/cityhash
		base/third_party/double_conversion
		base/third_party/icu
		base/third_party/nspr
		base/third_party/superfasthash
		base/third_party/symbolize
		base/third_party/xdg_user_dirs
		buildtools/third_party/libc++
		buildtools/third_party/libc++abi
		net/third_party/mozilla_security_manager
		net/third_party/quic
		net/third_party/uri_template
		third_party/abseil-cpp
		third_party/angle
		third_party/angle/src/common/third_party/xxhash
		third_party/angle/src/third_party/ceval
		third_party/angle/src/third_party/libXNVCtrl
		third_party/angle/src/third_party/volk
		third_party/anonymous_tokens
		third_party/apple_apsl
		third_party/axe-core
		third_party/bidimapper
		third_party/blink
		third_party/boringssl
		third_party/boringssl/src/third_party/fiat
		third_party/breakpad
		third_party/breakpad/breakpad/src/third_party/curl
		third_party/brotli
		third_party/catapult
		third_party/catapult/common/py_vulcanize/third_party/rcssmin
		third_party/catapult/common/py_vulcanize/third_party/rjsmin
		third_party/catapult/third_party/beautifulsoup4-4.9.3
		third_party/catapult/third_party/html5lib-1.1
		third_party/catapult/third_party/polymer
		third_party/catapult/third_party/six
		third_party/catapult/third_party/typ
		third_party/catapult/tracing/third_party/d3
		third_party/catapult/tracing/third_party/gl-matrix
		third_party/catapult/tracing/third_party/jpeg-js
		third_party/catapult/tracing/third_party/jszip
		third_party/catapult/tracing/third_party/mannwhitneyu
		third_party/catapult/tracing/third_party/oboe
		third_party/catapult/tracing/third_party/pako
		third_party/ced
		third_party/cld_3
		third_party/closure_compiler
		third_party/compiler-rt # Since M137 atomic is required; we could probably unbundle this as a target of opportunity.
		third_party/content_analysis_sdk
		third_party/cpuinfo
		third_party/crabbyavif
		third_party/crashpad
		third_party/crashpad/crashpad/third_party/lss
		third_party/crashpad/crashpad/third_party/zlib
		third_party/crc32c
		third_party/cros_system_api
		third_party/d3
		third_party/dav1d
		third_party/dawn
		third_party/dawn/third_party/gn/webgpu-cts
		third_party/dawn/third_party/OpenGL-Registry
		third_party/dawn/third_party/renderdoc
		third_party/dawn/third_party/webgpu-headers
		third_party/depot_tools
		third_party/devscripts
		third_party/devtools-frontend
		third_party/devtools-frontend/src/front_end/third_party/acorn
		third_party/devtools-frontend/src/front_end/third_party/additional_readme_paths.json
		third_party/devtools-frontend/src/front_end/third_party/axe-core
		third_party/devtools-frontend/src/front_end/third_party/chromium
		third_party/devtools-frontend/src/front_end/third_party/codemirror
		third_party/devtools-frontend/src/front_end/third_party/csp_evaluator
		third_party/devtools-frontend/src/front_end/third_party/diff
		third_party/devtools-frontend/src/front_end/third_party/i18n
		third_party/devtools-frontend/src/front_end/third_party/intl-messageformat
		third_party/devtools-frontend/src/front_end/third_party/json5
		third_party/devtools-frontend/src/front_end/third_party/legacy-javascript
		third_party/devtools-frontend/src/front_end/third_party/lighthouse
		third_party/devtools-frontend/src/front_end/third_party/lit
		third_party/devtools-frontend/src/front_end/third_party/marked
		third_party/devtools-frontend/src/front_end/third_party/puppeteer
		third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib/third_party/mitt
		third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib/third_party/parsel-js
		third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib/third_party/rxjs
		third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib/third_party/urlpattern-polyfill
		third_party/devtools-frontend/src/front_end/third_party/source-map-scopes-codec
		third_party/devtools-frontend/src/front_end/third_party/third-party-web
		third_party/devtools-frontend/src/front_end/third_party/vscode.web-custom-data
		third_party/devtools-frontend/src/front_end/third_party/wasmparser
		third_party/devtools-frontend/src/front_end/third_party/web-vitals
		third_party/devtools-frontend/src/third_party
		third_party/dom_distiller_js
		third_party/dragonbox
		third_party/eigen3
		third_party/emoji-segmenter
		third_party/farmhash
		third_party/fast_float
		third_party/fdlibm
		third_party/federated_compute/chromium/fcp/confidentialcompute
		third_party/federated_compute/chromium/fcp/protos
		third_party/federated_compute/chromium/fcp/secagg
		third_party/federated_compute/chromium/fcp/client
		third_party/federated_compute/src/fcp/base
		third_party/federated_compute/src/fcp/confidentialcompute
		third_party/federated_compute/src/fcp/protos
		third_party/federated_compute/src/fcp/client
		third_party/federated_compute/src/fcp/secagg
		third_party/federated_compute/third_party/googleapis/src/google
		third_party/federated_compute/third_party/tensorflow-federated
		third_party/federated_compute/third_party/protodatastore-cpp
		third_party/ffmpeg
		third_party/fft2d
		third_party/flatbuffers
		third_party/fp16
		third_party/freetype
		third_party/fusejs
		third_party/fxdiv
		third_party/gemmlowp
		third_party/google_input_tools
		third_party/google_input_tools/third_party/closure_library
		third_party/google_input_tools/third_party/closure_library/third_party/closure
		third_party/googletest
		third_party/gperf # We symlink system gperf, but this will purge the symlink since we tidy up afterwards.
		third_party/highway
		third_party/hunspell
		third_party/ink/src/ink/brush
		third_party/ink/src/ink/color
		third_party/ink/src/ink/geometry
		third_party/ink/src/ink/rendering
		third_party/ink/src/ink/rendering/skia/common_internal
		third_party/ink/src/ink/rendering/skia/native
		third_party/ink/src/ink/rendering/skia/native/internal
		third_party/ink/src/ink/strokes
		third_party/ink/src/ink/types
		third_party/inspector_protocol
		third_party/ipcz
		third_party/jinja2
		third_party/jsoncpp
		third_party/khronos
		third_party/lens_server_proto
		third_party/leveldatabase
		third_party/libaddressinput
		third_party/libaom
		third_party/libaom/source/libaom/third_party/fastfeat
		third_party/libaom/source/libaom/third_party/vector
		third_party/libaom/source/libaom/third_party/x86inc
		third_party/libc++
		third_party/libdrm
		third_party/libgav1
		third_party/libjingle
		third_party/libpfm4
		third_party/libphonenumber
		third_party/libpng
		third_party/libsecret
		third_party/libsrtp
		third_party/libsync
		third_party/libtess2/libtess2
		third_party/libtess2/src/Include
		third_party/libtess2/src/Source
		third_party/liburlpattern
		third_party/libva_protected_content
		third_party/libvpx
		third_party/libvpx/source/libvpx/third_party/x86inc
		third_party/libwebm
		third_party/libx11
		third_party/libxcb-keysyms
		third_party/libxml/chromium
		third_party/libyuv
		third_party/libzip
		third_party/lit
		third_party/llvm-libc
		third_party/llvm-libc/src/shared/
		third_party/lottie
		third_party/lss
		third_party/lzma_sdk
		third_party/mako
		third_party/markupsafe
		third_party/material_color_utilities
		third_party/metrics_proto
		third_party/minigbm
		third_party/ml_dtypes
		third_party/modp_b64
		third_party/nasm
		third_party/nearby
		third_party/neon_2_sse
		third_party/node
		third_party/oak/chromium/proto
		third_party/oak/chromium/proto/attestation
		third_party/omnibox_proto
		third_party/one_euro_filter
		third_party/openscreen
		third_party/openscreen/src/third_party/
		third_party/openscreen/src/third_party/tinycbor/src/src
		third_party/opus
		third_party/ots
		third_party/pdfium
		third_party/pdfium/third_party/agg23
		third_party/pdfium/third_party/bigint
		third_party/pdfium/third_party/freetype
		third_party/pdfium/third_party/lcms
		third_party/pdfium/third_party/libopenjpeg
		third_party/pdfium/third_party/libtiff
		third_party/perfetto
		third_party/perfetto/protos/third_party/android
		third_party/perfetto/protos/third_party/chromium
		third_party/perfetto/protos/third_party/pprof
		third_party/perfetto/protos/third_party/primes
		third_party/perfetto/protos/third_party/simpleperf
		third_party/pffft
		third_party/ply
		third_party/polymer
		third_party/private_membership
		third_party/private-join-and-compute
		third_party/protobuf
		third_party/protobuf/third_party/utf8_range
		third_party/pthreadpool
		third_party/puffin
		third_party/pyjson5
		third_party/pyyaml
		third_party/rapidhash
		third_party/re2
		third_party/readability
		third_party/rnnoise
		third_party/rust
		third_party/ruy
		third_party/s2cellid
		third_party/search_engines_data
		third_party/securemessage
		third_party/selenium-atoms
		third_party/sentencepiece
		third_party/sentencepiece/src/third_party/darts_clone
		third_party/shell-encryption
		third_party/simdutf
		third_party/simplejson
		third_party/six
		third_party/skia
		third_party/skia/include/third_party/vulkan
		third_party/smhasher
		third_party/snappy
		third_party/spirv-headers
		third_party/spirv-tools
		third_party/sqlite
		third_party/swiftshader
		third_party/swiftshader/third_party/astc-encoder
		third_party/swiftshader/third_party/llvm-subzero
		third_party/swiftshader/third_party/marl
		third_party/swiftshader/third_party/SPIRV-Headers/include/spirv
		third_party/swiftshader/third_party/SPIRV-Tools
		third_party/swiftshader/third_party/subzero
		third_party/tensorflow_models
		third_party/tensorflow-text
		third_party/tflite
		third_party/tflite/src/third_party/fft2d
		third_party/tflite/src/third_party/xla/third_party/tsl
		third_party/tflite/src/third_party/xla/xla/tsl/framework
		third_party/tflite/src/third_party/xla/xla/tsl/lib/random
		third_party/tflite/src/third_party/xla/xla/tsl/platform
		third_party/tflite/src/third_party/xla/xla/tsl/protobuf
		third_party/tflite/src/third_party/xla/xla/tsl/util
		third_party/ukey2
		third_party/utf
		third_party/vulkan
		third_party/wayland
		third_party/webdriver
		third_party/webgpu-cts
		third_party/webrtc
		third_party/webrtc/common_audio/third_party/ooura
		third_party/webrtc/common_audio/third_party/spl_sqrt_floor
		third_party/webrtc/modules/third_party/fft
		third_party/webrtc/modules/third_party/g711
		third_party/webrtc/modules/third_party/g722
		third_party/widevine
		third_party/woff2
		third_party/wuffs
		third_party/x11proto
		third_party/xcbproto
		third_party/xnnpack
		third_party/zlib/google
		third_party/zxcvbn-cpp
		url/third_party/mozilla
		v8/third_party/glibc
		v8/third_party/inspector_protocol
		v8/third_party/rapidhash-v8
		v8/third_party/siphash
		v8/third_party/utf8-decoder
		v8/third_party/v8
		v8/third_party/valgrind

		# gyp -> gn leftovers
		third_party/speech-dispatcher
		third_party/usb_ids
	)

	# USE=system-*
	if ! use system-harfbuzz; then
		keeplibs+=( third_party/harfbuzz )
	fi

	# ICU stays bundled: Blink, autofill, url_formatter and brave:brave_dist_resources need the
	# icudtl.dat data file target of the in-tree third_party/icu (system ICU has no such file).
	keeplibs+=( third_party/icu )

	if ! use system-zstd; then
		keeplibs+=( third_party/zstd )
	fi

	# Sanity check keeplibs, on major version bumps it is often necessary to update this list
	local whitelist_libs=(
		net/third_party/quic
		third_party/devtools-frontend/src/front_end/third_party/additional_readme_paths.json
		third_party/libjingle
		third_party/mesa
		third_party/skia/third_party/vulkan
		third_party/vulkan
	)
	local lib not_found_libs=()
	for lib in "${keeplibs[@]}"; do
		if [[ ! -d "${lib}" ]] && ! has "${lib}" "${whitelist_libs[@]}"; then
			not_found_libs+=( "${lib}" )
		fi
	done

	if [[ ${#not_found_libs[@]} -gt 0 ]]; then
		eerror "The following \`keeplibs\` directories were not found in the source tree:"
		for lib in "${not_found_libs[@]}"; do
			eerror "  ${lib}"
		done
		die "Please update the ebuild."
	fi

	# Remove most bundled libraries. Some are still needed.
	# brave/ (its third_party/ + vendor/ + node_modules) is Brave's own code and not subject to
	# unbundling: move it out of the way, remove_bundled_libraries.py would delete all of it.
	einfo "Unbundling third-party libraries ..."
	mv brave "${WORKDIR}/brave-aside" || die
	build/linux/unbundle/remove_bundled_libraries.py "${keeplibs[@]}" --do-remove || die
	mv "${WORKDIR}/brave-aside" brave || die

	# Rust toolchain for Brave's wasm crates (see WASM_RUST_VER): a copy of rust-bin plus the wasm32 std.
	einfo "Assembling third_party/rust-toolchain with wasm32-unknown-unknown std ..."
	cp -a "${EPREFIX}/opt/rust-bin-${WASM_RUST_VER}" third_party/rust-toolchain || die
	cp -a "${WORKDIR}/rust-std-${WASM_RUST_VER}-wasm32-unknown-unknown/rust-std-wasm32-unknown-unknown/lib/rustlib/wasm32-unknown-unknown" \
		third_party/rust-toolchain/lib/rustlib/ || die

	# Interferes with our bundled clang path; we don't want stripped binaries anyway.
	sed -i -e 's|${clang_base_path}/bin/llvm-strip|/bin/true|g' \
		-e 's|${clang_base_path}/bin/llvm-objcopy|/bin/true|g' \
		build/linux/strip_binary.gni || die
}

src_configure() {
	# Calling this here supports resumption via FEATURES=keepwork
	python_setup

	# 974899: sometimes people try to build with a non-Unicode locale and python gets very upset
	python_export_utf8_locale || die "Chromium builds require a UTF-8 locale."

	local -x PYTHONPATH="${S}/brave/script:${S}/tools/grit/grit/extern:${S}/build:${S}/third_party/depot_tools"

	# Bug 491582.
	export TMPDIR="${WORKDIR}/temp"
	mkdir -p -m 755 "${TMPDIR}" || die

	# https://bugs.gentoo.org/654216
	addpredict /dev/dri/ #nowarn

	# Use system-provided libraries (see keeplibs for what stays bundled; protobuf, sqlite,
	# hunspell, harfbuzz(optional), ffmpeg, libvpx, dav1d, ... stay bundled: no system target
	# in build/linux/unbundle, or Chromium patches them).
	local gn_system_libraries=(
		flac
		fontconfig
		freetype
		libjpeg
		libwebp
		libxml
		libxslt
		openh264
		zlib
	)
	use system-zstd && gn_system_libraries+=( zstd )

	build/linux/unbundle/replace_gn_files.py --system-libraries "${gn_system_libraries[@]}" ||
		die "Failed to replace GN files for system libraries"

	# The above call clobbers `enable_freetype = true` in the freetype gni file
	local freetype_gni="build/config/freetype/freetype.gni"
	sed -i -e '$d' ${freetype_gni} || die
	echo "  enable_freetype = true" >> ${freetype_gni} || die
	echo "}" >> ${freetype_gni} || die

	replace-flags "-Os" "-O2"
	strip-flags
	# Debug info section overflows without component build
	# Prevent linker from running out of address space, bug #471810 .
	filter-flags "-g*"
	# 949123: several multimedia components build with specific CFLAGS and use runtime detection.
	filter-flags "-march*" "-mtune*" "-mcpu*"

	# We don't use the same clang version as upstream, and with -Werror
	# we need to make sure that we don't get superfluous warnings.
	append-flags -Wno-unknown-warning-option

	# Make sure the build system will use the right tools, bug #340795.
	tc-export AR CC CXX NM

	strip-unsupported-flags
	append-ldflags -Wl,--undefined-version # https://bugs.gentoo.org/918897#c32

	filter-flags -mno-mmx -mno-sse2 -mno-ssse3 -mno-sse4.1 \
		-mno-avx -mno-avx2 -mno-fma -mno-fma4 -mno-xop -mno-sse4a

	# Brave's GN defaults (public ones; no keys): root_extra_deps //brave, proprietary codecs
	# with ffmpeg_branding=Chrome, widevine CDM loader, safe_browsing_mode=1, ...
	local myconf_gn=(
		'import("//brave/build/args/brave_defaults.gni")'
		'import("//brave/build/args/blink_platform_defaults.gni")'
		'import("//brave/build/args/branding_defaults.gni")'
		'import("//brave/build/args/desktop_defaults.gni")'
		'brave_channel=""'

		"is_clang=true"
		"clang_use_chrome_plugins=false"
		"use_clang_modules=false" # M141 enables this for the linux platform by default.
		'custom_toolchain="//build/toolchain/linux/unbundle:default"'
		'host_toolchain="//build/toolchain/linux/unbundle:default"'
		# From M127 we need to provide a location for libclang and the clang resource dir so that bindgen can find them
		"bindgen_libclang_path=\"$(get_llvm_prefix)/$(get_libdir)\""
		"bindgen_clang_resource_dir=\"${EPREFIX}/usr/lib/clang/${LLVM_SLOT}/include\""
		"bindgen_extra_clang_args=[\"-I${EPREFIX}/usr/lib/clang/${LLVM_SLOT}/include\"]"
		"clang_base_path=\"${EPREFIX}/usr/lib/clang/${LLVM_SLOT}/\""
		"rust_bindgen_root=\"${EPREFIX}/usr/\""
		"rust_sysroot_absolute=\"$(get_rust_prefix)\""
		"rustc_version=\"${RUST_SLOT}\""
		"use_lld=true"
		"use_mold=false" # defaults to true since M151 and needs a bundled mold binary
		'target_cpu="x64"'

		# Disable code formating of generated files
		"blink_enable_generated_code_formatting=false"
		# enable DCHECK with USE=debug only, increases binary size by 30%, bug #811138.
		"dcheck_always_on=$(usex debug true false)"
		"dcheck_is_configurable=$(usex debug true false)"
		# Distro builds must not use the field-trial testing config
		"disable_fieldtrial_testing_config=true"
		"enable_freetype=true"
		# Don't need nocompile checks and GN crashes with our config
		"enable_nocompile_tests=false"
		"enable_pseudolocales=false"
		"enable_widevine=$(usex widevine true false)"
		# Disable fatal linker warnings, bug 506268.
		"fatal_linker_warnings=false"
		"is_component_build=false"
		"is_debug=false"
		# Brave's official build asserts that private service keys are set. We have none, so
		# stay with the non-official build type (Brave's own default) and no API keys.
		"is_official_build=false"
		"symbol_level=0"
		"blink_symbol_level=0"
		"v8_symbol_level=0"
		"chrome_pgo_phase=0"
		"ozone_auto_platforms=false"
		"ozone_platform_headless=true"
		"safe_browsing_use_unrar=false"
		"thin_lto_enable_optimizations=${use_lto}"
		"use_thin_lto=${use_lto}"
		"treat_warnings_as_errors=false"
		# Use in-tree libc++ (forced since 120)
		"use_custom_libcxx=true"
		"use_ozone=true"
		# The sysroot is the oldest debian image that chromium supports, we don't need it
		"use_sysroot=false"
		"use_system_harfbuzz=$(usex system-harfbuzz true false)"
		"v8_use_libm_trig_functions=true"
		"tint_use_system_go=true"

		"gtk_version=$(usex gtk4 4 3)"
		# link pulseaudio directly (DT_NEEDED) instead of using dlopen.
		"link_pulseaudio=$(usex pulseaudio true false)"
		"ozone_platform_wayland=$(usex wayland true false)"
		"ozone_platform_x11=$(usex X true false)"
		"ozone_platform=\"$(usex wayland wayland x11)\""
		"rtc_use_pipewire=$(usex screencast true false)"
		"rtc_link_pipewire=$(usex screencast true false)"
		"use_cups=$(usex cups true false)"
		"use_kerberos=$(usex kerberos true false)"
		"use_pulseaudio=$(usex pulseaudio true false)"
		"use_qt5=false"
		"use_system_libffi=$(usex wayland true false)"
		"use_system_minigbm=true"
		"use_vaapi=$(usex vaapi true false)"
		"use_xkbcommon=true"
	)

	if use qt6; then
		myconf_gn+=(
			"use_qt6=true"
			"moc_qt6_path=\"${EPREFIX}/usr/$(get_libdir)/qt6/libexec\""
		)
	else
		myconf_gn+=( "use_qt6=false" )
	fi

	# LLVM < 23: workaround for -fsanitize-ignore-for-ubsan-feature
	[[ ${LLVM_SLOT} -lt 23 ]] && myconf_gn+=( 'clang_has_ubsan_feature_ignore=false' )

	einfo "Configuring Brave ..."
	set -- gn gen --args="${myconf_gn[*]}${EXTRA_GN:+ ${EXTRA_GN}}" out/Release
	echo "$@"
	"$@" || die "Failed to configure Brave"
}

src_compile() {
	# Final link uses lots of file descriptors.
	ulimit -n 2048

	# Calling this here supports resumption via FEATURES=keepwork
	python_setup

	# Don't inherit PYTHONPATH from environment, bug #789021, #812689; use Brave's own
	# (build/commands/lib/config.ts): brave_chromium_utils & co. live in brave/script.
	local -x PYTHONPATH="${S}/brave/script:${S}/tools/grit/grit/extern:${S}/build:${S}/third_party/depot_tools"

	# Brave's GN actions run `node` and `npm` from PATH (web UI transpile, brave_node.py).
	# Build mksnapshot and pax-mark it.
	if use pax-kernel; then
		local x
		for x in mksnapshot v8_context_snapshot_generator code_cache_generator; do
			eninja -C out/Release "${x}"
			pax-mark m "out/Release/${x}"
		done
	fi

	# Even though ninja autodetects number of CPUs, we respect
	# user's options, for debugging with -j 1 or any other reason.
	eninja -C out/Release brave chrome_sandbox

	pax-mark m out/Release/brave
	rm -f out/Release/locales/*.pak.info || die
}

src_install() {
	local BRAVE_HOME="/usr/$(get_libdir)/brave"

	exeinto "${BRAVE_HOME}"
	doexe out/Release/brave
	doexe out/Release/chrome_crashpad_handler
	# Setuid sandbox, only used if unprivileged user namespaces are unavailable.
	newexe out/Release/chrome_sandbox chrome-sandbox
	fperms 4755 "${BRAVE_HOME}/chrome-sandbox"

	cat > "${T}/brave" <<-EOF || die
		#!/bin/sh
		# Allow users to override command-line options
		flags_file="\${XDG_CONFIG_HOME:-\$HOME/.config}/brave-flags.conf"
		if [ -r "\${flags_file}" ]; then
			BRAVE_FLAGS="\$(grep -v '^#' "\${flags_file}" | tr '\\n' ' ')"
		fi
		export CHROME_WRAPPER="\$(readlink -f "\$0")"
		export CHROME_DESKTOP="brave-browser.desktop"
		# BRAVE_FLAGS is deliberately unquoted so each flag is its own argument
		exec ${BRAVE_HOME}/brave \${BRAVE_FLAGS} "\$@"
	EOF
	dobin "${T}/brave"

	pushd out/Release/locales > /dev/null || die
	chromium_remove_language_paks
	popd > /dev/null || die

	insinto "${BRAVE_HOME}"
	doins out/Release/*.bin
	doins out/Release/*.pak

	(
		shopt -s nullglob
		local files=(out/Release/*.so out/Release/*.so.[0-9])
		[[ ${#files[@]} -gt 0 ]] && doins "${files[@]}"
	)

	doins out/Release/icudtl.dat

	doins -r out/Release/locales
	doins -r out/Release/MEIPreload

	# Install vk_swiftshader_icd.json; bug #827861
	doins out/Release/vk_swiftshader_icd.json

	if [[ -d out/Release/swiftshader ]]; then
		insinto "${BRAVE_HOME}/swiftshader"
		doins out/Release/swiftshader/*.so
	fi

	# Icons (Brave ships release-channel logos in brave/app/theme/brave)
	local size
	for size in 16 24 32 48 64 128 256 ; do
		newicon -s ${size} "brave/app/theme/brave/product_logo_${size}.png" brave.png
	done

	make_desktop_entry brave "Brave Web Browser" brave \
		"Network;WebBrowser" \
		"MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;\nStartupWMClass=Brave-browser"

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

	# Sandbox: Brave uses the user-namespace sandbox when the kernel has USER_NS/PID_NS/NET_NS/SECCOMP_FILTER
	# and falls back to the setuid helper below. Never rely on --no-sandbox.
	if [[ ! -u ${EROOT}/usr/$(get_libdir)/brave/chrome-sandbox ]]; then
		ewarn "${EROOT}/usr/$(get_libdir)/brave/chrome-sandbox is not setuid root;"
		ewarn "without user namespaces Brave will refuse to start. Fix: chmod 4755 on it."
	else
		elog "chrome-sandbox is installed setuid root (the fallback when unprivileged user"
		elog "namespaces are unavailable; with USER_NS enabled Brave uses those instead)."
	fi

	if use vaapi && [[ -z "${REPLACING_VERSIONS}" ]]; then
		elog "Hardware-accelerated video decoding: add to ~/.config/brave-flags.conf, e.g."
		elog "   --enable-features=AcceleratedVideoDecodeLinuxGL"
		elog "(VA-API with Vulkan on X11: --enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE)"
	fi
	if use screencast; then
		elog "Screencast is disabled by default at runtime. Enable it with"
		elog "--enable-features=WebRTCPipeWireCapturer."
	fi
}
