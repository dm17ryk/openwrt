#!/bin/sh

set -eu

src=${1:-package/network/utils/uqmi/files/lib/netifd/proto/qmi.sh}
uqmi_src=${2:-}

sync_line=$(grep -n -- '--sync' "$src" | head -n 1 | cut -d: -f1)
pin_line=$(grep -n -- '--get-pin-status' "$src" | head -n 1 | cut -d: -f1)
[ -n "$sync_line" ] && [ -n "$pin_line" ] && [ "$sync_line" -lt "$pin_line" ] || {
	echo "DWR-921 QMI CTL sync must precede the first PIN query" >&2
	exit 1
}

! grep -q -- '--set-data-format 802.3' "$src" || {
	echo "unsupported legacy uqmi data-format action remains" >&2
	exit 1
}

if [ -n "$uqmi_src" ]; then
	[ -f "$uqmi_src/uqmi/uqmi.h" ] && [ -f "$uqmi_src/uqmi/dev.c" ] || {
		echo "invalid uqmi source root: $uqmi_src" >&2
		exit 1
	}

	grep -q 'uint16_t message;' "$uqmi_src/uqmi/uqmi.h" || {
		echo "QMI requests must retain their message ID" >&2
		exit 1
	}
	grep -q 'req->message =' "$uqmi_src/uqmi/dev.c" || {
		echo "QMI request message ID is not recorded" >&2
		exit 1
	}
	grep -q 'req->message == le16_to_cpu(sync_msg.ctl.message)' "$uqmi_src/uqmi/dev.c" || {
		echo "CTL Sync indication handling does not preserve the Sync request" >&2
		exit 1
	}
	grep -q 'continue;' "$uqmi_src/uqmi/dev.c" || {
		echo "CTL Sync indication handling has no preserved-request branch" >&2
		exit 1
	}
fi

echo "dwr921 QMI ordering: PASS"
