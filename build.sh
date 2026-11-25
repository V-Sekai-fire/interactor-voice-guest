#!/usr/bin/env bash
# Build voice.elf into project/.
#
#   RISCV64_SYSROOT=<repository-riscv64-sysroot> [GUEST_RUNTIME_ROOT=<contract-guest-runtime>] [PRECISION=single|double] ./build.sh
#
# Needs cmake, ninja, a clang++ with a riscv64 target (the sysroot's pixi environment has one), the
# repository-riscv64-sysroot checkout, and the contract-guest-runtime checkout, by default at
# ../../2-contract/guest-runtime as the goal manifest lays it out. No V extension: the Linux addon
# traps on vector code. PRECISION is single or double (default double): the addon refuses a guest
# whose Variant size differs from its own, so each engine precision needs its own ELF.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSROOT="${RISCV64_SYSROOT:?set RISCV64_SYSROOT to the riscv64 sysroot (toolchain.cmake inside)}"
PRECISION="${PRECISION:-double}"
case "$PRECISION" in
	single) DOUBLE=OFF ;;
	double) DOUBLE=ON ;;
	*) echo "error: PRECISION must be single or double, not $PRECISION" >&2; exit 1 ;;
esac
BUILD="${BUILD_DIR:-$HERE/build-$PRECISION}"

if [ ! -f "$SYSROOT/toolchain.cmake" ]; then
	echo "error: no toolchain.cmake under RISCV64_SYSROOT=$SYSROOT" >&2
	exit 1
fi
has_riscv() { "$1" --print-targets 2>/dev/null | grep -qi riscv64; }
if ! { command -v clang++ >/dev/null 2>&1 && has_riscv clang++; }; then
	echo "error: no clang++ with a riscv64 target on PATH" >&2
	exit 1
fi

if [ ! -f "$BUILD/build.ninja" ]; then
	cmake -S "$HERE" -B "$BUILD" -G Ninja \
		-DCMAKE_TOOLCHAIN_FILE="$SYSROOT/toolchain.cmake" \
		-DCMAKE_BUILD_TYPE=Release \
		${GUEST_RUNTIME_ROOT:+-DGUEST_RUNTIME_ROOT="$GUEST_RUNTIME_ROOT"} \
		-DSANDBOX_RISCV_EXT_V=OFF \
		-DDOUBLE_PRECISION="$DOUBLE"
fi
cmake --build "$BUILD" -- -j "${BUILD_JOBS:-8}"
ls -la "$HERE/project/voice.elf"
sha256sum "$HERE/project/voice.elf"
