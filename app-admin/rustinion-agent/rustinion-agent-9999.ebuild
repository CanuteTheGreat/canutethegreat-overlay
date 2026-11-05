# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo git-r3 rustinion-agent

DESCRIPTION="Rustinion agent (device management and monitoring), built from source"
HOMEPAGE="https://rustinion.com"
# private repo: needs an ssh key on the building machine; crates come from the network (cargo_live_src_unpack)
EGIT_REPO_URI="ssh://git@git.canutethegreat.com/CanuteTheGreat/rustinion.git"
EGIT_BRANCH="main"
PROPERTIES="live"

LICENSE="all-rights-reserved"
RESTRICT="mirror test"
SLOT="0"
IUSE="+ra-host"
RUST_MIN_VER="1.85.0"

BDEPEND="dev-build/cmake"
RDEPEND="!app-admin/rustinion-bin"
QA_FLAGS_IGNORED="usr/bin/rustinion usr/libexec/rustinion/*"

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_compile() {
	cargo_src_compile -p rustinion
	use ra-host && cargo_src_compile -p rustinion-ra-host
}

src_install() {
	local t=$(cargo_target_dir)
	dobin "${t}/rustinion"
	if use ra-host; then
		exeinto /usr/libexec/rustinion
		doexe "${t}/rustinion-ra-host"
	fi
	_rustinion_install_common agent/packaging/linux/rustinion.service
}
