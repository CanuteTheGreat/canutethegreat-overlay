# Copyright 2026 Errant Solutions
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: rustinion-agent.eclass
# @MAINTAINER:
# Ronald Farrer <canutethegreat@gmail.com>
# @BLURB: shared service/config install + postinst for app-admin/rustinion-agent
# @DESCRIPTION:
# Same layout as the rustinion-agent .deb: /usr/bin/rustinion, /usr/libexec/rustinion/rustinion-ra-host[-pw]
# (root-owned helper), /usr/lib/rustinion/package-managed (content "portage": the agent then never
# replaces its own binary, emerge is the update path), /etc/rustinion (0755; device.json = enrolment, kept
# across upgrades/removal), the systemd unit and an OpenRC script.

case ${EAPI} in 8) ;; *) die "${ECLASS}: EAPI ${EAPI:-0} unsupported" ;; esac

inherit systemd

EXPORT_FUNCTIONS pkg_preinst pkg_postinst

# _rustinion_install_common <unit file>
_rustinion_install_common() {
	systemd_dounit "${1}"
	newinitd "${FILESDIR}/rustinion.initd" rustinion
	newconfd "${FILESDIR}/rustinion.confd" rustinion
	insinto /usr/lib/rustinion
	newins - package-managed <<<"portage"
	diropts -m 0755
	keepdir /etc/rustinion
}

rustinion-agent_pkg_preinst() {
	# adopt a pre-package install exactly like the .deb's postinst: keep its daemon flags, move the old
	# unit/binary aside (never touch /etc/rustinion/device.json)
	[[ -z ${ROOT} ]] || return
	local old=/etc/systemd/system/rustinion.service
	if [[ -f ${old} ]] && grep -q '^ExecStart=.*rustinion daemon' "${old}"; then
		local keep=/var/lib/rustinion/pre-package-$(date +%Y%m%d%H%M%S) args
		mkdir -p "${keep}" || return
		args=$(sed -n 's|^ExecStart=[^ ]*rustinion daemon ||p' "${old}" | head -1)
		if [[ -n ${args} && ! -f /etc/rustinion/daemon.env ]]; then
			mkdir -p /etc/rustinion
			printf '# Adopted from the pre-package unit by the rustinion-agent package.\nRUSTINION_DAEMON_ARGS="%s"\n' "${args}" > /etc/rustinion/daemon.env
		fi
		mv "${old}" "${keep}/"
		[[ -d ${old}.d ]] && mv "${old}.d" "${keep}/"
		local f; for f in /usr/local/bin/rustinion /usr/local/bin/rustinion.new; do [[ -e ${f} ]] && mv "${f}" "${keep}/"; done
		elog "Adopted the existing install (old files kept in ${keep}); enrolment in /etc/rustinion is unchanged."
	fi
}

rustinion-agent_pkg_postinst() {
	if [[ ! -f ${EROOT}/etc/rustinion/device.json ]]; then
		elog "Not enrolled. Enrol with your tenant token:  rustinion enroll --token <token>"
	fi
	elog "Start the service (not started automatically on Gentoo):"
	elog "  systemd: systemctl enable --now rustinion"
	elog "  OpenRC : rc-update add rustinion default && rc-service rustinion start"
	elog "Updates: Portage owns /usr/bin/rustinion (package marker 'portage'); the agent only reports a new version, emerge -u installs it."
}
