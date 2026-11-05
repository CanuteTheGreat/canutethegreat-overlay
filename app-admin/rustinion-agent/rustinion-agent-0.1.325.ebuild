# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="Rustinion agent and remote-desktop helper (device management, monitoring)"
HOMEPAGE="https://rustinion.com"
DL="https://rustinion.com/downloads"
# Version-pinned, never replaced after publication (scripts/ci/publish-artifacts.sh), so the Manifest stays valid.
SRC_URI="
	amd64? (
		${DL}/rustinion-linux-x86_64-${PV}
		remote-desktop? (
			${DL}/rustinion-ra-host-linux-x86_64-${PV}
			pipewire? ( ${DL}/rustinion-ra-host-pw-linux-x86_64-${PV} )
		)
	)
	arm64? (
		${DL}/rustinion-linux-arm64-${PV}
		remote-desktop? ( ${DL}/rustinion-ra-host-linux-arm64-${PV} )
	)
"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
# remote-desktop: the glibc helper that captures the screen/audio and injects input for a remote-desktop session
#   (started by the agent only when an admin enables the channel for the tenant; everything is OFF by default).
# pipewire: a second helper build linked against libpipewire (GNOME/KDE portal + Mutter capture on Wayland). amd64 only:
#   the arm64 helper has no PipeWire build yet. Without PipeWire the plain helper is used (wlroots + X11 only).
IUSE="+remote-desktop +pipewire"
REQUIRED_USE="pipewire? ( remote-desktop )"
RESTRICT="mirror bindist strip"

# The helper loads these with dlopen (a missing one only disables that media feature, the session still works):
# openh264 = Cisco's H.264 (built from Cisco's source; the helper looks for libopenh264.so.8 or .so.7),
# opus = audio codec, libpulse (pulse-simple) = system-audio capture/playback on PulseAudio and PipeWire-pulse,
# libva = Intel/AMD hardware H.264 encode.
RDEPEND="
	remote-desktop? (
		media-libs/openh264
		media-libs/opus
		media-libs/libpulse
		media-libs/libva
	)
	pipewire? ( media-video/pipewire )
"

QA_PREBUILT="usr/bin/rustinion usr/libexec/rustinion/*"

src_unpack() {
	# prebuilt binaries (the agent is signed by the Rustinion release key upstream; the Manifest pins every hash)
	:
}

src_install() {
	local arch
	use amd64 && arch=x86_64
	use arm64 && arch=arm64
	newbin "${DISTDIR}/rustinion-linux-${arch}-${PV}" rustinion

	newinitd "${FILESDIR}/rustinion.initd" rustinion
	systemd_dounit "${FILESDIR}/rustinion.service"

	if use remote-desktop; then
		# root-owned 0755 in a root-owned directory: the agent runs as root and refuses a helper anyone else can change
		exeinto /usr/libexec/rustinion
		newexe "${DISTDIR}/rustinion-ra-host-linux-${arch}-${PV}" rustinion-ra-host
		use pipewire && newexe "${DISTDIR}/rustinion-ra-host-pw-linux-${arch}-${PV}" rustinion-ra-host-pw
	fi

	# marker: the agent never replaces this binary itself (see pkg_managed.rs)
	insinto /usr/lib/rustinion
	newins - package-managed <<<"portage"

	keepdir /etc/rustinion
}

pkg_postinst() {
	if [[ -f "${EROOT}/etc/rustinion/device.json" ]]; then
		elog "This machine is already enrolled (/etc/rustinion/device.json is kept)."
		elog "Enable the service: rc-update add rustinion default && rc-service rustinion start"
	else
		elog "Enrol this machine with your tenant token, then start the service:"
		elog "  rustinion enroll --token <token>"
		elog "  rc-update add rustinion default && rc-service rustinion start   (systemd: systemctl enable --now rustinion)"
	fi
	elog "Portage owns /usr/bin/rustinion: update with emerge -u app-admin/rustinion-agent."
	if use remote-desktop; then
		elog "Remote desktop: the helper is installed in /usr/libexec/rustinion; sessions stay disabled"
		elog "until an administrator enables the channel for this device's tenant."
	fi
}
