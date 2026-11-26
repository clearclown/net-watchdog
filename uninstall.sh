#!/bin/bash
# Remove net-watchdog.
# Usage: sudo ./uninstall.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "root 権限が必要です: sudo ./uninstall.sh" >&2
    exit 1
fi

LABEL="com.net.watchdog"

launchctl bootout "system/${LABEL}" 2>/dev/null || true
rm -f "/Library/LaunchDaemons/${LABEL}.plist" /usr/local/bin/net-watchdog.sh

echo "アンインストールしました（ログ /var/log/net-watchdog*.log は残しています）"
