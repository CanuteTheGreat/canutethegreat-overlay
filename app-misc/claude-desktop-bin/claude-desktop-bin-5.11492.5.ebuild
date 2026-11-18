# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

DESCRIPTION="Claude desktop app: Chat, Cowork and Claude Code (Linux beta, official binary build)"
HOMEPAGE="https://code.claude.com/docs/en/desktop-linux"
# Anthropic's signed apt repository (key 31DD DE24 DDFA B679 F42D 7BD2 BAA9 29FF 1A7E CACE);
# the pinned pool URLs are checked against the repository's Packages index SHA256.
APT_BASE="https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop"
SRC_URI="
	amd64? ( ${APT_BASE}/claude-desktop_${PV}_amd64.deb )
	arm64? ( ${APT_BASE}/claude-desktop_${PV}_arm64.deb )
"
S=${WORKDIR}

# Anthropic's own code is proprietary; the Electron/Chromium runtime it ships
# (LICENSES.chromium.html) adds the licenses below.
LICENSE="Anthropic-Claude-Desktop Apache-2.0 BSD BSD-2 Boost-1.0 CC-BY-3.0 CC-BY-4.0 FTL IJG ISC LGPL-2 LGPL-2.1 MIT MPL-1.1 MPL-2.0 Ms-PL SSLeay Unicode-3.0 Unicode-DFS-2015 ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
IUSE="+cowork"
RESTRICT="bindist mirror strip"

# Mirrors the .deb's Depends/Recommends. Cowork runs its tasks in a QEMU/KVM guest
# (qemu + UEFI firmware + virtiofsd; the app also bundles a virtiofsd it falls back to).
RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	app-crypt/libsecret
	app-misc/ca-certificates
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa[gbm(+)]
	media-video/pipewire
	net-misc/socat
	net-print/cups
	sys-apps/bubblewrap
	sys-apps/dbus
	sys-libs/libcap-ng
	sys-apps/xdg-desktop-portal
	sys-libs/glibc
	virtual/openssh
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3[X]
	x11-libs/libdrm
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libXtst
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libxshmfence
	x11-libs/pango
	x11-misc/xdg-utils
	|| (
		sys-apps/xdg-desktop-portal-gtk
		gnome-base/gnome-desktop-portal
		kde-plasma/xdg-desktop-portal-kde
	)
	cowork? (
		amd64? (
			app-emulation/qemu[qemu_softmmu_targets_x86_64]
			|| ( sys-firmware/edk2-bin sys-firmware/edk2-ovmf-bin )
		)
		arm64? (
			app-emulation/qemu[qemu_softmmu_targets_aarch64]
			sys-firmware/edk2-bin
		)
		app-emulation/virtiofsd
	)
"

QA_PREBUILT="opt/claude-desktop/*"
QA_DESKTOP_FILE="usr/share/applications/com.anthropic.Claude.desktop"

src_unpack() {
	unpack_deb ${A}
}

src_install() {
	local dest=/opt/claude-desktop

	# The vendor tree is relocatable (resources are found next to the executable).
	# Copy it with modes intact (doins would drop the exec bits). The .deb maintainer
	# scripts (apt repo registration, AppArmor profile, unattended-upgrades snippet,
	# apt keyring) are NOT run: Portage owns updates. The app has no self-updater on Linux.
	dodir "${dest%/*}"
	cp -a usr/lib/claude-desktop "${ED}${dest}" || die
	fperms 4711 "${dest}/chrome-sandbox"

	# Wrapper honours ${XDG_CONFIG_HOME:-~/.config}/claude-desktop-flags.conf
	exeinto /usr/bin
	doexe "${FILESDIR}/claude-desktop"

	domenu usr/share/applications/com.anthropic.Claude.desktop
	local size
	for size in 16 32 48 128 256; do
		newicon -s ${size} usr/share/icons/hicolor/${size}x${size}/apps/claude-desktop.png claude-desktop.png
	done

	# claude:// URL handler and .mcpb/.dxt/.skill file types (the .deb postinst copies these)
	insinto /usr/share/mime/packages
	doins usr/lib/claude-desktop/resources/linux-mime/com.anthropic.Claude.xml
	# GNOME Shell search provider; the vendor D-Bus unit points at /usr/lib, repoint to /opt
	insinto /usr/share/gnome-shell/search-providers
	doins usr/lib/claude-desktop/resources/gnome-search-provider/com.anthropic.Claude.search-provider.ini
	insinto /usr/share/dbus-1/services
	newins - com.anthropic.Claude.SearchProvider.service <<-EOF
		[D-BUS Service]
		Name=com.anthropic.Claude.SearchProvider
		Exec=/usr/bin/gjs -m ${dest}/resources/gnome-search-provider/searchProvider.js
	EOF

	dodoc usr/share/doc/claude-desktop/copyright
}

pkg_postinst() {
	xdg_pkg_postinst
	if use cowork; then
		elog "Cowork runs its tasks in a QEMU/KVM virtual machine. It needs:"
		elog "  - hardware virtualization enabled in firmware and /dev/kvm"
		elog "  - your user in the kvm group (needed for /dev/vhost-vsock too):"
		elog "      usermod -aG kvm <user>   then log out and back in"
		elog "  - the vhost_vsock module (modprobe vhost_vsock, or list it in /etc/modules-load.d/)"
		elog "The app checks these once at launch: restart it after changing them."
	fi
	elog "Extra command-line flags are read from"
	elog "  \${XDG_CONFIG_HOME:-~/.config}/claude-desktop-flags.conf"
	elog "(whitespace-separated, '#' comments). --ozone-platform-hint=auto is the default."
	elog "The setuid chrome-sandbox needs USER_NS/PID_NS/NET_NS/SECCOMP in the kernel."
	elog "The app does not update itself on Linux; updates come through Portage."
}

pkg_postrm() {
	xdg_pkg_postrm
}
