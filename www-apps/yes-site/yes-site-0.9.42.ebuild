# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit yes-site

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

BASE="https://git.canutethegreat.com/api/packages/CanuteTheGreat/generic/yes-site/${PV}"
S="${WORKDIR}/yes-site-${PV}"
SRC_URI="
	${BASE}/yes-site-${PV}.tar.gz
	${BASE}/yes-site-${PV}-crates.tar.xz
"
KEYWORDS="~amd64 ~arm64"

src_unpack() {
	default
	# offline build: vendored crates (cargo vendor --locked, same Cargo.lock) behind the usual gentoo source replacement
	cargo_gen_config
	mkdir -p "${ECARGO_VENDOR}" || die
	cp -a "${WORKDIR}/vendor/." "${ECARGO_VENDOR}/" || die
}
