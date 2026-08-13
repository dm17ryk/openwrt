#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/swconfig" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$DWR921_SWCONFIG_LOG"
case "$*" in
  *" get enable") printf 'enable: 1\n' ;;
esac
EOF
chmod +x "$TMP/swconfig"

export DWR921_PORTS_FILE="$ROOT/package/network/utils/dwr921-portctl/files/usr/share/dwr921-portctl/ports"

export DWR921_SWCONFIG_LOG="$TMP/commands"
PATH="$TMP:$PATH" "$ROOT/package/network/utils/dwr921-portctl/files/usr/sbin/dwr921-portctl" \
	port-disable lan1
for label in lan1 lan2 lan3 lan4 wan; do
	PATH="$TMP:$PATH" "$ROOT/package/network/utils/dwr921-portctl/files/usr/sbin/dwr921-portctl" \
		port-status "$label" >/dev/null
done
PATH="$TMP:$PATH" "$ROOT/package/network/utils/dwr921-portctl/files/usr/sbin/dwr921-portctl" \
	restore-all-ports

grep -qx 'dev switch0 port 3 set enable 0' "$DWR921_SWCONFIG_LOG"
for port in 0 1 2 3 4; do
	grep -qx "dev switch0 port $port get enable" "$DWR921_SWCONFIG_LOG"
done
for port in 0 1 2 3 4; do
	grep -qx "dev switch0 port $port set enable 1" "$DWR921_SWCONFIG_LOG"
done

for label in 0 5 6 7 lan0 lan5 lan6 wan0; do
	if PATH="$TMP:$PATH" "$ROOT/package/network/utils/dwr921-portctl/files/usr/sbin/dwr921-portctl" \
		port-disable "$label" >/dev/null 2>&1; then
		echo "invalid port unexpectedly accepted: $label" >&2
		exit 1
	fi
done

if PATH="$TMP:$PATH" "$ROOT/package/network/utils/dwr921-portctl/files/usr/sbin/dwr921-portctl" \
	port-disable >/dev/null 2>&1; then
	echo 'missing label unexpectedly accepted' >&2
	exit 1
fi
