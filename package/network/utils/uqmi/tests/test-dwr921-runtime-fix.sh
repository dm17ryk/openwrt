#!/bin/sh

set -eu

src=${1:-package/network/utils/uqmi/files/lib/netifd/proto/qmi.sh}
uqmi_src=${2:-}

sync_line=$(grep -n -- '--sync' "$src" | head -n 1 | cut -d: -f1)
pin_line=$(grep -n -- '--get-pin-status' "$src" | head -n 1 | cut -d: -f1)
release_line=$(grep -n 'dwr921_qmi_release_autoconnect$' "$src" | tail -n 1 | cut -d: -f1)
start_line=$(grep -n -- '--start-network' "$src" | head -n 1 | cut -d: -f1)
[ -n "$sync_line" ] && [ -n "$pin_line" ] && [ "$sync_line" -lt "$pin_line" ] || {
	echo "DWR-921 QMI CTL sync must precede the first PIN query" >&2
	exit 1
}

# The modem must not own the packet data session. Enabling modem autoconnect
# writes WDS 0x51 into NVRAM, the modem raises the PDN itself, the host's
# network-start request answers "No effect" and no host WDS client ever holds a
# packet data handle -- downlink is then zero. Stock disables autoconnect first
# and connects with its own WDS client, so releasing it has to happen before the
# first start request.
[ -n "$release_line" ] && [ -n "$start_line" ] && \
	[ "$release_line" -lt "$start_line" ] || {
	echo "DWR-921 must release modem autoconnect before the first WDS start request" >&2
	exit 1
}

grep -q 'dwr921_qmi_board && autoconnect=""' "$src" || {
	echo "DWR-921 must force modem autoconnect off so the host owns the bearer" >&2
	exit 1
}

grep -q -- '--set-autoconnect disabled' "$src" || {
	echo "DWR-921 setup must disable WDS autoconnect" >&2
	exit 1
}

grep -q "radio_interface\[0\]" "$src" || {
	echo "DWR-921 QMI radio interface must use uqmi's radio_interface array" >&2
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
	grep -A25 'cmd_wds_set_autoconnect_settings_prepare' \
		"$uqmi_src/uqmi/commands-wds.c" | grep -q 'return QMI_CMD_REQUEST' || {
		echo "WDS autoconnect action must transmit its prepared request" >&2
		exit 1
	}
fi

echo "dwr921 QMI ordering: PASS"
