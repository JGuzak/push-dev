FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Push kernel identity observed on-device.
ARG KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/rt/linux-stable-rt.git
ARG KERNEL_TAG=v5.15.48
ARG KERNEL_COMMIT=e1dd58c995daf8b632344b61df9d3cbed26454dc
ARG KERNEL_LOCALVERSION=-intel-pk-preempt-rt

ARG ARCH=x86_64
ARG TOOLCHAIN_PREFIX=x86_64-oe-linux-
ARG TOOLCHAIN_PREFIX_DIR=/opt/toolchain
ARG GCC_VERSION=11.5.0
ARG BINUTILS_VERSION=2.38
ARG BINUTILS_REPORTED_VERSION=2.38.20220708
ARG TARGET_GCC_VERSION="x86_64-oe-linux-gcc (GCC) 11.5.0"
ARG TARGET_LD_VERSION="GNU ld (GNU Binutils) 2.38.20220708"

ENV ARCH=${ARCH}
ENV CROSS_COMPILE=${TOOLCHAIN_PREFIX}
ENV PATH=${TOOLCHAIN_PREFIX_DIR}/bin:${PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    bison \
    build-essential \
    bzip2 \
    ca-certificates \
    clang \
    clang-format \
    cpio \
    dwarves \
    file \
    flex \
    git \
    kmod \
    libgmp-dev \
    libelf-dev \
    libisl-dev \
    libmpc-dev \
    libmpfr-dev \
    libssl-dev \
    make \
    openssl \
    patch \
    python3 \
    rsync \
    texinfo \
    wget \
    xz-utils \
    zlib1g-dev \
    vim \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /tmp/toolchain-src /tmp/toolchain-build "${TOOLCHAIN_PREFIX_DIR}"; \
    wget -O /tmp/toolchain-src/binutils.tar.xz "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz"; \
    tar -C /tmp/toolchain-src -xf /tmp/toolchain-src/binutils.tar.xz; \
    echo "binutils version metadata before patch:"; \
    grep -R -n -E "BFD_VERSION|${BINUTILS_VERSION}" \
        /tmp/toolchain-src/binutils-${BINUTILS_VERSION}/bfd/version* \
        /tmp/toolchain-src/binutils-${BINUTILS_VERSION}/bfd/configure \
        /tmp/toolchain-src/binutils-${BINUTILS_VERSION}/ld/configure \
        | head -80; \
    find /tmp/toolchain-src/binutils-${BINUTILS_VERSION} \
        \( -name "version.m4" -o -name "version.h" -o -name "configure" -o -name "bfdver.h" \) \
        -type f -exec sed -i "s/${BINUTILS_VERSION}/${BINUTILS_REPORTED_VERSION}/g" '{}' +; \
    echo "binutils version metadata after patch:"; \
    grep -R -n -E "BFD_VERSION|${BINUTILS_REPORTED_VERSION}" \
        /tmp/toolchain-src/binutils-${BINUTILS_VERSION}/bfd/version* \
        /tmp/toolchain-src/binutils-${BINUTILS_VERSION}/bfd/configure \
        /tmp/toolchain-src/binutils-${BINUTILS_VERSION}/ld/configure \
        | head -80; \
    mkdir -p /tmp/toolchain-build/binutils; \
    cd /tmp/toolchain-build/binutils; \
    /tmp/toolchain-src/binutils-${BINUTILS_VERSION}/configure \
        --prefix="${TOOLCHAIN_PREFIX_DIR}" \
        --target="${TOOLCHAIN_PREFIX%-}" \
        --with-pkgversion="GNU Binutils" \
        --disable-nls \
        --disable-werror; \
    make -j"$(nproc)"; \
    make install

RUN set -eux; \
    wget -O /tmp/toolchain-src/gcc.tar.xz "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"; \
    tar -C /tmp/toolchain-src -xf /tmp/toolchain-src/gcc.tar.xz; \
    mkdir -p /tmp/toolchain-build/gcc; \
    cd /tmp/toolchain-build/gcc; \
    /tmp/toolchain-src/gcc-${GCC_VERSION}/configure \
        --prefix="${TOOLCHAIN_PREFIX_DIR}" \
        --target="${TOOLCHAIN_PREFIX%-}" \
        --with-pkgversion="GCC" \
        --enable-languages=c \
        --without-headers \
        --disable-bootstrap \
        --disable-decimal-float \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx \
        --disable-multilib \
        --disable-nls \
        --disable-shared \
        --disable-threads; \
    make -j"$(nproc)" all-gcc; \
    make install-gcc; \
    rm -rf /tmp/toolchain-src /tmp/toolchain-build

RUN set -eux; \
    test "$(${TOOLCHAIN_PREFIX}gcc --version | head -1)" = "${TARGET_GCC_VERSION}"; \
    test "$(${TOOLCHAIN_PREFIX}ld --version | head -1)" = "${TARGET_LD_VERSION}"; \
    ${TOOLCHAIN_PREFIX}gcc --version | head -1; \
    ${TOOLCHAIN_PREFIX}ld --version | head -1

WORKDIR /kernel

RUN git clone --depth 1 --branch "${KERNEL_TAG}" "${KERNEL_REPO}" /kernel \
    && test "$(git rev-parse HEAD)" = "${KERNEL_COMMIT}"

# Minimal config for external module iteration. This is not claimed to be the
# exact Push kernel config, this is as goood as it gets for now, no /proc/config.gz, /boot/config-*,
# /lib/modules/.../build, source, or Module.symvers from AbletonOS 3.20 were found.

# DEBUG_INFO, DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT, DEBUG_INFO_BTF, and DEBUG_INFO_BTF_MODULES
# must remain enabled. Otherwise kernel modules will fail to load due to module
# format incompatibilities. Maybe investigate this in the future to avoid warning
# messages during build while also retaining the ability to actually load said modules.
RUN make x86_64_defconfig \
    && scripts/config \
        --set-str LOCALVERSION "${KERNEL_LOCALVERSION}" \
        --enable MODULES \
        --enable MODULE_UNLOAD \
        --enable SMP \
        --disable MODVERSIONS \
        --disable MODULE_SIG \
        --enable DEBUG_INFO \
        --enable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
        --enable DEBUG_INFO_BTF \
        --enable DEBUG_INFO_BTF_MODULES \
        --disable STACKPROTECTOR \
        --disable STACKPROTECTOR_STRONG \
        --disable STACKPROTECTOR_REGULAR \
        --enable SOUND \
        --module SND \
        --module SND_TIMER \
        --module SND_PCM \
    && make olddefconfig \
    && make modules_prepare \
    && test "$(make -s kernelrelease)" = "5.15.48${KERNEL_LOCALVERSION}"

WORKDIR /workspace

ENV KDIR=/kernel

COPY bin/build-kernel-modules.sh /usr/local/bin/build-kernel-modules
RUN chmod +x /usr/local/bin/build-kernel-modules

CMD ["sleep", "infinity"]
