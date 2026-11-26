# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-info systemd

DESCRIPTION="ETPH router client: use a phone as this machine's internet uplink (USB or Wi-Fi), upstream static build"
HOMEPAGE="https://errant.solutions/etphonehome/ https://github.com/CanuteTheGreat/etphonehome"

# Upstream's router build (static musl, no BlueZ/libdbus), the same binary the OpenWrt package ships. Each release's SHA256SUMS is
# signed (keys/release-signing.asc in the repository, fingerprint in SECURITY.md); the Manifest below pins the artifacts.
# The packaging revision of the upstream .ipk is -r1 (bump ETPH_PKGREL with the Manifest when upstream re-spins a release).
ETPH_PKGREL=1
ETPH_RELEASES="https://git.canutethegreat.com/CanuteTheGreat/etphonehome/releases/download/v${PV}"
SRC_URI="
	amd64? ( ${ETPH_RELEASES}/etph_${PV}-r${ETPH_PKGREL}_x86_64.ipk )
	arm64? ( ${ETPH_RELEASES}/etph_${PV}-r${ETPH_PKGREL}_aarch64_generic.ipk )
"
S="${WORKDIR}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="strip mirror"
QA_PREBUILT="usr/sbin/etphonehome"

RDEPEND="sys-apps/iproute2"

CONFIG_CHECK="~TUN"
ERROR_TUN="CONFIG_TUN is required: the client's phone uplink is a TUN device (modprobe tun works when it is a module)."

src_unpack() {
	# an .ipk is a gzip'd tar of debian-binary, control.tar.gz and data.tar.gz
	local ipk=${A}
	mkdir -p "${WORKDIR}/ipk" || die
	tar -xzf "${DISTDIR}/${ipk}" -C "${WORKDIR}/ipk" --wildcards '*data.tar.gz' || die
	mkdir -p "${WORKDIR}/root" || die
	tar -xzf "${WORKDIR}/ipk/data.tar.gz" -C "${WORKDIR}/root" ./usr/sbin/etphonehome || die
}

src_install() {
	dosbin "${WORKDIR}/root/usr/sbin/etphonehome"

	exeinto /usr/libexec/etphonehome
	doexe "${FILESDIR}/etphonehome-run"

	# one settings file for both inits; the directory and file are private because they hold the adb key and can hold the pairing token
	diropts -m0700
	keepdir /etc/etph /etc/etph/.android
	insopts -m0600
	insinto /etc/etph
	doins "${FILESDIR}/etph.conf"

	newinitd "${FILESDIR}/etphonehome.initd" etphonehome
	newconfd "${FILESDIR}/etphonehome.confd" etphonehome
	systemd_dounit "${FILESDIR}/etphonehome.service"

	insopts -m0644
	insinto /etc/logrotate.d
	newins "${FILESDIR}/etphonehome.logrotate" etphonehome
}

pkg_postinst() {
	elog "ETPH router client installed. Settings: /etc/etph/etph.conf (all keys optional; default = USB phone)."
	elog "OpenRC:  rc-update add etphonehome default && rc-service etphonehome start"
	elog "systemd: systemctl enable --now etphonehome.service"
	elog "Status:  /run/etph/status.json (JSON: state, phone, bytes, last error)."
}
