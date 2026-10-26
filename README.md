# RISC-V toolchain Docker images

Package the existing GitHub release archives in Ubuntu 24.04 images. The
toolchain is extracted to `/opt/riscv`, and `/opt/riscv/bin` is on `PATH`.
No toolchain source build or second toolchain download is needed. Building
still needs network access for the Ubuntu base image and runtime packages.

Each image contains one archive:

| Variant | Use | Compiler |
| --- | --- | --- |
| `riscv32-elf` | 32-bit bare metal / Newlib | `riscv32-unknown-elf-gcc` |
| `riscv64-elf` | 64-bit bare metal / Newlib | `riscv64-unknown-elf-gcc` |
| `riscv32-glibc` | 32-bit Linux / glibc | `riscv32-unknown-linux-gnu-gcc` |
| `riscv64-glibc` | 64-bit Linux / glibc | `riscv64-unknown-linux-gnu-gcc` |

The archives contain **x86-64 Linux host executables**, even for the 32-bit
RISC-V targets. With Docker, build and run with `--platform linux/amd64`.
Apple Silicon requires amd64 emulation in the Docker engine (for example,
OrbStack).
These archives cannot produce a native arm64-hosted compiler image. Docker
documents the platform and emulation requirements in its
[multi-platform build guide](https://docs.docker.com/build/building/multi-platform/).

## Build

### Windows with WSL containers (wslc)

WSL 3.0 includes `wslc`, which builds and runs these Dockerfile images
without a separate Ubuntu distribution or Docker Desktop installation.
See Microsoft's [WSL container guide](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-containers).
Check the runtime from PowerShell:

```powershell
wslc version
wslc system info
```

On an x86-64 Windows host, build the default image with:

```powershell
./scripts/build.ps1 riscv64-elf
```

Build all four images:

```powershell
foreach ($variant in 'riscv32-elf', 'riscv64-elf', 'riscv32-glibc', 'riscv64-glibc') {
    ./scripts/build.ps1 $variant
}
```

The PowerShell script defaults to `wslc`. Use `-ContainerCli docker` for
Docker, or `-Release` and `-ImageTag` to override the release and tag.
The `RELEASE` and `IMAGE_TAG` environment variables are also supported.
`wslc` builds for the native x86-64 host; its build command does not accept
Docker's `--platform` flag. `.gitattributes` keeps the Linux shell scripts
and Dockerfile in LF format on Windows checkouts.

The direct equivalent is:

```powershell
wslc build --build-arg TOOLCHAIN=riscv64-elf --build-arg RELEASE=2026.08.27 -t riscv-toolchain:2026.08.27-riscv64-elf .
```

Run the compiler or repeat the smoke test:

```powershell
wslc run --rm riscv-toolchain:2026.08.27-riscv64-elf riscv64-unknown-elf-gcc --version
wslc run --rm riscv-toolchain:2026.08.27-riscv64-elf toolchain-smoke-test
```

### Docker / OrbStack

Run from this directory with Docker/OrbStack running:

```sh
./scripts/build.sh riscv64-elf
```

This creates `riscv-toolchain:2026.08.27-riscv64-elf`. Substitute any variant
from the table. With no argument, the script selects `riscv64-elf`.

Build all four images:

```sh
for variant in riscv32-elf riscv64-elf riscv32-glibc riscv64-glibc; do
  ./scripts/build.sh "$variant" || break
done
```

The equivalent direct command is:

```sh
docker build --platform linux/amd64 \
  --build-arg TOOLCHAIN=riscv64-elf \
  --build-arg RELEASE=2026.08.27 \
  -t riscv-toolchain:2026.08.27-riscv64-elf .
```

Archives must be at
`downloads/<release>/<variant>-ubuntu-24.04-gcc.tar.xz`.
To use another release or image tag:

```sh
RELEASE=2026.08.27 IMAGE_TAG=my-riscv-toolchain:latest ./scripts/build.sh riscv64-glibc
```

BuildKit mounts only the selected archive during extraction, keeping the
compressed tarball out of the image layers. The extracted toolchains alone
occupy approximately 2.5 GiB (`elf`), 3.1 GiB (`riscv32-glibc`), or 3.2 GiB
(`riscv64-glibc`), plus Ubuntu and runtime libraries.

Every build runs `toolchain-smoke-test`. It checks GCC, G++, GDB with Python,
both bundled QEMU programs, and C/C++ compilation and linking. It verifies
the output's RISC-V architecture and ELF bit width. The bare-metal checks
use a freestanding entry point and libgcc; Linux checks also use glibc and
libstdc++ and execute their programs with the bundled QEMU and sysroot.

## Use

Check the compiler:

```sh
docker run --rm --platform linux/amd64 \
  riscv-toolchain:2026.08.27-riscv64-elf riscv64-unknown-elf-gcc --version
```

Open a shell with the current project mounted at `/work`:

```sh
docker run --rm -it --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -v "$PWD:/work" \
  riscv-toolchain:2026.08.27-riscv64-elf
```

The image includes `make`; invoke your project's build with its target
compiler prefix, for example `make CROSS_COMPILE=riscv64-unknown-elf-`.
Bare-metal programs still need the startup code and linker script required
by their board or simulator.

For a compile-only check, `examples/smoke.c` provides a small integer
arithmetic program that works with all four toolchain variants. From this
directory, run:

```powershell
wslc run --rm -v "${PWD}:/work:ro" riscv-toolchain:2026.08.27-riscv64-elf riscv64-unknown-elf-gcc -std=c11 -Wall -Wextra -Werror -c /work/examples/smoke.c -o /tmp/smoke.o
```

Or with Docker / OrbStack:

```sh
docker run --rm --platform linux/amd64 \
  -v "$PWD:/work:ro" \
  riscv-toolchain:2026.08.27-riscv64-elf \
  riscv64-unknown-elf-gcc -std=c11 -Wall -Wextra -Werror \
  -c /work/examples/smoke.c -o /tmp/smoke.o
```

A successful exit confirms compilation. The object file is written inside
the temporary container. Substitute the matching image tag and compiler
from the variant table to check another target. `-c` skips linking, so this
check needs no board-specific startup code or linker script.

To repeat the built-in checks after building:

```sh
docker run --rm --platform linux/amd64 \
  riscv-toolchain:2026.08.27-riscv64-elf toolchain-smoke-test
```

## Verification status

On 2026-10-26, all four variants were rebuilt with `wslc 3.0.3.0` on
x86-64 Windows 11. Each passed the built-in smoke tests during its build
and again in a fresh `wslc` container. Both glibc variants executed their
C and C++ programs successfully in QEMU. The resulting images are
`linux/amd64`, with GCC/G++ 16.1.0 and QEMU 11.0.0.

On 2026-10-26, all four variants passed the built-in smoke tests during
`linux/amd64` Docker builds on OrbStack running on Apple Silicon. Checks
covered GCC/G++, GDB with Python, both bundled QEMU programs, C/C++ compilation
and linking, and the expected RISC-V ELF architecture and bit width. Both
glibc variants also successfully executed their C and C++ programs in QEMU.

The local image tags are:

- `riscv-toolchain:2026.08.27-riscv32-elf`
- `riscv-toolchain:2026.08.27-riscv64-elf`
- `riscv-toolchain:2026.08.27-riscv32-glibc`
- `riscv-toolchain:2026.08.27-riscv64-glibc`

## License

The Dockerfile, scripts, and documentation in this repository are licensed
under the [MIT License](LICENSE). The toolchains and Ubuntu packages included
in the images retain their respective upstream licenses.
