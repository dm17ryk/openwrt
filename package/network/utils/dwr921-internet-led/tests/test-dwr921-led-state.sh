#!/bin/sh

set -eu

script="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/files/usr/sbin/dwr921-internet-led"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/sys/class/leds" "$tmpdir/sys/class/net/phy0-ap0"
for led in green:internet green:wifi green:3g green:4g green:sigstrength red:sigstrength; do
	mkdir -p "$tmpdir/sys/class/leds/$led"
	: > "$tmpdir/sys/class/leds/$led/brightness"
	: > "$tmpdir/sys/class/leds/$led/trigger"
done
printf 'up\n' > "$tmpdir/sys/class/net/phy0-ap0/operstate"
printf 'registration=registered\nradio=lte\nrssi=-70\n' > "$tmpdir/qmi-state"

mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/ip" <<'EOF'
#!/bin/sh
case "$*" in
  *"route get"*) echo "1.1.1.1 dev eth0.2 src 192.0.2.2" ;;
  *) exit 1 ;;
esac
EOF
cat > "$tmpdir/bin/ping" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 755 "$tmpdir/bin/ip" "$tmpdir/bin/ping"

DWR921_INTERNET_LED_TEST=1 \
DWR921_INTERNET_LED_ONCE=1 \
DWR921_LED_SYSFS_ROOT="$tmpdir/sys/class/leds" \
DWR921_QMI_STATE_FILE="$tmpdir/qmi-state" \
DWR921_WIFI_SYSFS="$tmpdir/sys/class/net" \
PATH="$tmpdir/bin:$PATH" "$script"

[ "$(cat "$tmpdir/sys/class/leds/green:internet/brightness")" = 1 ]
[ "$(cat "$tmpdir/sys/class/leds/green:wifi/brightness")" = 1 ]
[ "$(cat "$tmpdir/sys/class/leds/green:4g/brightness")" = 1 ]
[ "$(cat "$tmpdir/sys/class/leds/green:3g/brightness")" = 0 ]
[ "$(cat "$tmpdir/sys/class/leds/green:sigstrength/brightness")" = 1 ]
[ "$(cat "$tmpdir/sys/class/leds/red:sigstrength/brightness")" = 0 ]

printf 'down\n' > "$tmpdir/sys/class/net/phy0-ap0/operstate"
printf 'registration=registered\nradio=umts\nrssi=-95\n' > "$tmpdir/qmi-state"
DWR921_INTERNET_LED_TEST=1 \
DWR921_INTERNET_LED_ONCE=1 \
DWR921_LED_SYSFS_ROOT="$tmpdir/sys/class/leds" \
DWR921_QMI_STATE_FILE="$tmpdir/qmi-state" \
DWR921_WIFI_SYSFS="$tmpdir/sys/class/net" \
PATH="$tmpdir/bin:$PATH" "$script"

[ "$(cat "$tmpdir/sys/class/leds/green:wifi/brightness")" = 0 ]
[ "$(cat "$tmpdir/sys/class/leds/green:4g/brightness")" = 0 ]
[ "$(cat "$tmpdir/sys/class/leds/green:3g/brightness")" = 1 ]
[ "$(cat "$tmpdir/sys/class/leds/green:sigstrength/brightness")" = 0 ]
[ "$(cat "$tmpdir/sys/class/leds/red:sigstrength/brightness")" = 1 ]

echo "dwr921 LED state: PASS"
