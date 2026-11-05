# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: yes-site.eclass
# @MAINTAINER:
# Ronald Farrer <canutethegreat@gmail.com>
# @BLURB: shared install/postinst for www-apps/yes-site (live and release ebuilds)
# @DESCRIPTION:
# Mirrors the yes-site .deb (Cargo.toml [package.metadata.deb] assets) file for file; adds OpenRC scripts.

case ${EAPI} in 8) ;; *) die "${ECLASS}: EAPI ${EAPI:-0} unsupported" ;; esac

inherit cargo systemd

EXPORT_FUNCTIONS src_install pkg_postinst pkg_postrm

yes-site_src_install() {
	cargo_src_install
	local d=packaging/gentoo

	insinto /usr/share/yes-site/assets
	doins assets/{style.css,app.js,live.js,altcha.js,webauthn.js,verify.js,og-default.png,favicon.svg}
	insinto /usr/share/yes-site
	newins data/states.json states.json
	insinto /usr/share/yes-site/ctg-backup
	doins debian-extra/backup/{paths,excludes}

	# /etc/yes-site: root:yes-site 0750 (the .deb's postinst), env file = conffile (CONFIG_PROTECTed)
	diropts -m 0750 -o root -g yes-site
	keepdir /etc/yes-site
	diropts -m 0755 -o root -g root
	insinto /etc/yes-site
	insopts -m 0644
	doins debian-extra/yes-site.env

	systemd_dounit debian-extra/yes-site.service debian-extra/yes-site.socket \
		debian-extra/yes-import.service debian-extra/yes-import.timer \
		debian-extra/yes-poll.service debian-extra/yes-cloudflared.service

	exeinto /usr/libexec/yes-site
	doexe ${d}/run-with-env
	local s
	for s in yes-site yes-poll yes-import yes-cloudflared; do doinitd ${d}/openrc/${s}; done
}

yes-site_pkg_postinst() {
	# ctg-backup (owner backup standard) integration, same as the .deb: link the packaged lists in when the tool is installed
	if [[ -d ${EROOT}/etc/ctg-backup ]]; then
		ln -sf /usr/share/yes-site/ctg-backup/paths "${EROOT}/etc/ctg-backup/paths"
		ln -sf /usr/share/yes-site/ctg-backup/excludes "${EROOT}/etc/ctg-backup/excludes"
	fi
	elog "Nothing is enabled or started by default (the .deb enables everything)."
	elog "  systemd: systemctl enable --now yes-site.socket yes-site.service yes-import.timer yes-poll.service yes-cloudflared.service"
	elog "  OpenRC : rc-update add yes-site default; rc-update add yes-import default; rc-update add yes-poll default; rc-update add yes-cloudflared default"
	elog "Secrets (never packaged): /etc/yes-site/secrets.env (root:yes-site 0640: YES_DB_URL=postgres://..., YES_MAIL_KEY, ...),"
	elog "and /etc/yes-site/tunnel.token for the Cloudflare tunnel (yes-cloudflared does not start without it)."
	elog "OpenRC has no socket activation: yes-site binds YES_LISTEN itself (no zero-downtime socket hand-over there)."
}

yes-site_pkg_postrm() {
	if [[ -z ${REPLACED_BY_VERSION} ]]; then
		rm -f "${EROOT}/etc/ctg-backup/paths" "${EROOT}/etc/ctg-backup/excludes" 2>/dev/null
	fi
}
