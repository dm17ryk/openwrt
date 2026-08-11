#!/bin/sh

set -eu

usage() {
	echo "Usage: $0 <target-directory> <firmware-prefix>" >&2
	exit 2
}

[ "$#" -eq 2 ] || usage

TARGET_DIR=$1
PREFIX=$2
MANIFEST=$TARGET_DIR/$PREFIX.manifest

[ -d "$TARGET_DIR" ]
[ -s "$MANIFEST" ]

MKIMAGE=${MKIMAGE:-$PWD/staging_dir/host/bin/mkimage}
DUMPIMAGE=${DUMPIMAGE:-$(command -v dumpimage || true)}
FWTOOL=${FWTOOL:-$PWD/staging_dir/host/bin/fwtool}

command -v dd >/dev/null
command -v od >/dev/null
command -v stat >/dev/null
command -v unsquashfs >/dev/null
[ -x "$MKIMAGE" ]
[ -x "$DUMPIMAGE" ]
[ -x "$FWTOOL" ]

required_packages='
tc-full
kmod-netem
kmod-ifb
kmod-nf-nathelper-extra
kmod-nf-conntrack-netlink
conntrack
iperf3
socat
dnsmasq-full
wpad-openssl
hostapd-utils
wpa-cli
iw
dwr921-portctl'

for package in $required_packages; do
	grep -Eq "^$package -" "$MANIFEST"
done

dnsmasq_providers=$(awk '$1 == "dnsmasq" || $1 == "dnsmasq-full" { print $1 }' "$MANIFEST")
[ "$dnsmasq_providers" = dnsmasq-full ]

wpad_providers=$(awk '$1 ~ /^wpad(-|$)/ { print $1 }' "$MANIFEST")
[ "$wpad_providers" = wpad-openssl ]

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

for suffix in initramfs-kernel.bin squashfs-factory.bin squashfs-sysupgrade.bin; do
	image=$TARGET_DIR/$PREFIX-$suffix
	[ -s "$image" ]
	[ "$(stat -c '%s' "$image")" -le $((0xfb0000)) ]
	magic=$(od -An -tx1 -N4 "$image" | tr -d '[:space:]')
	[ "$magic" = 27051956 ]
	info=$($MKIMAGE -l "$image")
	echo "$info" | grep -Eq 'Image Type:.*MIPS Linux Kernel Image'
	echo "$info" | grep -Eq 'Compression:.*lzma|Image Type:.*lzma compressed'
	$DUMPIMAGE -T kernel -p 0 -o "$TMP_DIR/$suffix.payload" "$image" \
		>/dev/null

	data_size=$(printf '%s\n' "$info" | awk '/Data Size:/ { print $3; exit }')
	[ -n "$data_size" ]
	[ "$(stat -c '%s' "$TMP_DIR/$suffix.payload")" -eq "$data_size" ]
done

for suffix in squashfs-factory.bin squashfs-sysupgrade.bin; do
	image=$TARGET_DIR/$PREFIX-$suffix
	kernel_data_size=$($MKIMAGE -l "$image" \
		| awk '/Data Size:/ { print $3; exit }')
	rootfs_offset=$((64 + kernel_data_size))
	image_size=$(stat -c '%s' "$image")
	[ "$rootfs_offset" -lt "$image_size" ]
	rootfs_magic=$(dd if="$image" iflag=skip_bytes,count_bytes \
		skip="$rootfs_offset" count=4 2>/dev/null \
		| od -An -tx1 | tr -d '[:space:]')
	[ "$rootfs_magic" = 68737173 ]
done

metadata=$TMP_DIR/metadata
$FWTOOL -q -i "$metadata" "$TARGET_DIR/$PREFIX-squashfs-factory.bin"
grep -Fq 'dlink,dwr-921-c3-uboot' "$metadata"

rootfs_image=$TMP_DIR/rootfs.squashfs
kernel_data_size=$($MKIMAGE -l "$TARGET_DIR/$PREFIX-squashfs-sysupgrade.bin" \
	| awk '/Data Size:/ { print $3; exit }')
rootfs_offset=$((64 + kernel_data_size))
dd if="$TARGET_DIR/$PREFIX-squashfs-sysupgrade.bin" \
	iflag=skip_bytes skip="$rootfs_offset" of="$rootfs_image" 2>/dev/null
unsquashfs -s "$rootfs_image" >/dev/null
rootfs_list=$TMP_DIR/rootfs.list
unsquashfs -lls "$rootfs_image" > "$rootfs_list"

rootfs_has() {
	grep -Eq "squashfs-root/$1( -> |$)" "$rootfs_list"
}

for path in \
	usr/sbin/dwr921-portctl \
	sbin/tc \
	usr/sbin/conntrack \
	usr/bin/iperf3 \
	usr/bin/socat \
	usr/sbin/hostapd_cli \
	usr/sbin/wpa_cli \
	usr/sbin/iw; do
	rootfs_has "$path"
done

find_module() {
	grep -E "squashfs-root/lib/modules/[^[:space:]]*/$1\\.ko(\\.[^[:space:]]*)?( -> |$)" \
		"$rootfs_list" >/dev/null
}

find_module sch_netem
find_module ifb
find_module nf_conntrack_netlink
find_module nf_conntrack_sip
find_module nf_nat_sip

# Package installation must not create a diagnostic service or a changed
# default wireless mode. The socat package ships a disabled example only.
! rootfs_has etc/rc.d/S99socat
! rootfs_has etc/init.d/dwr921-portctl
unsquashfs -cat "$rootfs_image" etc/config/socat > "$TMP_DIR/socat.config"
grep -Eq "^[[:space:]]*option[[:space:]]+enable[[:space:]]+'0'" \
	"$TMP_DIR/socat.config"

rootfs_text_matches() {
	for base in etc/config etc/init.d; do
		while IFS= read -r entry; do
			path=${entry#*squashfs-root/}
			case "$path" in
				$base/*) ;;
				*) continue ;;
			esac
			case "$entry" in
				*" -> "*) continue ;;
			esac
			if unsquashfs -cat "$rootfs_image" "$path" 2>/dev/null \
				| grep -E "(^|[[:space:]])(tc[[:space:]]+qdisc|netem|ifb|ct[[:space:]]+helper|mode[[:space:]]+'monitor')" \
				>/dev/null 2>&1; then
				return 0
			fi
		done < "$rootfs_list"
	done
	return 1
}

! rootfs_text_matches

echo "dwr921-production: image, package, rootfs and inactive-default checks passed"
