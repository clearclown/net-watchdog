#!/bin/bash
# net-watchdog.sh - CGNAT drop auto-recovery for macOS
# Monitors internet connectivity; on failure, rotates the Wi-Fi MAC address
# and power-cycles Wi-Fi so the upstream network hands out a fresh session.
# Resource usage: ~0.1% CPU, negligible memory

LOG="${NET_WATCHDOG_LOG:-/var/log/net-watchdog.log}"
IFACE="${NET_WATCHDOG_IFACE:-en0}"
PING_TARGET="8.8.8.8"
PING_BACKUP="1.1.1.1"
CHECK_INTERVAL=20
FAIL_THRESHOLD=3
FAIL_COUNT=0
RECOVERY_COUNT=0

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG"
}

# Locally administered, unicast address: the first octet is fixed to 02.
# (A random first octet is a multicast address half of the time, which
# ifconfig rejects with "Can't assign requested address".)
generate_mac() {
    printf '02:%s\n' "$(openssl rand -hex 5 | sed 's/\(..\)/\1:/g; s/:$//')"
}

check_connectivity() {
    ping -c 1 -t 2 "$PING_TARGET" > /dev/null 2>&1 && return 0
    ping -c 1 -t 2 "$PING_BACKUP" > /dev/null 2>&1 && return 0
    return 1
}

recover() {
    local new_mac mac_note
    new_mac=$(generate_mac)
    RECOVERY_COUNT=$((RECOVERY_COUNT + 1))

    log "RECOVER #${RECOVERY_COUNT}: ${FAIL_COUNT}回連続失敗 - MAC=${new_mac}"

    if ifconfig "$IFACE" ether "$new_mac" 2>> "$LOG"; then
        mac_note="MAC=${new_mac}"
    else
        mac_note="MAC変更失敗"
        log "WARN: MAC を変更できませんでした（Wi-Fi の入れ直しのみ実施）"
    fi

    networksetup -setairportpower "$IFACE" off
    sleep 3
    networksetup -setairportpower "$IFACE" on
    sleep 15

    if check_connectivity; then
        local new_ip
        new_ip=$(ifconfig "$IFACE" | grep "inet " | awk '{print $2}')
        log "RECOVERED: 新IP=${new_ip} ${mac_note}"
    else
        log "RECOVER FAILED: 再試行待ち"
    fi
}

# Main loop
log "START: net-watchdog pid=$$ iface=${IFACE}"

while true; do
    if check_connectivity; then
        FAIL_COUNT=0
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        if [ $FAIL_COUNT -ge $FAIL_THRESHOLD ]; then
            recover
            FAIL_COUNT=0
        fi
    fi
    sleep "$CHECK_INTERVAL"
done
