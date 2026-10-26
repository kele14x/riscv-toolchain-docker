#!/bin/sh
set -eu

case "${TOOLCHAIN:?TOOLCHAIN must identify the installed archive}" in
    riscv32-elf) target=riscv32-unknown-elf; bits=32; kind=elf ;;
    riscv64-elf) target=riscv64-unknown-elf; bits=64; kind=elf ;;
    riscv32-glibc) target=riscv32-unknown-linux-gnu; bits=32; kind=glibc ;;
    riscv64-glibc) target=riscv64-unknown-linux-gnu; bits=64; kind=glibc ;;
    *) echo "Unsupported toolchain: $TOOLCHAIN" >&2; exit 1 ;;
esac

test "$("$target-gcc" -dumpmachine)" = "$target"
"$target-gcc" --version
"$target-g++" --version
"$target-gdb" --batch --nx -ex 'python import sys; print(sys.version)'
qemu-riscv32 --version
qemu-riscv64 --version

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' 0
trap 'exit 1' HUP INT TERM

if [ "$kind" = glibc ]; then
    cat > "$test_dir/hello.c" <<'EOF'
#include <stdio.h>
int main(void) { return puts("RISC-V C OK") < 0; }
EOF
    cat > "$test_dir/hello.cpp" <<'EOF'
#include <iostream>
int main() { std::cout << "RISC-V C++ OK\n"; return !std::cout; }
EOF
    "$target-gcc" -Wall -Werror "$test_dir/hello.c" -o "$test_dir/hello-c"
    "$target-g++" -Wall -Werror "$test_dir/hello.cpp" -o "$test_dir/hello-cpp"
    sysroot=$("$target-gcc" -print-sysroot)
    test -d "$sysroot"
    "qemu-riscv$bits" -L "$sysroot" "$test_dir/hello-c"
    "qemu-riscv$bits" -L "$sysroot" "$test_dir/hello-cpp"
else
    # A bare-metal program supplies its own entry point and needs no OS syscalls.
    cat > "$test_dir/hello.c" <<'EOF'
#include <stdint.h>
volatile uint64_t numerator = 42, denominator = 3, result;
void _start(void) {
    result = numerator / denominator;
    for (;;) {}
}
EOF
    cat > "$test_dir/hello.cpp" <<'EOF'
#include <array>
#include <cstdint>
volatile std::uint32_t result;
extern "C" void _start() {
    constexpr std::array<std::uint32_t, 2> values = {20, 22};
    result = values[0] + values[1];
    for (;;) {}
}
EOF
    "$target-gcc" -O2 -Wall -Werror -ffreestanding -nostdlib -Wl,-e,_start \
        "$test_dir/hello.c" -lgcc -o "$test_dir/hello-c"
    "$target-g++" -O2 -Wall -Werror -ffreestanding -nostdlib -Wl,-e,_start \
        "$test_dir/hello.cpp" -lgcc -o "$test_dir/hello-cpp"
fi

for executable in "$test_dir/hello-c" "$test_dir/hello-cpp"; do
    "$target-readelf" -h "$executable" > "$test_dir/elf-header"
    grep -Eq "Class:[[:space:]]+ELF$bits" "$test_dir/elf-header"
    grep -Eq 'Machine:[[:space:]]+RISC-V' "$test_dir/elf-header"
done

echo "Toolchain smoke test passed: $target (ELF$bits C and C++)"
