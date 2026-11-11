# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: ctg-ops.eclass
# @MAINTAINER:
# Ronald Farrer <canutethegreat@gmail.com>
# @BLURB: shared src_install for app-admin/ctg-ops (live and release ebuilds)
# @DESCRIPTION:
# Installs the ctg-ops payload (ctg-infrastructure packaging/ctg-ops) with the same file layout
# as the Debian packages of the same names, one USE flag per .deb. systemd units are shipped
# as-is; OpenRC scripts are generated from those same units (packaging/gentoo/ctg-ops/
# unit2openrc.py) so the two cannot drift. systemd .timer units become supervise-daemon
# services running ctg-timerd. Everything under /etc is plain CONFIG_PROTECT material.
#
# Expected tree (S): packaging/ctg-ops/files, packaging/gentoo/ctg-ops (tarball layout and git layout agree).

case ${EAPI} in 8) ;; *) die "${ECLASS}: EAPI ${EAPI:-0} unsupported" ;; esac

inherit systemd udev

EXPORT_FUNCTIONS src_install pkg_postinst

_CTGOPS_F=
_CTGOPS_OPSUNITS="rustinion-canary rustinion-web-oom-watch rustinion-platform-alert-watch rustinion-tenant-relay rustinion-tenant-relay-sweep ctg-sitehealth pg-backup-monitor pg-restore-drill pg-backup pg-backup-catchup lxdbr0-docker-forward"

# _ctgops_fix <mode> <src> <dest>: path-fixed install (same sed the .debs use)
_ctgops_fix() {
	install -D -m "${1}" /dev/null "${ED}${3}" || die
	sed -f "${_CTGOPS_F}/fixpaths.sed" "${2}" > "${ED}${3}" || die
}

# _ctgops_unit <srcdir> <name> [--no-openrc] : fix + install <name>.service/.timer for systemd and
# generate the OpenRC script (+ conf.d) from the same fixed units.
_ctgops_unit() {
	local dir=${1} name=${2} tmpd=${T}/units opts=() tmpl=
	mkdir -p "${tmpd}" || die
	sed -f "${_CTGOPS_F}/fixpaths.sed" "${dir}/${name}.service" > "${tmpd}/${name}.service" || die
	[[ -f ${dir}/${name}.timer ]] && { sed -f "${_CTGOPS_F}/fixpaths.sed" "${dir}/${name}.timer" > "${tmpd}/${name}.timer" || die; }
	systemd_dounit "${tmpd}/${name}.service"
	[[ -f ${tmpd}/${name}.timer ]] && systemd_dounit "${tmpd}/${name}.timer"
	local dropins=()
	if [[ -d ${dir}/${name}.service.d ]]; then
		insinto "/etc/systemd/system/${name}.service.d"
		doins "${dir}/${name}.service.d/"*.conf
		dropins=( --dropin "${dir}/${name}.service.d/"*.conf )
	fi
	[[ ${name} == *@ ]] && tmpl=--template
	local oname=${name%@}
	python3 "${_CTGOPS_G}/unit2openrc.py" --service "${tmpd}/${name}.service" \
		$([[ -f ${tmpd}/${name}.timer ]] && echo --timer "${tmpd}/${name}.timer") "${dropins[@]}" ${tmpl} \
		--name "${oname}" --out-initd "${T}/initd" --out-confd "${T}/confd" || die "openrc generation failed for ${name}"
	doinitd "${T}/initd/${oname}"
	doconfd "${T}/confd/${oname}"
}

ctg-ops_src_install() {
	_CTGOPS_F=${S}/packaging/ctg-ops/files
	_CTGOPS_G=${S}/packaging/gentoo/ctg-ops
	local OLL=${_CTGOPS_F}/ollivanders s u

	if use alert-mail; then
		_ctgops_fix 0755 "${_CTGOPS_F}/alert-mail/ctg-alert-mail" /usr/bin/ctg-alert-mail
	fi

	if use offhost-watch; then
		insinto /usr/lib/ctg-offhost
		doins "${_CTGOPS_F}/crystalcave/offhost/ctg_offhost.py" "${OLL}/bin/ctg_escalate.py"
		dobin "${_CTGOPS_F}/crystalcave/offhost/ctg-offhost"
	fi

	if use ollivanders-ops; then
		exeinto /usr/libexec/ctg-ops
		for s in rustinion-canary.py rustinion-web-oom-watch.py rustinion-platform-alert-watch.py rustinion-tenant-relay.py ctg-sitehealth.py; do
			_ctgops_fix 0755 "${OLL}/bin/${s}" "/usr/libexec/ctg-ops/${s}"
		done
		_ctgops_fix 0644 "${OLL}/bin/ctg_escalate.py" /usr/lib/ctg-ops/ctg_escalate.py
		for s in pg-backup-monitor.py pg-backup-run.py pg-restore-drill-run.sh cloudflared-docker-update.sh lxdbr0-docker-forward-allow.sh rustinion-tenant-relay-fw-allow.sh; do
			_ctgops_fix 0755 "${OLL}/sbin/${s}" "/usr/libexec/ctg-ops/${s}"
		done
		for u in ${_CTGOPS_OPSUNITS}; do _ctgops_unit "${OLL}/systemd" "${u}"; done
		keepdir /etc/ctg-alerts
		fowners root:ctg-alerts /etc/ctg-alerts
		fperms 0750 /etc/ctg-alerts
		insinto /etc/ctg-alerts
		doins "${OLL}/etc/route.conf"
		dosym ../libexec/ctg-ops/pg-backup-run.py /usr/sbin/ctg-pg-backup
		insinto /etc/cron.d
		newins "${OLL}/etc/cloudflared-docker-update" cloudflared-docker-update
		sed -i 's#/usr/local/sbin/cloudflared-docker-update.sh#/usr/libexec/ctg-ops/cloudflared-docker-update.sh#' \
			"${ED}/etc/cron.d/cloudflared-docker-update" || die
	fi

	if use deploy-watchers; then
		local watchers="big-double-d-deploy-watcher oops-deploy-watcher oops-labs-deploy-watcher php-site-deploy-watcher ssherpa-backend-deploy-watcher static-site-deploy-watcher deploy-web-watcher"
		for s in ${watchers}; do
			_ctgops_fix 0755 "${OLL}/bin/${s}.sh" "/usr/libexec/ctg-deploy/${s}.sh"
		done
		_ctgops_fix 0644 "${OLL}/lib/verify-artifact.sh" /usr/lib/ctg-deploy/verify-artifact.sh
		local wunits=$(cd "${OLL}/systemd" && ls *deploy-watcher*.service | sed 's/\.service$//')
		for u in ${wunits} rustinion-deploy-web-watcher; do
			[[ -f ${OLL}/systemd/${u}.service ]] || continue
			_ctgops_unit "${OLL}/systemd" "${u}"
		done
		insinto /etc/ctg-deploy
		doins "${OLL}/etc/allowed_signers" "${OLL}/etc/require-signature"
		insinto /etc/ctg-deploy/php-sites
		doins "${OLL}/php-sites/"*.env
		# one OpenRC instance per packaged site (symlink only: nothing is enabled by default,
		# the debs enable the timers, here `rc-update add` / `systemctl enable` is the admin's call)
		for s in "${OLL}/php-sites/"*.env; do
			s=${s##*/}; s=${s%.env}
			dosym php-site-deploy-watcher "/etc/init.d/php-site-deploy-watcher.${s}"
		done
	fi

	if use ollivanders-ssh; then
		insinto /etc/ssh/sshd_config.d
		doins "${OLL}/etc/50-ctg-hardening.conf"
		insinto /etc/fail2ban/jail.d
		doins "${OLL}/etc/zz-ctg-sshd.local"
	fi

	if use azkaban-host; then
		if [[ -e ${_CTGOPS_F}/azkaban/bulk-ensure ]]; then
			# ctg-ops >= 1.0.35: Time Machine + cloud-copy live on the bulk pool (tmpool-* units renamed bulk-*)
			for s in bulk-ensure bulk-recover bulk-health zpool-capacity-check; do
				_ctgops_fix 0755 "${_CTGOPS_F}/azkaban/${s}" "/usr/libexec/ctg-azkaban/${s}"
			done
			for u in hw-watchdog bulk-ensure bulk-recover bulk-health zfs-load-key-bulk zpool-capacity-check; do
				_ctgops_unit "${_CTGOPS_F}/azkaban" "${u}"
			done
			# same rules file the .deb ships (systemd starts the units; OpenRC gets the init scripts)
			cat > "${T}/99-bulk.rules" <<-EOF || die
			# Re-run bulk-ensure when the bulk Seagate (re)appears (USB reconnect), then clear the pool if the disconnect left it SUSPENDED
			ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd*[!0-9]", ENV{ID_SERIAL_SHORT}=="NA9W4KXB", TEST=="/run/systemd/system", RUN+="/usr/bin/systemctl --no-block start bulk-ensure.service bulk-recover.service"
			ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd*[!0-9]", ENV{ID_SERIAL_SHORT}=="NA9W4KXB", TEST!="/run/systemd/system", RUN+="/bin/sh -c 'rc-service bulk-ensure restart >/dev/null 2>&1 &'"
			EOF
			udev_dorules "${T}/99-bulk.rules"
		else
			for s in tmpool-ensure tmpool-health zpool-capacity-check; do
				_ctgops_fix 0755 "${_CTGOPS_F}/azkaban/${s}" "/usr/libexec/ctg-azkaban/${s}"
			done
			for u in hw-watchdog tmpool-ensure tmpool-health zfs-load-key-tmpool zpool-capacity-check; do
				_ctgops_unit "${_CTGOPS_F}/azkaban" "${u}"
			done
			# ONE rules file for both inits: systemd starts the unit, OpenRC starts the init script
			cat > "${T}/99-tmpool.rules" <<-EOF || die
			# Re-run tmpool-ensure when the Time Machine NVMe (re)appears (USB reconnect)
			ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd*[!0-9]", ENV{ID_SERIAL_SHORT}=="AME6N008111706O5D", TEST=="/run/systemd/system", RUN+="/usr/bin/systemctl --no-block start tmpool-ensure.service"
			ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd*[!0-9]", ENV{ID_SERIAL_SHORT}=="AME6N008111706O5D", TEST!="/run/systemd/system", RUN+="/bin/sh -c 'rc-service tmpool-ensure restart >/dev/null 2>&1 &'"
			EOF
			udev_dorules "${T}/99-tmpool.rules"
		fi
		insinto /etc/sysctl.d
		doins "${_CTGOPS_F}/azkaban/99-azkaban-zram.conf"
		insinto /etc/systemd/system.conf.d
		doins "${_CTGOPS_F}/azkaban/10-watchdog.conf"
	fi

	if use sudoers-crystalcave; then
		insinto /etc/sudoers.d
		insopts -m 0440
		doins "${_CTGOPS_F}/sudoers/ctg"
	fi

	if use forgejo-host; then
		_ctgops_fix 0755 "${_CTGOPS_F}/forgejo/ci-supersede-sweeper" /usr/libexec/ctg-forgejo/ci-supersede-sweeper
		_ctgops_fix 0755 "${_CTGOPS_F}/forgejo/ctg-forgejo-update" /usr/libexec/ctg-forgejo/ctg-forgejo-update
		_ctgops_unit "${_CTGOPS_F}/forgejo" ci-supersede-sweeper
		insinto /etc/cron.d
		newins - ctg-forgejo-update <<<'0 1 * * * root /usr/libexec/ctg-forgejo/ctg-forgejo-update'
	fi

	if use crystalcave-host; then
		# The .deb ships MODE="0666"; overlay policy is uaccess + a 0660 group instead.
		for s in 51-android.rules 52-android-accessory.rules; do
			sed 's/MODE="0666"/TAG+="uaccess", MODE="0660"/' "${_CTGOPS_F}/crystalcave/${s}" > "${T}/${s}" || die
			udev_dorules "${T}/${s}"
		done
		insinto /etc/modules-load.d
		doins "${_CTGOPS_F}/crystalcave/openshell-k3s.conf"
		insinto /etc/sysctl.d
		doins "${_CTGOPS_F}/crystalcave/99-openshell-k3s.conf"
		insinto /etc/systemd/system/ollama.service.d
		doins "${_CTGOPS_F}/crystalcave/ollama-override.conf"
	fi

	if use pg-restore-drill; then
		dosbin "${_CTGOPS_F}/containers/pg-restore-drill"
		dosym pg-restore-drill /usr/sbin/ctg-pg-restore-drill
	fi
	if use wordpress-ops; then
		dosbin "${_CTGOPS_F}/containers/ctg-update-wordpress"
		insinto /etc/cron.d
		doins "${_CTGOPS_F}/containers/ctg-wp-updates"
		newins - ctg-wordpress-update <<<$'# Core update with backup + rollback (was in the root crontab).\n0 5 * * * root /usr/sbin/ctg-update-wordpress >/dev/null'
	fi
	if use nextcloud-ops; then
		dosbin "${_CTGOPS_F}/containers/ctg-nextcloud-update"
		insinto /etc/cron.d
		newins - ctg-nextcloud-update <<<$'# Nextcloud updater + occ db repairs (was in the root crontab).\n30 4 * * * root /usr/sbin/ctg-nextcloud-update'
	fi
}

ctg-ops_pkg_postinst() {
	if use ollivanders-ops; then
		# HMAC key of the tenant finding relay: generated once, never packaged, never overwritten
		local k="${EROOT}/etc/ctg-alerts/tenant-relay.key"
		if [[ ! -s ${k} ]]; then
			( umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "${k}" ) || ewarn "could not create ${k}"
			chmod 0600 "${k}"
		fi
		chgrp ctg-alerts "${EROOT}/etc/ctg-alerts" 2>/dev/null; chmod 0750 "${EROOT}/etc/ctg-alerts"
	fi
	if use ollivanders-ssh && [[ -z ${ROOT} && -x /usr/sbin/sshd ]]; then
		mkdir -p /run/sshd
		/usr/sbin/sshd -t 2>/dev/null || ewarn "sshd -t fails with the new drop-in: sshd was NOT reloaded"
	fi
	use azkaban-host && udev_reload
	use crystalcave-host && udev_reload
	elog "Nothing is enabled by default (the .debs enable their timers). Enable with"
	elog "  systemctl enable --now <name>.timer      (systemd), or"
	elog "  rc-update add <name> default && rc-service <name> start   (OpenRC)"
	elog "OpenRC replaces .timer units with ctg-timerd under supervise-daemon (schedule in the init script, command in conf.d)."
	elog "Secrets (/etc/ctg-alerts/resend.key etc.) are never packaged: create them as root, 0600."
}
