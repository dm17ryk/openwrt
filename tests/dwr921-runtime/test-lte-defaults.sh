#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# uci-defaults/21_dwr921_c3_uboot_lte runs again on the first boot after every
# sysupgrade, including one that preserved /etc/config/network. It must seed the
# LTE defaults on a freshly generated section and keep its hands off a section
# the user has already customised.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
SCRIPT="$ROOT/target/linux/ramips/mt7620/base-files/etc/uci-defaults/21_dwr921_c3_uboot_lte"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/state"

cat > "$TMP/bin/board_name" <<'EOF'
#!/bin/sh
echo dlink,dwr-921-c3-uboot
EOF

# Minimal uci stand-in: one file per option, so state survives across the
# separate invocations the script makes. "batch" is supported too, so this
# test measures what the script does to the config rather than which uci
# spelling it happens to use.
cat > "$TMP/bin/uci" <<'EOF'
#!/bin/sh
state=${UCI_STATE:?}

unquote() {
	v=$1
	case "$v" in
	\'*\') v=${v#\'}; v=${v%\'} ;;
	esac
	printf '%s' "$v"
}

do_cmd() {
	while [ "${1:-}" = "-q" ]; do shift; done
	cmd=${1:-}
	shift || true
	case "$cmd" in
	get)
		[ -f "$state/$1" ] && { cat "$state/$1"; return 0; }
		for f in "$state/$1".*; do
			[ -e "$f" ] || continue
			echo interface
			return 0
		done
		return 1
		;;
	set)
		unquote "${1#*=}" > "$state/${1%%=*}"
		echo >> "$state/${1%%=*}"
		;;
	delete)
		rm -f "$state/$1"
		;;
	commit|"")
		;;
	*)
		echo "uci stub: unhandled command '$cmd'" >&2
		return 1
		;;
	esac
	return 0
}

case "${1:-}" in
-q) [ "${2:-}" = batch ] && set -- batch ;;
esac

if [ "${1:-}" = batch ]; then
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		# shellcheck disable=SC2086
		do_cmd $line || exit 1
	done
	exit 0
fi

do_cmd "$@"
EOF

chmod +x "$TMP/bin/board_name" "$TMP/bin/uci"
PATH="$TMP/bin:$PATH"
export PATH UCI_STATE

seed() {
	rm -rf "$TMP/state"
	mkdir -p "$TMP/state"
	# What config_generate leaves behind for a qmi interface.
	printf 'qmi\n' > "$TMP/state/network.lte.proto"
	printf 'ipv4\n' > "$TMP/state/network.lte.pdptype"
	printf '/dev/cdc-wdm0\n' > "$TMP/state/network.lte.device"
	printf '20\n' > "$TMP/state/network.lte.metric"
	while [ $# -gt 0 ]; do
		printf '%s\n' "${1#*=}" > "$TMP/state/network.lte.${1%%=*}"
		shift
	done
}

expect() {
	got=
	[ ! -f "$TMP/state/network.lte.$1" ] || got=$(cat "$TMP/state/network.lte.$1")
	[ "$got" = "$2" ] || {
		echo "$CASE: network.lte.$1 is '$got', expected '$2'" >&2
		exit 1
	}
}

UCI_STATE="$TMP/state"

# A freshly generated section gets the full set of defaults.
CASE="fresh flash"
seed
sh "$SCRIPT"
expect apn uinternet
expect auth none
expect autoconnect 0
expect mtu 1420
expect dhcp ""

# A stale dhcp on an otherwise untouched section is still cleared, so qmi.sh
# keeps spawning its own dynamic DHCP client.
CASE="fresh flash with stale dhcp"
seed dhcp=1
sh "$SCRIPT"
expect apn uinternet
expect dhcp ""

# A section the user has configured survives the upgrade untouched.
CASE="sysupgrade with customised lte"
seed apn=mycarrier auth=pap autoconnect=1 mtu=1500 dhcp=1
sh "$SCRIPT"
expect apn mycarrier
expect auth pap
expect autoconnect 1
expect mtu 1500
expect dhcp 1

# A partially configured section keeps what the user set and only gains the
# options that are genuinely absent.
CASE="sysupgrade with partially customised lte"
seed apn=mycarrier dhcp=1
sh "$SCRIPT"
expect apn mycarrier
expect auth none
expect autoconnect 0
expect mtu 1420
expect dhcp 1

# Boards other than the DWR-921 C3 must not be touched at all.
CASE="other board"
seed
cat > "$TMP/bin/board_name" <<'EOF'
#!/bin/sh
echo generic,other-board
EOF
chmod +x "$TMP/bin/board_name"
sh "$SCRIPT"
expect apn ""
expect mtu ""

echo "dwr921 LTE defaults: PASS"
