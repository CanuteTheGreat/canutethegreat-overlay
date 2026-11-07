#!/sbin/openrc-run
# Plex Media Server (net-misc/plexmediaserver). Same environment as upstream's systemd unit; NO nice/ionice
# (::gentoo's script does `start-stop-daemon -N -5`, which fails with EACCES in an unprivileged LXD container and the server never starts).
description="Plex Media Server"
supervisor=supervise-daemon
command="${PLEX_SCRIPT:-/usr/libexec/plex-media-server-launch}"
command_user="${PLEX_USER:-plex}:${PLEX_GROUP:-plex}"
directory="${PLEX_HOME_DIR:-/var/lib/plexmediaserver}"
output_log="${PLEX_OUTLOG:-/var/log/pms/out.log}"
error_log="${PLEX_ERRLOG:-/var/log/pms/err.log}"
pidfile="/run/${RC_SVCNAME}.pid"
respawn_delay=5
respawn_max=10
respawn_period=60

depend() {
	need net
	use dns logger
	after ctg-media-mount localmount
}

start_pre() {
	checkpath -d -o "${command_user}" /var/log/pms
	export PLEX_MEDIA_SERVER_HOME=/usr/lib/plexmediaserver
	export PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="${PLEX_APPLICATION_SUPPORT_DIR:-${directory}/Library/Application Support}"
	export PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS="${PLEX_MAX_PLUGIN_PROCS:-6}"
	export PLEX_MEDIA_SERVER_INFO_VENDOR=Gentoo
	export PLEX_MEDIA_SERVER_INFO_MODEL="$(uname -m)"
	export PLEX_MEDIA_SERVER_INFO_PLATFORM_VERSION="$(readlink /etc/portage/make.profile 2>/dev/null | sed 's|.*/profiles/||')"
}

stop_post() {
	# Plex spawns helpers (Plug-in host, transcoder, tuner service) that outlive the supervised parent
	pkill -u "${command_user%%:*}" -f '^/usr/lib/plexmediaserver/' 2>/dev/null
	return 0
}
