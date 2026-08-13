#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
probe="$script_dir/../files/dwr921-at-probe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

mkdir -p "$tmp/bin"

cat >"$tmp/bin/picocom" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$DWR921_TEST_ARGS"
cat >"$DWR921_TEST_INPUT"
printf 'BroadMobi BM806C\r\nOK\r\n'
EOF
cat >"$tmp/bin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp/bin/picocom" "$tmp/bin/sleep"

export DWR921_TEST_ARGS="$tmp/args"
export DWR921_TEST_INPUT="$tmp/input"

PATH="$tmp/bin:$PATH" sh "$probe" /dev/null >"$tmp/output"

grep -q -- '--baud 115200' "$tmp/args"
grep -q -- '--flow n' "$tmp/args"
grep -q -- '--parity n' "$tmp/args"
grep -q -- '--databits 8' "$tmp/args"
grep -q -- '--stopbits 1' "$tmp/args"
grep -q -- '--exit-after 3000' "$tmp/args"
grep -q -- '--noreset' "$tmp/args"
grep -q -- '--quiet' "$tmp/args"
grep -q -- '/dev/null' "$tmp/args"

grep -q 'AT+CGMI' "$tmp/input"
grep -q 'AT+CFUN?' "$tmp/input"
grep -q 'AT+COPS?' "$tmp/input"
od -An -t u1 "$tmp/input" | grep -Eq '(^|[[:space:]])1[[:space:]]+24([[:space:]]|$)'
grep -q 'response=present' "$tmp/output"

grep -q '+picocom' "$script_dir/../Makefile"
! grep -Eq '\+coreutils-(stty|timeout)' "$script_dir/../Makefile"

echo "dwr921-at-probe tests passed"
