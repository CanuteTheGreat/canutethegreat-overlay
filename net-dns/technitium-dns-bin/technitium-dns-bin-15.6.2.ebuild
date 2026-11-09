# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="Technitium DNS Server (authoritative + recursive, clustering, DHCP; upstream portable build)"
HOMEPAGE="https://technitium.com/dns/ https://github.com/TechnitiumSoftware/DnsServer"
SRC_URI="https://download.technitium.com/dns/archive/${PV}/DnsServerPortable.tar.gz -> DnsServerPortable-${PV}.tar.gz"
S="${WORKDIR}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="strip mirror"
QA_PREBUILT="opt/technitium/dns/*"

# the build targets net10.0 (Microsoft.NETCore.App + Microsoft.AspNetCore.App 10.0.x)
RDEPEND="
	acct-group/dns-server
	acct-user/dns-server
	dev-dotnet/dotnet-sdk-bin:10.0
	dev-libs/openssl
"

src_install() {
	insinto /opt/technitium/dns
	doins -r "${S}"/*
	fperms 0755 /opt/technitium/dns/start.sh

	newinitd "${FILESDIR}/technitium-dns.initd" technitium-dns
	systemd_newunit "${FILESDIR}/technitium-dns.service" technitium-dns.service
	newconfd "${FILESDIR}/technitium-dns.confd" technitium-dns

	# config + zones + stats live in /etc/dns (same path as the Debian install, so data copies verbatim)
	diropts -m0700 -o dns-server -g dns-server
	keepdir /etc/dns /var/log/technitium/dns
}

pkg_postinst() {
	elog "Config/data dir: /etc/dns (copy an existing node's dir to keep its zones, cluster identity and certs)."
	elog "Web console: http://<host>:5380/. Start with: rc-service technitium-dns start"
	elog "dns-bravo's resolv.conf must point at itself/peer only AFTER the service is up."
}
