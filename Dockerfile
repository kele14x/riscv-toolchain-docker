# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG TARGETARCH
ARG RELEASE=2026.08.27
ARG TOOLCHAIN=riscv64-elf

# The downloaded compilers run on x86-64 Linux, regardless of their RISC-V target.
RUN test "$TARGETARCH" = amd64 || \
    { echo "These archives require --platform linux/amd64" >&2; exit 1; }
RUN case "$TOOLCHAIN" in \
      riscv32-elf|riscv64-elf|riscv32-glibc|riscv64-glibc) ;; \
      *) echo "Unsupported toolchain: $TOOLCHAIN" >&2; exit 1 ;; \
    esac

# Includes the shared libraries used by GCC, GDB, and the bundled QEMU tools.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        libc6 \
        libexpat1 \
        libgcc-s1 \
        libglib2.0-0t64 \
        libgmp10 \
        libmpc3 \
        libmpfr6 \
        libncursesw6 \
        libpython3.12t64 \
        libstdc++6 \
        libtinfo6 \
        libzstd1 \
        make \
        python3 \
        xz-utils \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

# Mount only the selected archive; the compressed tarball is not an image layer.
# Every archive has a top-level riscv/ directory, yielding /opt/riscv/ here.
RUN --mount=type=bind,source=downloads/${RELEASE}/${TOOLCHAIN}-ubuntu-24.04-gcc.tar.xz,target=/tmp/toolchain.tar.xz \
    tar -xJf /tmp/toolchain.tar.xz -C /opt --no-same-owner

ENV RISCV=/opt/riscv
ENV PATH="/opt/riscv/bin:${PATH}"
ENV TOOLCHAIN=${TOOLCHAIN}

COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/toolchain-smoke-test
RUN toolchain-smoke-test

WORKDIR /work
CMD ["/bin/bash"]
