export CROSS_COMPILE=~/phone_kernel/PLATFORM/android-kernel-tools/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
export CLANG_TOOL_PATH=~/toolchains/clang-r383902/bin
export PATH=${CLANG_TOOL_PATH}:${PATH//"${CLANG_TOOL_PATH}:"}
export BSP_BUILD_FAMILY=sharkl3
export DTC_OVERLAY_TEST_EXT=$(pwd)/tools/mkdtimg/ufdt_apply_overlay
export DTC_OVERLAY_VTS_EXT=$(pwd)/tools/mkdtimg/ufdt_verify_overlay_host
export BSP_BUILD_ANDROID_OS=y
export ARCH=arm64
export KCFLAGS="-Wno-error=unused-variable -Wno-error=strict-prototypes -Wno-error=logical-not-parentheses"
