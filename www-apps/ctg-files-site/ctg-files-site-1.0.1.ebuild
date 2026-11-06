# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="files.canutethegreat.com: Apache static listing vhost + goofys B2 mount services (replaces the Ubuntu ctg-files LXD guest)"
HOMEPAGE="https://git.canutethegreat.com/CanuteTheGreat/ctg-infrastructure"
SRC_URI="https://git.canutethegreat.com/api/packages/CanuteTheGreat/generic/ctg-files-site/${PV}/ctg-files-site-${PV}.tar.gz"
S="${WORKDIR}/ctg-files-site-${PV}"

LICENSE="all-rights-reserved"
RESTRICT="mirror"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RDEPEND="
	www-servers/apache[apache2_modules_alias,apache2_modules_autoindex,apache2_modules_dir,apache2_modules_mime,apache2_modules_authz_core,apache2_modules_log_config,apache2_modules_deflate,apache2_modules_filter]
	net-fs/goofys
"
BDEPEND="dev-lang/python"

# bucket -> mount instances; credentials (/root/.aws/credentials, profile = bucket name) are never packaged
CTG_FILES_BUCKETS="ctg-files ctg-hacktheplanet"

src_install() {
	local f=${S}/packaging/gentoo/ctg-files-site/files b

	insinto /etc/apache2/vhosts.d
	doins "${f}/00_ctg-files.conf"
	keepdir /var/www/html /var/log/apache2

	systemd_dounit "${f}/ctg-goofys@.service"
	python3 "${S}/packaging/gentoo/ctg-ops/unit2openrc.py" --service "${f}/ctg-goofys@.service" --template \
		--name ctg-goofys --out-initd "${T}/initd" --out-confd "${T}/confd" || die
	doinitd "${T}/initd/ctg-goofys"
	doconfd "${T}/confd/ctg-goofys"
	for b in ${CTG_FILES_BUCKETS}; do
		dosym ctg-goofys "/etc/init.d/ctg-goofys.${b}"
	done
}

pkg_postinst() {
	elog "No credentials are packaged. As root, 0600: /root/.aws/credentials with profiles ctg-files and ctg-hacktheplanet (B2 application keys)."
	elog "Then (OpenRC):  rc-update add ctg-goofys.ctg-files default; rc-update add ctg-goofys.ctg-hacktheplanet default; rc-update add apache2 default"
	elog "      (systemd): systemctl enable --now ctg-goofys@ctg-files ctg-goofys@ctg-hacktheplanet apache2"
	elog "Content (index.html, files, the sg-daily-email/hotlink-ok and badusb symlinks) is data: copy it into /var/www/html."
	elog "Gentoo's apache2 must not run its own default vhost on :80 for the same Host: this vhost file sorts first and is the default."
}
