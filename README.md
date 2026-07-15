# Samsung Galaxy A03 Core (SM-A032F) Custom Kernel Build

Working build process for the A03 Core (Unisoc/Spreadtrum SC9863A, Sharkl3),
kernel 4.14.199, defconfig `a3core_eur_open_defconfig`.

## Device Info

- **Model**: SM-A032F (Galaxy A03 Core)
- **SoC**: Unisoc/Spreadtrum SC9863A (Sharkl3 family), board codename `m168`
- **Stock kernel**: `4.14.199-27418755-abA032FXXS9CZA2`, built by `dpi@SWDMC201`
  with **clang-r383902** (Android clang 11.0.1)
- **Android version**: 14, security patch 2024-12-01
- **Bootloader**: unlocked (`verifiedbootstate=orange`), AVB v1.1
- **No `fastboot boot`** — Samsung's fastboot is stripped down to Download
  mode only. All testing must go through actual flash + Odin/Heimdall.

## Toolchain (matches stock kernel build)

```bash
export CROSS_COMPILE=<path>/android-kernel-tools/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
export CLANG_TOOL_PATH=<path>/toolchains/clang-r383902/bin
export PATH=${CLANG_TOOL_PATH}:${PATH//"${CLANG_TOOL_PATH}:"}
export BSP_BUILD_FAMILY=sharkl3
export BSP_BUILD_ANDROID_OS=y
export ARCH=arm64
```

Toolchains sourced from `github.com/pkm774/android-kernel-tools` (GCC Linaro
7.5.0 was used in an earlier session but does **not** match the stock
kernel's actual build signature — use GCC `aarch64-linux-android-4.9` +
clang-r383902 instead, confirmed via `/proc/version` on-device).

## Required KCFLAGS (clang-r383902 specific)

```bash
export KCFLAGS="-Wno-error=unused-variable -Wno-error=strict-prototypes"
```

**Important**: do NOT add `-Wno-error=align-mismatch` or
`-Wno-error=void-pointer-to-int-cast` — these warning categories don't
exist in clang-r383902 (they're r428724-era additions), and passing an
unrecognized `-Wno-error=X` flag becomes a hard error itself since the
build sets `-Werror=unknown-warning-option`. This cost significant time
in an earlier session where the wrong toolchain (r428724) was used and
its KCFLAGS were blindly carried over to r383902.

## Known Source Fixes (apply once per fresh extraction)

### 1. `scripts/dtc/Makefile` — wrong host-link variable name

Samsung's tree sets `HOSTLDLIBS_dtc`, but the kbuild `Makefile.host` in
this kernel version only reads `HOSTLOADLIBES_dtc`. Without this fix,
`scripts/dtc/dtc` fails to link with `undefined reference to
yaml_emitter_emit` and similar errors, because `-lyaml` never reaches the
actual link command.

```bash
sed -i 's/HOSTLDLIBS_dtc\s*:=\s*-lyaml/HOSTLOADLIBES_dtc := -lyaml/' scripts/dtc/Makefile
```

## Build Commands

```bash
cd <kernel-source-root>

make -C $(pwd) O=$(pwd)/out BSP_BUILD_DT_OVERLAY=y CC=clang LD=ld.lld \
  ARCH=arm64 CLANG_TRIPLE=aarch64-linux-gnu- a3core_eur_open_defconfig -j$(nproc)

make -C $(pwd) O=$(pwd)/out BSP_BUILD_DT_OVERLAY=y CC=clang LD=ld.lld \
  ARCH=arm64 CLANG_TRIPLE=aarch64-linux-gnu- -j$(nproc)
```

Output: `out/arch/arm64/boot/Image`

## Partition Layout (relevant)

| Partition | Device node | Notes |
|---|---|---|
| `boot` | `/dev/block/by-name/boot` (mmcblk0p40) | Main Android kernel+ramdisk, header v2, 64MB, has real AVB hash footer signed by Samsung |
| `recovery` | separate partition, also 64MB | **Confirmed independently bootable** via power+vol-up combo — proven safe to experiment on, does not affect daily Android |
| `dtbo` | mmcblk0p42 | Separate DT overlay partition — NOT combined into boot.img on this device |
| SD card | mmcblk1 (`mmcblk1p1` small vfat "primary", `mmcblk1p2` larger ext4 adopted storage) | External storage, unencrypted, good for dual-boot rootfs experiments |
| `userdata`/`/data` | dm-mapped (`dm-45` etc) | **Encrypted (FBE)** — raw mount from a bare initramfs will NOT see plaintext files |

## boot.img Structure (header v2)

```
BOARD_KERNEL_CMDLINE   console=ttyS1,115200n8
BOARD_KERNEL_BASE      0x00000000
BOARD_NAME             SRPUH09A009
BOARD_PAGE_SIZE        2048
BOARD_KERNEL_OFFSET    0x00008000
BOARD_RAMDISK_OFFSET   0x01000000
BOARD_TAGS_OFFSET      0x00000100
BOARD_HEADER_VERSION   2
BOARD_DTB_OFFSET       0x01f00000  (embedded dtb, separate from dtbo partition)
```

Repack with:
```bash
mkbootimg --kernel Image --ramdisk ramdisk.gz --dtb dtb \
  --cmdline "console=ttyS1,115200n8" --base 0x00000000 \
  --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
  --tags_offset 0x00000100 --pagesize 2048 \
  --os_version 11.0.0 --os_patch_level 2025-12 \
  --header_version 2 --board SRPUH09A009 -o new_boot.img
```

## Critical Safety Notes

1. **NEVER flash a custom kernel to `boot` without a full backup first**:
   ```bash
   adb shell dd if=/dev/block/by-name/boot of=/sdcard/current_boot.img
   adb pull /sdcard/current_boot.img
   ```
   Same for `recovery` and `vbmeta` before touching either.

2. **AVB footer status: unresolved for custom kernels on the `boot` slot.**
   A repacked `boot.img` without any AVB footer causes an early, silent
   bounce to Download mode (no kernel panic, nothing in pstore — the
   bootloader rejects it before the kernel gets control). Disabling AVB
   entirely via `vbmeta --flags 2` made things WORSE (stuck at first logo,
   recovery unreachable) — do not do this. Real fix would require either
   Samsung's actual signing key (not available) or a self-signed AVB
   footer test (untested, unclear if the "orange" bootloader state
   tolerates a mismatched-but-present footer the way it tolerates
   putting `recovery.img` in the `boot` slot).

3. **Given #2, the recommended safe path**: test all custom kernel builds
   via the `recovery` partition slot (power+vol-up to boot), never the
   `boot` slot. This was confirmed to independently boot a custom
   kernel+ramdisk without any AVB complaint, and doesn't risk daily
   Android use.

4. **No `fastboot boot`** — every test is a real flash. Use Heimdall or
   `adb shell dd` (with root) for flashing, always with a pre-verified
   backup in hand.

## Working NetHunter Setup (achieved via different path)

Wifi monitor mode / packet injection is already working via the official
Kali NetHunter app + chroot installer running on the **stock, unmodified
kernel**, combined with custom-built `.ko` wifi driver modules matching
the stock kernel's vermagic. This did NOT require any custom kernel
compilation — the custom-kernel work in this document is a separate,
additional project (dual-boot, HID/BadUSB, general feature work), not a
prerequisite for NetHunter functionality.
