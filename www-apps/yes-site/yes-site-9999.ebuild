# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 yes-site

DESCRIPTION="YES site: server-rendered embed catalog with scheduled importer"
HOMEPAGE="https://git.canutethegreat.com/CanuteTheGreat/yes"
LICENSE="all-rights-reserved"
RESTRICT="mirror test"   # tests need a PostgreSQL (run in the repo CI)
SLOT="0"
RUST_MIN_VER="1.85.0"
DEPEND="acct-user/yes-site acct-group/yes-site"
RDEPEND="
	acct-user/yes-site
	acct-group/yes-site
	dev-lang/python
	net-vpn/cloudflared
	app-admin/ctg-timerd
"
QA_FLAGS_IGNORED="usr/bin/yes-site"

PROPERTIES="live"
# private repo: needs an ssh key on the building machine; the crates come from the network (cargo_live_src_unpack)
EGIT_REPO_URI="ssh://git@git.canutethegreat.com/CanuteTheGreat/yes.git"
EGIT_BRANCH="main"

src_unpack() {
	git-r3_src_unpack
	# newer cargo.eclass runs `cargo fetch` in the current dir (WORKDIR), not S
	pushd "${S}" >/dev/null || die
	cargo_live_src_unpack
	popd >/dev/null || die
}
