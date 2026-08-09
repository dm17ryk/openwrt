#!/bin/sh

set -eu

src=${1:?usage: $0 <patched-uqmi-source> [uqmi-binary]}
binary=${2:-}

rg -q 'DWR921-QMI-CTL:' "$src/uqmi/dev.c"
rg -q 'request-ret' "$src/uqmi/commands.c"
rg -q 'timeout-triggered' "$src/uqmi/uqmi.c"
rg -q 'DWR921_QMI_CTL_TRACE' \
	package/network/utils/uqmi/patches/100-dwr921-qmi-ctl-trace.patch
rg -q 'QMI_ERROR_CANCELLED' "$src/common/utils.c"
rg -q 'Request cancelled' "$src/common/utils.c"

if [ -n "$binary" ]; then
	strings "$binary" | rg -q 'DWR921-QMI-CTL:'
	! strings "$binary" | rg -q 'Received packet:|Send packet:'
fi

echo "dwr921-qmi-ctl-trace: PASS"
