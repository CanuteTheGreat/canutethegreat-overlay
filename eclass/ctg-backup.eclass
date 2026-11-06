# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: ctg-backup.eclass
# @MAINTAINER:
# Ronald Farrer <canutethegreat@gmail.com>
# @BLURB: shared src_install for app-admin/ctg-backup (live and release ebuilds)
# @DESCRIPTION:
# Installs the ctg-infrastructure backup kit (backups/ + packaging/ctg-infra/files) with the same
# file layout as the ctg-backup* .debs, one USE flag per .deb. systemd units are shipped as-is;
# OpenRC scripts are generated from the same units (packaging/gentoo/ctg-ops/unit2openrc.py, timers
# run under ctg-timerd) so the two init systems cannot drift. Credentials are never packaged.
#
# Expected tree (S): backups, packaging/ctg-infra/files, packaging/gentoo/ctg-ops/unit2openrc.py.

case ${EAPI} in 8) ;; *) die "${ECLASS}: EAPI ${EAPI:-0} unsupported" ;; esac

inherit systemd

EXPORT_FUNCTIONS src_install pkg_postinst

# _ctgb_unit <srcdir> <name> [outname]: install <name>.service/.timer for systemd (optionally
# renamed) and generate the OpenRC script + conf.d from the same units.
_ctgb_unit() {
	local dir=${1} name=${2} out=${3:-${2}} tmpl= tmpd=${T}/units
	mkdir -p "${tmpd}" || die
	cp "${dir}/${name}.service" "${tmpd}/${out}.service" || die
	[[ -f ${dir}/${name}.timer ]] && { cp "${dir}/${name}.timer" "${tmpd}/${out}.timer" || die; }
	if [[ -n ${_CTGB_UNIT_SED} ]]; then
		sed -i -e "${_CTGB_UNIT_SED}" "${tmpd}/${out}.service" || die
	fi
	systemd_dounit "${tmpd}/${out}.service"
	[[ -f ${tmpd}/${out}.timer ]] && systemd_dounit "${tmpd}/${out}.timer"
	[[ ${out} == *@ ]] && tmpl=--template
	local oname=${out%@}
	python3 "${S}/packaging/gentoo/ctg-ops/unit2openrc.py" --service "${tmpd}/${out}.service" \
		$([[ -f ${tmpd}/${out}.timer ]] && echo --timer "${tmpd}/${out}.timer") ${tmpl} \
		--name "${oname}" --out-initd "${T}/initd" --out-confd "${T}/confd" \
		|| die "openrc generation failed for ${name}"
	doinitd "${T}/initd/${oname}"
	doconfd "${T}/confd/${oname}"
}

ctg-backup_src_install() {
	local B=${S}/backups F=${S}/packaging/ctg-infra/files h f n e

	# --- ctg-backup (always)
	dosbin "${B}/ctg-restic"
	newsbin "${B}/router-config-pull.sh" ctg-router-config-pull
	newsbin "${B}/cf-export.py" ctg-cf-export
	for n in backup prune check; do _ctgb_unit "${B}/systemd" "ctg-restic-${n}"; done
	diropts -m 0700
	keepdir /etc/ctg-backup /var/lib/ctg-backup
	diropts -m 0755

	if use admin; then
		newsbin "${B}/workstations-prune.sh" ctg-workstations-prune
		_ctgb_unit "${B}/systemd" ctg-workstations-prune
	fi

	if use tm; then
		# units derived exactly as the .deb does (ctg-backup-tm)
		_CTGB_UNIT_SED='/^\[Service\]/a Environment=CTG_BACKUP_CONF=/etc/ctg-backup-tm\nEnvironment=CTG_BACKUP_STATE=/var/lib/ctg-backup-tm
s#^ConditionPathExists=.*#ConditionPathExists=/etc/ctg-backup-tm/env#'
		for n in backup prune check; do _ctgb_unit "${B}/systemd" "ctg-restic-${n}" "ctg-restic-tm-${n}"; done
		_CTGB_UNIT_SED=
		for n in backup prune check; do
			sed -i 's|ctg-restic|ctg-restic (Time Machine copy)|' "${ED}/usr/lib/systemd/system/ctg-restic-tm-${n}.timer" || die
		done
		sed -i 's/03:30/05:30/' "${ED}/usr/lib/systemd/system/ctg-restic-tm-backup.timer" || die
		# the OpenRC script was generated before the 03:30 -> 05:30 edit: regenerate from the final units
		rm -f "${ED}"/etc/init.d/ctg-restic-tm-{backup,prune,check} "${ED}"/etc/conf.d/ctg-restic-tm-{backup,prune,check} || die
		for n in backup prune check; do
			python3 "${S}/packaging/gentoo/ctg-ops/unit2openrc.py" \
				--service "${ED}/usr/lib/systemd/system/ctg-restic-tm-${n}.service" \
				--timer "${ED}/usr/lib/systemd/system/ctg-restic-tm-${n}.timer" \
				--name "ctg-restic-tm-${n}" --out-initd "${T}/initd" --out-confd "${T}/confd" || die
			doinitd "${T}/initd/ctg-restic-tm-${n}"
			doconfd "${T}/confd/ctg-restic-tm-${n}"
		done
		diropts -m 0700
		keepdir /etc/ctg-backup-tm /var/lib/ctg-backup-tm
		diropts -m 0755
		exeinto /etc/ctg-backup-tm
		newexe "${B}/hosts/azkaban/tm-pre.sh" pre.sh
		newexe "${B}/hosts/azkaban/tm-post.sh" post.sh
		insinto /etc/ctg-backup-tm
		newins "${B}/hosts/azkaban/tm-paths" paths
	fi

	# --- per-host configuration (paths/excludes/hooks), at most one
	for h in crystalcave ollivanders captainjack gringotts; do
		use "host-${h}" || continue
		for f in paths excludes; do
			[[ -f ${B}/hosts/${h}/${f} ]] && { insinto /etc/ctg-backup; doins "${B}/hosts/${h}/${f}"; }
		done
		for f in pre.sh post.sh; do
			[[ -f ${B}/hosts/${h}/${f} ]] && { exeinto /etc/ctg-backup; doexe "${B}/hosts/${h}/${f}"; }
		done
	done

	if use laptop; then
		# systemd only: ConditionACPower has no OpenRC equivalent (the OpenRC laptops are lab machines that run on AC)
		for n in backup prune check; do
			insinto "/usr/lib/systemd/system/ctg-restic-${n}.service.d"
			doins "${F}/laptop/ac-only.conf"
		done
	fi

	if use cloud-copy; then
		newsbin "${B}/cloud-copy/cloud-copy-backup" cloud-copy-backup
		newsbin "${B}/cloud-copy/cloud-copy-maint" cloud-copy-maint
		newsbin "${B}/cloud-copy/restore-test.sh" cloud-copy-restore-test
		for n in backup prune check; do _ctgb_unit "${B}/cloud-copy" "cloud-copy-${n}"; done
		diropts -m 0700
		keepdir /etc/cloud-copy /var/lib/ctg-backup-cloud /var/cache/cloud-copy
		diropts -m 0755
		insinto /etc/logrotate.d
		newins "${S}/packaging/ctg-infra/debian/ctg-cloud-copy.logrotate" ctg-cloud-copy
	fi

	if use pve; then
		dosbin "${F}/pve-backup/pve-config-backup" "${F}/pve-backup/pve-config-prune"
		insinto /etc/default
		newins "${F}/pve-backup/pve-backup.default" pve-backup
		for n in backup prune; do _ctgb_unit "${F}/pve-backup" "restic-${n}"; done
	fi

	if use guest; then
		dosbin "${F}/guest-backup/guest-restic-backup" "${F}/guest-backup/guest-restic-prune"
		insinto /etc/default
		newins "${F}/guest-backup/guest-backup.default" guest-backup
		for n in backup prune; do _ctgb_unit "${F}/guest-backup" "guest-restic-${n}"; done
	fi

	if use unit-failure-mail; then
		dobin "${F}/unit-failure-mail/unit-failure-mail"
		# systemd OnFailure= helper; template unit (OpenRC has no OnFailure, the generated script is the same helper for manual use)
		systemd_dounit "${F}/unit-failure-mail/unit-failure-mail@.service"
	fi

	if use agent-ssh; then
		insinto /etc/ssh/ssh_config.d
		doins "${F}/agent-ssh/50-agent-known-hosts.conf"
		dobin "${F}/agent-ssh/ctg-known-hosts-merge"
		_ctgb_unit "${F}/agent-ssh" "ctg-known-hosts-merge@"
	fi

	if use plex-guard; then
		dosbin "${F}/plex-guard/plex-playback-guard"
		_ctgb_unit "${F}/plex-guard" plex-playback-guard
	fi
}

ctg-backup_pkg_postinst() {
	chmod 0700 "${EROOT}/etc/ctg-backup" 2>/dev/null
	elog "Nothing is enabled by default and no credentials are packaged. Provision as root, 0600:"
	elog "  /etc/ctg-backup/env and /etc/ctg-backup/repo.pw (units do nothing until env exists)."
	elog "Enable: systemctl enable --now ctg-restic-backup.timer   (systemd), or"
	elog "        rc-update add ctg-restic-backup default && rc-service ctg-restic-backup start   (OpenRC, ctg-timerd)"
}
