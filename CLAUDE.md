# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A fork of the OpenWrt build system (`origin` = `dm17ryk/openwrt`, `upstream` = `openwrt/openwrt`).
Upstream code is untouched except for one focused body of work: a **D-Link DWR-921 C3 (U-Boot
variant)** port on `ramips/mt7620`, developed on the `dlink-dwr-921-c3-uboot` branch.
`git diff upstream/main...HEAD --stat` is the fastest way to see everything this fork adds.

Note: `AGENTS.md` and `RTK.md` in the repo root are gitignored local agent-tooling files, not
project documentation — they describe no part of this codebase.

## Build system essentials

OpenWrt is a make-based cross-compilation framework, not an application. Nothing here is
`npm`/`cargo`; everything goes through the top-level `Makefile`, `rules.mk` and `include/*.mk`.

```sh
./scripts/feeds update -a && ./scripts/feeds install -a   # required once; populates package/feeds/
make menuconfig            # interactive target/package selection -> .config
make defconfig             # expand a minimal .config into a full one
make download -j$(nproc)   # prefetch sources into dl/
make -j$(nproc)            # full build (toolchain + kernel + packages + images)
make -j1 V=s               # serial rebuild with full command echo — the way to diagnose failures
```

The current `.config` already selects `ramips/mt7620`, profile `dlink_dwr-921-c3-uboot`.

Targeted rebuilds (much faster than a full `make`):

```sh
make package/network/utils/dwr921-portctl/{clean,compile} V=s
make target/linux/{clean,compile} V=s          # kernel + in-tree ralink drivers
make target/linux/install V=s                  # regenerate images only
```

Build artifacts land in `bin/targets/ramips/mt7620/`; host tools used by tests are in
`staging_dir/host/bin/` (`mkimage`, `fwtool`, `unsquashfs4`). `build_dir/`, `staging_dir/`,
`dl/`, `bin/`, `feeds/`, `logs/` and `tmp/` are all generated — never commit them.

## Tests

There is no unified test runner. Tests are standalone POSIX `sh` scripts (plus one C unit test)
that run **offline against the source tree**, except the image validator, which needs a completed
build. Run them directly from the repo root:

```sh
sh tests/dwr921-portctl/test-portctl.sh              # port helper, with a stubbed swconfig
sh tests/dwr921-runtime/test-port-map.sh             # external label -> switch port map
sh tests/dwr921-runtime/test-review-regressions.sh   # firewall zone + LED lifecycle regressions
sh tests/dwr921-runtime/test-lte-defaults.sh         # uci-defaults seed vs. preserved user config
sh package/network/utils/dwr921-internet-led/tests/test-dwr921-led-state.sh
sh package/network/utils/dwr921-internet-led/tests/test-internet-led.sh
sh package/network/utils/dwr921-diag/tests/test-at-probe.sh
sh package/network/utils/uqmi/tests/test-dwr921-runtime-fix.sh

cc -std=c11 -Wall -Wextra -Werror tests/dwr921-portctl/test-bmcr.c -o /tmp/test-bmcr && /tmp/test-bmcr

# after a build: validates uImage header, derived SquashFS boundary, manifest, size bounds
tests/dwr921-production/test-image.sh bin/targets/ramips/mt7620 \
  openwrt-ramips-mt7620-dlink_dwr-921-c3-uboot

# after a build: needs the patched uqmi source tree, so it is not part of the offline set
sh package/network/utils/uqmi/tests/test-dwr921-ctl-trace.sh \
  build_dir/target-mipsel_24kc_musl/uqmi-*
```

Every script above, plus the device-side helpers under `package/network/utils/dwr921-*/files/`,
`package/network/utils/uqmi/files/` and the ramips `uci-defaults/`, is syntax-checked in CI with
`sh -n`, and the whole offline set is executed there. Keep new scripts POSIX `sh` — they run on
BusyBox on the device — and add new tests to the workflow's "Run offline source tests" step.

CI (`.github/workflows/build-dwr-921-c3-uboot.yml`) runs the offline tests, then a full firmware
build inside the OpenWrt buildbot container, then `test-image.sh`, then stages release files with
`sha256sums` and a `build-provenance.txt`. It is the reference for the exact expected build steps.

## Where the DWR-921 C3 work lives

The port spans four layers; a change to the device usually touches more than one.

- **Device/image definition** — `target/linux/ramips/image/mt7620.mk`: `Device/dlink_dwr-921-c3-uboot`
  (production) and `...-ramtest` (a stripped RAM-only variant for hardware bring-up). The image
  recipe is deliberately `append-kernel | append-rootfs | pad-rootfs` with **no fixed kernel slot**,
  so the rootfs offset is derived at validation time from `64 + ih_size` of the legacy uImage header
  rather than assumed. Do not reintroduce a hardcoded rootfs offset.
- **Board description** — `target/linux/ramips/dts/mt7620n_dlink_dwr-921-c3-uboot.dts` (vendor U-Boot
  flash map: U-Boot, environment and Factory partitions stay outside the firmware image) plus
  `target/linux/ramips/mt7620/base-files/etc/board.d/{01_leds,02_network}` and
  `.../etc/uci-defaults/`.
- **Kernel drivers** — patched *in place*, not via `patches/`, under
  `target/linux/ramips/files/drivers/net/ethernet/ralink/` (`mdio_mt7620.c`, `mt7530.c`,
  `gsw_mt7620.*`, `soc_mt7620.c`, and the fork-added `mt7620_bmcr.h`). This board stays on the
  legacy `swconfig` driver, **not** DSA — that is a deliberate, recorded decision.
- **Device packages** — `package/network/utils/`:
  - `dwr921-portctl` — per-port PHY enable/disable via the bounded `swconfig` `enable` attribute;
    accepts only external labels (`lan1..lan4`, `wan`), maps them through
    `files/usr/share/dwr921-portctl/ports`, and rejects CPU port 6 / ports 5 and 7.
  - `dwr921-internet-led` — status/cellular LED service driven by QMI state.
  - `dwr921-diag` — modem AT/QMI diagnostics (read-only QMI probe; depends on `picocom`).
  - `uqmi` — fork-local patches (`patches/10x-dwr921-*.patch`) and a modified
    `files/lib/netifd/proto/qmi.sh` for this modem's radio-state mapping.

`docs/reference/dwr921-c3-capabilities.md` is the authoritative capability record: what is
source-implemented, what is merely built-and-installed but not enabled, and what is deferred.
Update it when capability status changes, and keep its distinction between "built" and
"hardware-qualified" intact.

## Conventions

- **Commits**: OpenWrt style — `<subsystem>: <what changed>` (e.g. `ramips: add QMI support for
  DWR-921 C3 U-Boot`) is used for target/kernel/package changes; Conventional Commits
  (`fix(dwr921): ...`, `ci: ...`, `chore: ...`) appear for fork-infrastructure changes. Match the
  neighbouring history for the area you touch. Kernel/driver changes carry `Signed-off-by`.
  Do **not** add a `Co-Authored-By` trailer.
- Changes intended for upstream must follow upstream OpenWrt rules; `scripts/checkpatch.pl` is
  available for kernel-style patches.
- Device-side code runs on BusyBox with a ~16 MB firmware partition — no bashisms, no assuming
  GNU coreutils, and keep the package set lean (`IMAGE_SIZE := 16064k` is enforced by `check-size`).
- Local agent/session artifacts (`.claude-flow/`, `.agents/`, `.swarm/`, `.grit/`, `tasks/`,
  `docs/superpowers/`, `agentdb.rvf*`, `ruvector.db*`) are gitignored — keep them out of commits.
