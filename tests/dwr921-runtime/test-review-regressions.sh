#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
NETWORK_DEFAULTS="$ROOT/target/linux/ramips/mt7620/base-files/etc/board.d/02_network"
LED_INIT="$ROOT/package/network/utils/dwr921-internet-led/files/etc/init.d/dwr921-internet-led"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

grep -Fq "uci add_list firewall.@zone[1].network='lte'" "$NETWORK_DEFAULTS" || {
	echo "DWR-921 LTE interface is missing from the default WAN firewall zone" >&2
	exit 1
}

mkdir -p "$TMP/leds"
for led in green:internet green:wifi green:3g green:4g \
	green:sigstrength red:sigstrength; do
	mkdir -p "$TMP/leds/$led"
	printf 'timer\n' > "$TMP/leds/$led/trigger"
	printf '1\n' > "$TMP/leds/$led/brightness"
done

DWR921_LED_SYSFS_ROOT="$TMP/leds"
. "$LED_INIT"

clear_managed_leds
for led in green:internet green:wifi green:3g green:4g \
	green:sigstrength red:sigstrength; do
	[ "$(cat "$TMP/leds/$led/trigger")" = none ]
	[ "$(cat "$TMP/leds/$led/brightness")" = 0 ]
done

grep -Fq '[ "$enabled" = 1 ] || {' "$LED_INIT"
grep -A2 -F '[ "$enabled" = 1 ] || {' "$LED_INIT" |
	grep -Fq 'clear_managed_leds'

echo "dwr921 review regressions: PASS"
