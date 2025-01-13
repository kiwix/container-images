#!/bin/sh

function start_qbt {
	echo "Starting a qbittorrent-nox process (set NO_DAEMON if you dont want to)"

	QBT_HOST="${QBT_HOST:-localhost}"
	QBT_PORT="${QBT_PORT:-80}"
	QBT_USERNAME="${QBT_USERNAME:-admin}"
	QBT_TORRENTING_PORT="${QBT_TORRENTING_PORT:-6901}"

	QBT_MAX_CONNECTIONS="${QBT_MAX_CONNECTIONS:-500}"
	QBT_MAX_CONNECTIONS_PER_TORRENT="${QBT_MAX_CONNECTIONS_PER_TORRENT:-100}"
	QBT_MAX_UPLOADS="${QBT_MAX_UPLOADS:-20}"
	QBT_MAX_UPLOADS_PER_TORRENT="${QBT_MAX_UPLOADS_PER_TORRENT:-5}"

	if [ "x${QBT_PASSWORD}" = "x" ]; then
		QBT_PASSWORD=$(gen-password)
		echo "Generated web-ui password: ${QBT_PASSWORD}"
	fi
	PKBF2_PASSWORD=$(get-pbkdf2 "${QBT_PASSWORD}")

	QBITTORRENT_CONFIG_FILE=/root/.config/qBittorrent/qBittorrent.conf
	mkdir -p $(dirname $QBITTORRENT_CONFIG_FILE)
	cat <<EOF > $QBITTORRENT_CONFIG_FILE
[BitTorrent]
MergeTrackersEnabled=true
Session\DefaultSavePath=/data
Session\AddExtensionToIncompleteFiles=true
Session\MaxConnections=${QBT_MAX_CONNECTIONS}
Session\MaxConnectionsPerTorrent=${QBT_MAX_CONNECTIONS_PER_TORRENT}
Session\MaxUploads=${QBT_MAX_UPLOADS}
Session\MaxUploadsPerTorrent=${QBT_MAX_UPLOADS_PER_TORRENT}
Session\Port=${QBT_TORRENTING_PORT}
Session\Preallocation=true
Session\QueueingSystemEnabled=false
Session\SSL\Port=30154

[LegalNotice]
Accepted=true

[Meta]
MigrationVersion=8

[Preferences]
General\Locale=en
WebUI\Enabled=true
WebUI\Port=${QBT_PORT}
WebUI\Username=${QBT_USERNAME}
WebUI\Password_PBKDF2="@ByteArray(${PKBF2_PASSWORD})"
WebUI\LocalHostAuth=true
WebUI\HostHeaderValidation=false
WebUI\CSRFProtection=false

[Core]
AutoDeleteAddedTorrentFile=Always

[Application]
FileLogger\Age=5
FileLogger\AgeType=0
FileLogger\Backup=true
FileLogger\DeleteOld=true
FileLogger\Enabled=true
FileLogger\MaxSizeBytes=1048576
FileLogger\Path=/var/log
GUI\Notifications\TorrentAdded=false

EOF

	QBT_CONFIG_FILE=/root/.config/qbt/.qbt.toml
	mkdir -p $(dirname $QBT_CONFIG_FILE)
	cat <<EOF > $QBT_CONFIG_FILE
[qbittorrent]
addr       = "http://${QBT_HOST}:${QBT_PORT}" # qbittorrent webui-api hostname/ip
login      = "${QBT_USERNAME}"                  # qbittorrent webui-api user
password   = "${QBT_PASSWORD}"              # qbittorrent webui-api password
#basicUser = "user"                  # qbittorrent webui-api basic auth user
#basicPass = "password"              # qbittorrent webui-api basic auth password

[rules]
enabled              = true   # enable or disable rules
max_active_downloads = 2      # set max active downloads
EOF

	mkdir -p ~/.config/qbt && touch ~/.config/qbt/.qbt.toml


	# qbittorrent-nox --help
	qbittorrent-nox --save-path=/data --daemon
	rc=$?
	echo "rc=${rc}"
}

if [ "x${NO_DAEMON}" = "x" ]; then
	start_qbt
fi

exec "$@"
