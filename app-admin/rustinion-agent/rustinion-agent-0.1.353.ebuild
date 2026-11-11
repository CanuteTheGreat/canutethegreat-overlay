# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit rustinion-agent unpacker

DESCRIPTION="Rustinion agent (device management and monitoring)"
HOMEPAGE="https://rustinion.com"
REPO="https://rustinion.com/downloads/repo/apt/pool/main/r/rustinion-agent"
SRC_URI="
	amd64? ( ${REPO}/rustinion-agent_${PV}-1_amd64.deb )
	arm64? ( ${REPO}/rustinion-agent_${PV}-1_arm64.deb )
"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
RESTRICT="mirror bindist strip"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
IUSE="+ra-host"

# soft blocker: horcrux-overlay's old OpenRC-only -bin owns the same /usr/bin/rustinion
# (`emerge --deselect app-admin/rustinion-bin` first when it is in @selected)
RDEPEND="!app-admin/rustinion-bin"
QA_PREBUILT="usr/bin/rustinion usr/libexec/rustinion/*"

src_install() {
	dobin usr/bin/rustinion
	if use ra-host && [[ -d usr/libexec/rustinion ]]; then
		exeinto /usr/libexec/rustinion
		doexe usr/libexec/rustinion/*
	fi
	_rustinion_install_common usr/lib/systemd/system/rustinion.service
}
