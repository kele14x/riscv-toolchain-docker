#!/bin/sh
set -eu

usage() {
    echo "Usage: $0 [riscv32-elf|riscv64-elf|riscv32-glibc|riscv64-glibc]"
    echo "Default: riscv64-elf; environment overrides: RELEASE, IMAGE_TAG"
}

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
fi

variant=${1:-riscv64-elf}
case "$variant" in
    -h|--help) usage; exit 0 ;;
    riscv32-elf|riscv64-elf|riscv32-glibc|riscv64-glibc) ;;
    *) usage >&2; exit 2 ;;
esac

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
release=${RELEASE:-2026.08.27}
image_tag=${IMAGE_TAG:-riscv-toolchain:${release}-${variant}}
archive="$project_dir/downloads/$release/$variant-ubuntu-24.04-gcc.tar.xz"

if [ ! -f "$archive" ]; then
    echo "Toolchain archive not found: $archive" >&2
    exit 1
fi

exec docker build \
    --platform linux/amd64 \
    --build-arg "RELEASE=$release" \
    --build-arg "TOOLCHAIN=$variant" \
    --tag "$image_tag" \
    "$project_dir"
