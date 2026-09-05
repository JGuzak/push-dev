#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${REPO_ROOT}/src"
OUT_DIR="${REPO_ROOT}/build"
PAYLOAD_DIR="${OUT_DIR}/payload"
PACKAGE_DIR="${OUT_DIR}/package"
DEFAULT_VERSION="local"
BUILD_WORK_DIR=""

usage() {
    cat <<'EOF'
Usage:
  build.sh [options]

Options:
  -v, --version <version>  Version used in the package tarball name.
                           Default: local
  -h, --help               Show this help.

Run from the push-dev root inside the devcontainer:
  ./scripts/build.sh -v local

Environment:
  KDIR                    Prepared full kernel source tree (container: /kernel).
  ARCH, CROSS_COMPILE     Kernel target and toolchain from the devcontainer.
  PUSH_DEV_KCFLAGS         Extra module flags (default: -fno-stack-protector).

Builds stock usbmon only. Does not install or load modules on Push.
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '%s\n' "$*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

cleanup_build_work_dir() {
    if [[ -n "${BUILD_WORK_DIR}" && -d "${BUILD_WORK_DIR}" ]]; then
        rm -rf "${BUILD_WORK_DIR}"
    fi
}

validate_build() {
    [[ "${VERSION}" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] ||
        die "version must contain only letters, digits, dots, underscores, or hyphens"
    [[ -n "${KDIR:-}" && -f "${KDIR}/drivers/usb/mon/Makefile" ]] ||
        die "usbmon requires the prepared full kernel source tree in KDIR"
    [[ -f "${KDIR}/include/config/kernel.release" ]] ||
        die "KDIR must be prepared with modules_prepare"
    grep -Eq '^CONFIG_USB_MON=(y|m)$' "${KDIR}/.config" ||
        die "the KDIR configuration must enable CONFIG_USB_MON"
}

format_sources() {
    local sources=()
    local source_file

    while IFS= read -r -d '' source_file; do
        sources+=("${source_file}")
    done < <(find "${SRC_DIR}" -type f \( -name '*.c' -o -name '*.h' \) -print0)
    if [[ ${#sources[@]} -gt 0 ]]; then
        info "Formatting project-owned kernel sources..."
        clang-format -i "${sources[@]}"
    fi
}

run_build() {
    local release
    local module

    mkdir -p "${OUT_DIR}"
    BUILD_WORK_DIR="$(mktemp -d "${OUT_DIR}/.module-build.XXXXXX")"
    format_sources
    info "Building stock usbmon from the prepared kernel tree..."
    make -C "${SRC_DIR}" USBMON_WORK_DIR="${BUILD_WORK_DIR}/usbmon"
    module="${BUILD_WORK_DIR}/usbmon/usbmon.ko"
    [[ -f "${module}" ]] || die "usbmon module was not produced"
    release="$(cat "${KDIR}/include/config/kernel.release")"
    [[ "$(modinfo -F vermagic "${module}")" == "${release} "* ]] ||
        die "usbmon vermagic does not match the prepared kernel release"

    mkdir -p "${BUILD_WORK_DIR}/payload"
    cp "${module}" "${BUILD_WORK_DIR}/payload/"
    info "Copying diagnostic lifecycle scripts..."
    cp "${REPO_ROOT}/scripts/payload/"*.sh "${BUILD_WORK_DIR}/payload/"
    chmod 755 "${BUILD_WORK_DIR}/payload/"*.sh
    modinfo "${module}" > "${BUILD_WORK_DIR}/payload/modinfo.txt"
    {
        printf 'kernel_release=%s\n' "${release}"
        printf 'kernel_commit=%s\n' "$(git -C "${KDIR}" rev-parse HEAD)"
        printf 'arch=%s\n' "${ARCH:-x86_64}"
        printf 'cross_compile=%s\n' "${CROSS_COMPILE:-}"
        printf 'kcflags=%s %s\n' "${KCFLAGS:-}" "${PUSH_DEV_KCFLAGS:--fno-stack-protector}"
        sha256sum "${KDIR}/.config" "${KDIR}/drivers/usb/mon/"*.c \
            "${KDIR}/drivers/usb/mon/"*.h "${KDIR}/drivers/usb/mon/Makefile"
    } > "${BUILD_WORK_DIR}/payload/kernel-provenance.txt"
    (
        cd "${BUILD_WORK_DIR}/payload"
        sha256sum usbmon.ko modinfo.txt kernel-provenance.txt *.sh > checksums.txt
    )

    # Publish only a complete build; preserve unrelated build output.
    rm -rf "${PAYLOAD_DIR}"
    mv "${BUILD_WORK_DIR}/payload" "${PAYLOAD_DIR}"
    mkdir -p "${PACKAGE_DIR}"
    tar -C "${PAYLOAD_DIR}" -czf "${PACKAGE_DIR}/push-dev-${VERSION}.tar.gz" .
    (
        cd "${PACKAGE_DIR}"
        sha256sum "push-dev-${VERSION}.tar.gz" > checksums.txt
    )
    info "Package: ${PACKAGE_DIR}/push-dev-${VERSION}.tar.gz"
    info "Experimental diagnostic module only; no automatic installation or loading."
}

VERSION="${DEFAULT_VERSION}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
            [[ $# -ge 2 ]] || die "$1 requires a version"
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
done

for command_name in cp find clang-format make mktemp rm mv modinfo git grep sha256sum tar chmod; do
    require_command "${command_name}"
done
validate_build
trap cleanup_build_work_dir EXIT
run_build
info "Done."
