#!/bin/bash
# Install (or update) net-watchdog as a root LaunchDaemon.
# Usage: sudo ./install.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "root 権限が必要です: sudo ./install.sh" >&2
    exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.net.watchdog"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"

# MAC の変更には root が必要なので、ユーザー権限の重複起動は取り除く
if [ -n "${SUDO_USER:-}" ]; then
    USER_PLIST="$(eval echo "~${SUDO_USER}")/Library/LaunchAgents/${LABEL}.plist"
    if [ -f "$USER_PLIST" ]; then
        launchctl bootout "gui/$(id -u "$SUDO_USER")/${LABEL}" 2>/dev/null || true
        rm -f "$USER_PLIST"
        echo "ユーザー版の LaunchAgent を削除しました"
    fi
fi

mkdir -p /usr/local/bin
install -m 755 -o root -g wheel "$DIR/net-watchdog.sh" /usr/local/bin/net-watchdog.sh
install -m 644 -o root -g wheel "$DIR/${LABEL}.plist" "$PLIST"

launchctl bootout "system/${LABEL}" 2>/dev/null || true
launchctl bootstrap system "$PLIST"

echo "インストールしました。ログ: /var/log/net-watchdog.log"
