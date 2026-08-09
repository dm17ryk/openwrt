#!/bin/sh

set -eu

script="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/files/usr/sbin/dwr921-internet-led"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/sys/class/leds/green:internet"

cat > "$tmpdir/bin/ping" <<'EOF'
#!/bin/sh
device=
while [ "$#" -gt 0 ]; do
    case "$1" in
        -I)
            device="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done
printf '%s\n' "$device" >> "$DWR921_TEST_PING_LOG"
[ "$device" = "$DWR921_TEST_SUCCESS" ]
EOF
chmod 755 "$tmpdir/bin/ping"

run_case() {
    name="$1"
    success="$2"
    expected="$3"

    : > "$tmpdir/sys/class/leds/green:internet/brightness"
    : > "$tmpdir/ping.log"
    DWR921_INTERNET_LED_TEST=1 \
    DWR921_INTERNET_LED_ONCE=1 \
    DWR921_INTERNET_LED_SYSFS="$tmpdir/sys/class/leds/green:internet" \
    DWR921_INTERNET_LED_INTERFACES="wwan0 eth0.2" \
    DWR921_INTERNET_LED_PROBE_HOST=192.0.2.1 \
    DWR921_TEST_SUCCESS="$success" \
    DWR921_TEST_PING_LOG="$tmpdir/ping.log" \
    PATH="$tmpdir/bin:$PATH" \
        "$script"

    actual="$(cat "$tmpdir/sys/class/leds/green:internet/brightness")"
    [ "$actual" = "$expected" ] || {
        echo "$name: expected brightness $expected, got $actual" >&2
        exit 1
    }
}

run_case "lte-reachability" "wwan0" 1
run_case "wired-wan-reachability" "eth0.2" 1
run_case "both-fail" "none" 0
run_case "absent-interface" "missing0" 0

echo "dwr921-internet-led tests: PASS"
