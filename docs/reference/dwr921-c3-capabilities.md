# DWR-921 C3 (U-Boot) capability profile

This target uses the vendor U-Boot flash map and the legacy MT7620
`swconfig` driver. The normal production image contains the test tools below,
but none of the impairment or traffic-generation procedures is enabled by
default.

## Capability state

| Capability | State | Notes |
| --- | --- | --- |
| Firmware-region image support | SOURCE-IMPLEMENTED | U-Boot, environment and Factory remain outside the image. |
| Per-port PHY control | SOURCE-IMPLEMENTED | `dwr921-portctl` uses the bounded `swconfig` `enable` attribute. |
| Netem/IFB impairment | OFFLINE-BUILT | Requires an operator-created qdisc/filter. |
| SIP conntrack/NAT helper | OFFLINE-BUILT | `kmod-nf-nathelper-extra` is installed; helper assignment is not automatic. |
| DNS fault recipes | OFFLINE-BUILT | `dnsmasq-full` is installed; altered answers are not configured. |
| Conntrack inspection | OFFLINE-BUILT | `conntrack` and conntrack-netlink support are installed. |
| Throughput testing | OFFLINE-BUILT | `iperf3` and `socat` are installed; no server is enabled. |
| Wi-Fi diagnostics | OFFLINE-BUILT | Full OpenSSL WPA stack, `hostapd-utils`, `wpa-cli` and `iw` are installed. |
| DSA port naming | DEFERRED | This board remains on the validated `swconfig` topology. |

`OFFLINE-BUILT` here means that the package/toolchain integration and staged
root filesystem were built and inspected. It does not by itself mean that
the corresponding capability has completed hardware qualification.

## Physical-port control

The helper intentionally accepts only external labels:

```text
LAN1 → switch port 3
LAN2 → switch port 2
LAN3 → switch port 1
LAN4 → switch port 0
WAN  → switch port 4
```

Examples, all runtime-only:

```sh
dwr921-portctl port-status lan1
dwr921-portctl port-disable lan1
dwr921-portctl port-enable lan1
dwr921-portctl restore-all-ports
```

The driver changes only the selected PHY's BMCR. Disable sets `BMCR_PDOWN`;
enable clears it and sets autonegotiation enable/restart bits while preserving
the remaining BMCR bits. CPU port 6, unused port 5 and port 7 are rejected.

## Isolated impairment recipes

These examples are deliberately not installed as startup configuration. Run
them only against an isolated test interface and remove the state afterward.

```sh
# Delay and jitter on egress
tc qdisc replace dev eth0.2 root netem delay 40ms 10ms distribution normal
tc qdisc del dev eth0.2 root

# Loss, duplication and reordering
tc qdisc replace dev eth0.2 root netem loss 1% duplicate 0.1% reorder 5% 25%
tc qdisc del dev eth0.2 root

# Inbound impairment through IFB (adapt the physical device after inspection)
ip link add ifb-wan type ifb
ip link set ifb-wan up
tc qdisc replace dev eth0.2 ingress
tc filter replace dev eth0.2 ingress pref 10 matchall action mirred egress redirect dev ifb-wan
tc qdisc replace dev ifb-wan root netem delay 40ms
# Remove the filter/qdiscs and delete ifb-wan when the test ends:
tc qdisc del dev eth0.2 ingress
tc qdisc del dev ifb-wan root
ip link del ifb-wan
```

The IFB example redirects ingress packets into the IFB's egress path. Verify
the selected topology and counters with `tc -s` before relying on results.

## DNS and SIP fault tests

Use a temporary isolated `dnsmasq-full` instance or a temporary UCI override
to test wrong answers, empty replies, NXDOMAIN and SERVFAIL. Use netem for
response delay; `dnsmasq-full` does not by itself provide arbitrary delay.

For SIP, load the helper modules only for the isolated test and attach a
helper to the selected synthetic flow. Inspect `conntrack -L` and packet
captures, then remove the helper and unload only modules that are no longer in
use. Automatic conntrack-helper assignment remains disabled and no live SIP
traffic is altered by package installation.

## Qualification boundary

The source and package set are not a claim of hardware qualification. A later
RAM-only run must verify carrier loss/recovery on each socket, IFB cleanup,
SIP behavior, DNS fault semantics, WPA/monitor capabilities and resource use.
Persistent installation and CP8000 work require separate authorization.

The production image recipe uses the proven firmware-region pipeline without a
fixed kernel slot: `append-kernel | append-rootfs | pad-rootfs`. Therefore the
SquashFS boundary is derived from the actual legacy-uImage extent as
`64 + ih_size`, and may vary with the compressed kernel and package set. The
complete image remains bounded by the 0xfb0000-byte firmware partition. The
offline validator reads the uImage header, derives that boundary, checks the
SquashFS magic there, and validates the extracted filesystem. No assumption
that the rootfs begins at `0x1b0000` is made.
