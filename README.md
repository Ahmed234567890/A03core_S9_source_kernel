# Custom Kernel for Samsung Galaxy A03s (SM-A032F)

This kernel is built from the official Samsung open‑source release, with additional features enabled:

- Namespaces (IPC, PID, USER, NET, UTS, CGROUP)
- Control Groups (cgroups) with all controllers
- OverlayFS, SquashFS, FUSE
- Loop devices, TUN/TAP
- KVM (optional)
- And more...

## Build instructions

1. Install dependencies (on Arch Linux):
   ```bash
   sudo pacman -S git bc bison flex libssl-dev make gcc build-essential \
       libncurses-dev libelf-dev python3 python3-dev dtc clang lld aarch64-linux-gnu-binutils
Set up the cross‑compiler:

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CLANG_TRIPLE=aarch64-linux-gnu-
Configure the kernel:
make O=out a3core_eur_open_defconfig
# Or use the provided .config
Build:
make O=out -j$(nproc) Image
