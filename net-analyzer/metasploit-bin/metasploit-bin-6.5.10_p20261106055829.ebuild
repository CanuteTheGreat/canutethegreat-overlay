# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker

# PV 6.5.10_p20261106055829 = omnibus package 6.5.10~20261106055829~1rapid7-1
MY_PV="${PV%%_p*}"
MY_BUILD="${PV##*_p}"
MY_DEB="metasploit-framework_${MY_PV}~${MY_BUILD}~1rapid7-1_amd64.deb"

DESCRIPTION="Metasploit Framework penetration testing platform (Rapid7 omnibus binary build)"
HOMEPAGE="https://www.metasploit.com/ https://github.com/rapid7/metasploit-framework"
SRC_URI="https://apt.metasploit.com/pool/main/m/metasploit-framework/${MY_DEB} -> ${P}.deb"
S="${WORKDIR}"

# Framework: BSD-3. Bundled omnibus components (see LICENSES/ and
# version-manifest.json): Ruby (BSD-2), rubygems/bundler/libffi/libyaml/libxml2/
# libxslt/ncurses (MIT), OpenSSL, zlib, PostgreSQL, libedit (BSD), libuuid
# (LGPL-2.1), cacerts (MPL-2.0), liblzma (public domain), config.guess (GPL-3+).
LICENSE="BSD BSD-2 GPL-3+ LGPL-2.1 MIT MPL-2.0 openssl POSTGRESQL public-domain ZLIB"
SLOT="0"
KEYWORDS="~amd64"
# Prebuilt binaries with their own RPATH; the vendor package is not redistributed from our mirrors.
RESTRICT="mirror strip"

RDEPEND="sys-libs/glibc"
BDEPEND="app-arch/xz-utils"

QA_PREBUILT="opt/metasploit-framework/*"
QA_SONAME_NO_SYMLINK="opt/metasploit-framework/*"

MSF_HOME="/opt/metasploit-framework"

src_install() {
	# The vendor msfupdate self-updates through apt/gem: replaced by a stub.
	rm opt/metasploit-framework/bin/msfupdate || die

	dodir /opt
	cp -a opt/metasploit-framework "${ED}"/opt/ || die
	fowners -R root:root "${MSF_HOME}"

	local b
	for b in msfbinscan msfconsole msfd msfdb msfelfscan msfmachscan msfpescan \
		msfrop msfrpc msfrpcd msfvenom; do
		dosym "../..${MSF_HOME}/bin/${b}" "/usr/bin/${b}"
	done
	dobin "${FILESDIR}"/msfupdate
}

pkg_postinst() {
	elog "Run msfconsole to get started; 'msfdb init' sets up the bundled PostgreSQL"
	elog "database in ~/.msf4. Updates come through portage, not msfupdate."
}
