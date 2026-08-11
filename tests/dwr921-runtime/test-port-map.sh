#!/bin/sh

set -eu

ports="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)/package/network/utils/dwr921-portctl/files/usr/share/dwr921-portctl/ports"

expected='lan1 3
lan2 2
lan3 1
lan4 0
wan 4'
actual=$(cat "$ports")
[ "$actual" = "$expected" ] || {
	echo "unexpected DWR-921 external port map:" >&2
	printf '%s\n' "$actual" >&2
	exit 1
}

echo "dwr921 port map: PASS"
