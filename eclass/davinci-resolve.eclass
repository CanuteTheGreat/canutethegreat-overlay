# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: davinci-resolve.eclass
# @MAINTAINER:
# Ronald Farrer <canutethegreat@gmail.com>
# @SUPPORTED_EAPIS: 8
# @BLURB: shared install logic for DaVinci Resolve (free) and DaVinci Resolve Studio
# @DESCRIPTION:
# Both editions ship as the same makeself/AppImage installer inside a zip that
# Blackmagic only hands out after a registration form. The package name
# decides the edition: media-video/davinci-resolve (free) or
# media-video/davinci-resolve-studio. Both install into /opt/davinci-resolve
# and block each other. Two packages (not a USE flag) so that
# `ebuild ... manifest` only needs the one archive the owner actually has.
# Layout knowledge cross-checked against the ::gentoo-zh and AUR packagings.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_DAVINCI_RESOLVE_ECLASS} ]]; then
_DAVINCI_RESOLVE_ECLASS=1

inherit desktop udev xdg

# Blackmagic names the archive after PV without a trailing ".0"
# (21.1.0 -> 21.1): DaVinci_Resolve_<ver>_Linux.zip and
# DaVinci_Resolve_Studio_<ver>_Linux.zip
MY_PV=${PV%.0}
if [[ ${PN} == *-studio ]]; then
	_DR_NAME="DaVinci Resolve Studio"
	ZIP_NAME="DaVinci_Resolve_Studio_${MY_PV}_Linux.zip"
	_DR_OTHER=davinci-resolve
else
	_DR_NAME="DaVinci Resolve"
	ZIP_NAME="DaVinci_Resolve_${MY_PV}_Linux.zip"
	_DR_OTHER=davinci-resolve-studio
fi
DR_PN=davinci-resolve	# install prefix /opt/${DR_PN} for both editions

DESCRIPTION="Professional video editing, colour, effects and audio post-production"
HOMEPAGE="https://www.blackmagicdesign.com/products/davinciresolve"
SRC_URI="${ZIP_NAME}"
S=${WORKDIR}

LICENSE="all-rights-reserved"
SLOT="0"
IUSE="video_cards_amdgpu video_cards_intel video_cards_nvidia"
# One GPU compute stack is mandatory: Resolve refuses to start without CUDA/OpenCL.
REQUIRED_USE="|| ( video_cards_amdgpu video_cards_intel video_cards_nvidia )"
# bindist/mirror: proprietary. strip: the bundled libraries are prebuilt and
# must stay byte-identical to what Blackmagic ships.
RESTRICT="bindist fetch mirror strip"

# Everything below /opt is prebuilt; its bundled libraries (Qt, ffmpeg, libc++ ...)
# satisfy each other through RPATH.
QA_PREBUILT="opt/${DR_PN}/*"
QA_FLAGS_IGNORED="opt/${DR_PN}/.*"

BDEPEND="
	app-arch/unzip
	dev-util/patchelf
"
RDEPEND="
	!media-video/${_DR_OTHER}
	acct-group/video
	app-arch/bzip2
	app-arch/xz-utils
	app-crypt/mit-krb5
	app-misc/ca-certificates
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	media-libs/glu
	media-libs/libglvnd
	media-libs/libpulse
	sys-apps/dbus
	sys-apps/util-linux
	sys-devel/gcc:*[openmp]
	sys-libs/mtdev
	virtual/libcrypt:=
	virtual/opencl
	virtual/udev
	virtual/zlib:=
	x11-libs/libdrm
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXext
	x11-libs/libXi
	x11-libs/libXrender
	x11-libs/libXt
	x11-libs/libXtst
	x11-libs/libXxf86vm
	x11-libs/libxkbcommon[X]
	x11-libs/libxkbfile
	x11-libs/xcb-util
	x11-libs/xcb-util-cursor
	x11-libs/xcb-util-image
	x11-libs/xcb-util-keysyms
	x11-libs/xcb-util-renderutil
	x11-libs/xcb-util-wm
	video_cards_amdgpu? ( dev-libs/rocm-opencl-runtime )
	video_cards_intel? ( dev-libs/intel-compute-runtime )
	video_cards_nvidia? ( x11-drivers/nvidia-drivers )
"

davinci-resolve_pkg_nofetch() {
	local zip=${ZIP_NAME}

	einfo "DaVinci Resolve cannot be downloaded automatically: Blackmagic only"
	einfo "gives out the archive after a registration form."
	einfo
	einfo "  1. Open https://www.blackmagicdesign.com/support/family/davinci-resolve-and-fusion"
	einfo "  2. Pick ${_DR_NAME} ${MY_PV} -> Linux,"
	einfo "     fill in the form and download the archive."
	einfo "  3. Save it as exactly:"
	einfo
	einfo "       ${DISTDIR}/${zip}"
	einfo
	einfo "  4. Create the Manifest entry (thin Manifests: not shipped by the overlay):"
	einfo
	einfo "       ebuild \$(portageq get_repo_path / canutethegreat-overlay)/${CATEGORY}/${PN}/${PF}.ebuild manifest"
	einfo
	einfo "     and re-run emerge. Studio additionally needs a licence"
	einfo "     (dongle, Blackmagic Cloud or activation code)."
}

davinci-resolve_src_unpack() {
	local zip=${ZIP_NAME} run
	run=${zip%.zip}.run

	unpack "${zip}"
	[[ -f ${run} ]] || die "${zip} does not contain ${run}"
	chmod u+x "${run}" || die
	# makeself/AppImage installer: unpack the payload without installing
	"./${run}" --appimage-extract || die "extracting ${run} failed"
}

_is_elf() {
	[[ -f ${1} && $(LC_ALL=C od -An -tx1 -N4 "${1}" 2>/dev/null) == *"7f 45 4c 46"* ]]
}

# _set_rpath <rpath> <file>...
_set_rpath() {
	local rpath=${1} f
	shift
	for f; do
		[[ -e ${f} ]] || continue
		_is_elf "${f}" || continue
		patchelf --force-rpath --set-rpath "${rpath}" "${f}" \
			|| die "patchelf failed on ${f}"
	done
}

# Blackmagic's build machines leave their own paths in some RPATHs.
_has_bad_rpath() {
	local rpath
	rpath=$(patchelf --print-rpath "${1}" 2>/dev/null) || return 1
	[[ ${rpath} == *"/home/"* || ${rpath} == *"/persistent/"* ||
		${rpath} == *"/var/lib/jenkins/"* || ${rpath} == *"/xxxxxxxx"* ||
		${rpath} == *@loader_path* || ${rpath} == *"/lib/qt-"* ]]
}

# _sanitize_bad_rpaths <dir> <rpath>
_sanitize_bad_rpaths() {
	local f
	[[ -d ${1} ]] || return 0
	while IFS= read -r -d '' f; do
		_is_elf "${f}" || continue
		_has_bad_rpath "${f}" || continue
		_set_rpath "${2}" "${f}"
	done < <(find "${1}" -type f -print0)
}

davinci-resolve_src_prepare() {
	default

	local sq=squashfs-root inst=/opt/${DR_PN} f
	[[ -d ${sq} ]] || die "no ${sq}: archive layout changed?"
	chmod -R u+rwX "${sq}" || die

	# control panel SDK ships as a tarball inside the archive
	mkdir "${sq}/panel-framework" || die
	tar -xzf "${sq}/share/panels/dvpanel-framework-linux-x86_64.tgz" \
		-C "${sq}/panel-framework" || die
	chmod -R u+rwX "${sq}/panel-framework" || die
	rm -f "${sq}/share/panels/dvpanel-framework-linux-x86_64.tgz" || die

	# installer scaffolding and things the system provides
	rm -rf "${sq}"/{installer*,AppRun*,CentOSUpdate} || die
	rm -f "${sq}/DaVinci Control Panels Setup/libk5crypto.so.3" \
		"${sq}/share/DaVinciResolveInstaller.desktop" \
		"${sq}/scripts/"{pre_install.sh,post_install.sh,uninstall.sh} \
		"${sq}/bin/sqlite3" || die
	# the CUDA Blackmagic RAW decoder is useless (and links libcuda) without NVIDIA
	if ! use video_cards_nvidia; then
		rm -f "${sq}"/{BlackmagicRAWPlayer,BlackmagicRAWSpeedTest}/BlackmagicRawAPI/libDecoderCUDA.so \
			"${sq}/libs/libDecoderCUDA.so" || die
	fi
	# bundled glib stack clashes with the system pango/gdk-pixbuf (crash on
	# start on current distributions): use the system copies
	rm -f "${sq}"/libs/lib{glib,gio,gmodule,gobject}-2.0.so* || die

	_set_rpath '$ORIGIN/../libs:$ORIGIN/../libs/Fusion' \
		"${sq}/bin/resolve" "${sq}/Onboarding/DaVinci_Resolve_Welcome"
	_set_rpath '$ORIGIN/lib' \
		"${sq}/panel-framework/libDaVinciPanelAPI.so" \
		"${sq}/panel-framework/libFairlightPanelAPI.so"
	while IFS= read -r -d '' f; do
		_set_rpath '$ORIGIN' "${f}"
	done < <(find "${sq}" -type f \( -name 'libc++abi.so*' -o -name libgcc_s.so.1 \
		-o -name 'libCrmSdk.so.*' -o -name 'libcrypto.so.*' -o -name libcurl.so \
		-o -name 'libssl.so.*' -o -name libxmlsec1-openssl.so \) -print0)
	_sanitize_bad_rpaths "${sq}/libs" '$ORIGIN:$ORIGIN/Fusion'
	_sanitize_bad_rpaths "${sq}/plugins" '$ORIGIN:$ORIGIN/../libs'
	_sanitize_bad_rpaths "${sq}/Onboarding" \
		"\$ORIGIN:${inst}/libs:${inst}/libs/Fusion"

	ln -s ../BlackmagicRAWPlayer/BlackmagicRawAPI "${sq}/bin/BlackmagicRawAPI" || die

	# desktop entries: point at the installed prefix and the PATH wrappers
	while IFS= read -r -d '' f; do
		sed -i "s|RESOLVE_INSTALL_LOCATION|${inst}|g" "${f}" || die
	done < <(find "${sq}/share" -type f \
		\( -name '*.desktop' -o -name '*.directory' -o -name '*.menu' \) -print0)
	_fix_desktop DaVinciResolve "davinci-resolve %u" davinci-resolve
	_fix_desktop DaVinciResolveCaptureLogs davinci-resolve-capture-logs davinci-resolve
	_fix_desktop DaVinciControlPanelsSetup davinci-control-panels-setup davinci-resolve-panels-setup
	_fix_desktop blackmagicraw-player "blackmagicraw-player %f" blackmagicraw-player
	_fix_desktop blackmagicraw-speedtest "blackmagicraw-speedtest %f" blackmagicraw-speedtest
	sed -i 's/^Categories=Video$/Categories=AudioVideo;Video;/' \
		"${sq}"/share/blackmagicraw-{player,speedtest}.desktop || die
	echo "StartupWMClass=resolve" >> "${sq}/share/DaVinciResolve.desktop" || die

	# udev: upstream ships world-writable rules (MODE 0666). Give the
	# logged-in seat user access (uaccess) instead.
	local rules=( "${sq}"/share/etc/udev/rules.d/*.rules )
	[[ -e ${rules[0]} ]] || die "no udev rules in archive"
	# (Gentoo has no plugdev group either: uaccess replaces it.)
	sed -i -E -e 's/,? *MODE *= *"0?666"/, TAG+="uaccess"/' \
		-e 's/,? *GROUP *= *"plugdev"//' "${rules[@]}" || die
	cat > "${sq}/share/etc/udev/rules.d/75-sdx.rules" <<-'EOF' || die
		# Blackmagic Design USB devices (panels, keyboards, cameras)
		SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="096e", TAG+="uaccess"
	EOF
	if grep -q -E 'MODE *= *"?0?666' "${rules[@]}"; then
		die "world-writable udev rule left over"
	fi
}

# _fix_desktop <basename> <Exec> <Icon>
_fix_desktop() {
	local file=squashfs-root/share/${1}.desktop
	[[ -f ${file} ]] || die "${file} missing"
	sed -i -e "s|^Exec=.*|Exec=${2}|" -e "s|^Icon=.*|Icon=${3}|" \
		-e '/^Path=/d' -e '/^TryExec=/d' "${file}" || die
}

_newlib_ldscript() {
	insinto "/usr/$(get_libdir)"
	newins - "${1}" <<-EOF
		/* GNU ld script */
		GROUP ( ${2} )
	EOF
}

davinci-resolve_src_install() {
	local inst=/opt/${DR_PN} app="${ED}/opt/${DR_PN}" ic="${ED}/opt/${DR_PN}/graphics" f d

	dodir "${inst}"
	cp -a squashfs-root/. "${app}/" || die

	# sane modes: dirs 0755, ELF + helper scripts executable
	find "${app}" -type d -exec chmod 0755 {} + || die
	while IFS= read -r -d '' f; do
		_is_elf "${f}" && chmod 0755 "${f}"
	done < <(find "${app}" -type f -print0)
	for f in bin/run_bmdpaneld libs/libc++.so scripts/script.{checkfirmware,getlogs.v4,halt,kill,reboot,start,update}; do
		[[ -e ${app}/${f} ]] && chmod 0755 "${app}/${f}"
	done

	# Resolve writes its licence, logs and caches below the install prefix:
	# make them group-writable for the 'video' group (add your user to it).
	for d in "Apple Immersive/Calibration" .crashreport .license .LUT configs \
		DolbyVision GPUCache logs; do
		keepdir "${inst}/${d}"
		fowners root:video "${inst}/${d}"
		fperms 0775 "${inst}/${d}"
	done
	cp "${app}/share/"{default-config.dat,log-conf.xml} "${app}/configs/" || die
	cp "${app}/share/default_cm_config.bin" "${app}/DolbyVision/" || die

	dosym "${inst}/bin/resolve" /usr/bin/davinci-resolve
	dosym "${inst}/scripts/script.getlogs.v4" /usr/bin/davinci-resolve-capture-logs
	dosym "${inst}/DaVinci Control Panels Setup/DaVinci Control Panels Setup" \
		/usr/bin/davinci-control-panels-setup
	dosym "${inst}/BlackmagicRAWPlayer/BlackmagicRAWPlayer" /usr/bin/blackmagicraw-player
	dosym "${inst}/BlackmagicRAWSpeedTest/BlackmagicRAWSpeedTest" /usr/bin/blackmagicraw-speedtest
	_newlib_ldscript libDaVinciPanelAPI.so "${inst}/panel-framework/libDaVinciPanelAPI.so"
	_newlib_ldscript libFairlightPanelAPI.so "${inst}/panel-framework/libFairlightPanelAPI.so"

	newmenu "${app}/share/DaVinciResolve.desktop" com.blackmagicdesign.resolve.desktop
	newmenu "${app}/share/DaVinciResolveCaptureLogs.desktop" com.blackmagicdesign.resolve-CaptureLogs.desktop
	newmenu "${app}/share/DaVinciControlPanelsSetup.desktop" com.blackmagicdesign.resolve-Panels.desktop
	newmenu "${app}/share/blackmagicraw-player.desktop" com.blackmagicdesign.rawplayer.desktop
	newmenu "${app}/share/blackmagicraw-speedtest.desktop" com.blackmagicdesign.rawspeedtest.desktop

	newicon -s 64 "${ic}/DV_Resolve.png" davinci-resolve.png
	newicon -s 64 "${ic}/DV_Panels.png" davinci-resolve-panels-setup.png
	local s
	for s in 48 256; do
		newicon -s ${s} "${ic}/blackmagicraw-player_${s}x${s}_apps.png" blackmagicraw-player.png
		newicon -s ${s} "${ic}/blackmagicraw-speedtest_${s}x${s}_apps.png" blackmagicraw-speedtest.png
		newicon -s ${s} -c mimetypes "${ic}/application-x-braw-clip_${s}x${s}_mimetypes.png" application-x-braw-clip.png
		newicon -s ${s} -c mimetypes "${ic}/application-x-braw-sidecar_${s}x${s}_mimetypes.png" application-x-braw-sidecar.png
	done
	newicon -s 64 -c mimetypes "${ic}/DV_ResolveBin.png" application-x-resolvebin.png
	newicon -s 64 -c mimetypes "${ic}/DV_ResolveProj.png" application-x-resolveproj.png
	newicon -s 64 -c mimetypes "${ic}/DV_ResolveTimeline.png" application-x-resolvetimeline.png
	newicon -s 64 -c mimetypes "${ic}/DV_ServerAccess.png" application-x-resolvedbkey.png
	newicon -s 64 -c mimetypes "${ic}/DV_TemplateBundle.png" application-x-resolvetemplatebundle.png

	insinto /usr/share/mime/packages
	doins "${app}/share/"{resolve,blackmagicraw}.xml

	udev_dorules "${app}/share/etc/udev/rules.d/"*.rules

	dosym "${inst}/docs/License.html" "/usr/share/licenses/${PN}/License.html"
}

davinci-resolve_postinst_msg() {
	elog "DaVinci Resolve needs a working GPU compute stack (CUDA/OpenCL)."
	elog "  NVIDIA: x11-drivers/nvidia-drivers (Blackwell/RTX 50xx needs the open"
	elog "          kernel modules, USE=kernel-open on a current nvidia-drivers);"
	elog "          check with 'clinfo' (dev-util/clinfo) before blaming Resolve."
	elog "Resolve stores its licence, logs and caches under /opt/${DR_PN}:"
	elog "add your user to the 'video' group (gpasswd -a USER video) and log in again."
	elog "Blackmagic panels/dongles get access through udev 'uaccess' (seat user)."
	elog "On hybrid-GPU laptops start it on the discrete GPU if the UI is slow:"
	elog "  __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia davinci-resolve"
	if [[ ${PN} == *-studio ]]; then
		elog "Studio: activate with your licence dongle, Blackmagic Cloud or activation code."
	fi
}


# pkg_postinst/pkg_postrm stay in the ebuilds (portage's udev QA check looks for
# udev_reload in their own text); call davinci-resolve_postinst_msg from pkg_postinst.
EXPORT_FUNCTIONS pkg_nofetch src_unpack src_prepare src_install

fi
