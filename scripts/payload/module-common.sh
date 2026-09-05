#!/usr/bin/env bash
# Shared lifecycle checks for the diagnostic payload; sourced by both commands.

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '%s\n' "$*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_root() {
    [[ "$(id -u)" == 0 ]] || die "must run as root on the target device"
}

select_modules() {
    local path="$1"
    local module name existing

    [[ -d "${path}" ]] || die "package directory does not exist: ${path}"
    PACKAGE_PATH="$(cd -- "${path}" && pwd -P)"
    SELECTED_MODULES=()
    SELECTED_NAMES=()
    shopt -s nullglob
    for module in "${PACKAGE_PATH}/"*.ko; do
        [[ -f "${module}" && ! -L "${module}" ]] || die "not a regular module file: ${module}"
        name="$(modinfo -F name "${module}")" || die "cannot identify module: ${module}"
        name="${name//-/_}"
        [[ "${name}" =~ ^[a-zA-Z0-9_]+$ ]] || die "invalid module name: ${name}"
        for existing in "${SELECTED_NAMES[@]}"; do
            [[ "${name}" != "${existing}" ]] || die "duplicate module name in package: ${name}"
        done
        SELECTED_MODULES+=("${module}")
        SELECTED_NAMES+=("${name}")
    done
    shopt -u nullglob
    [[ ${#SELECTED_MODULES[@]} -gt 0 ]] || die "no *.ko files found in ${PACKAGE_PATH}"
}

verify_package() {
    local module expected

    [[ -f "${PACKAGE_PATH}/checksums.txt" ]] || die "package checksums.txt is missing"
    (cd "${PACKAGE_PATH}" && sha256sum -c checksums.txt) || die "package checksum validation failed"
    # Also require coverage: an extra .ko must not bypass the package manifest.
    for module in "${SELECTED_MODULES[@]}"; do
        expected="$(cd "${PACKAGE_PATH}" && sha256sum "${module##*/}")"
        grep -Fxq -- "${expected}" "${PACKAGE_PATH}/checksums.txt" ||
            die "module missing from checksum manifest: ${module##*/}"
    done
}

module_sys_path() {
    printf '/sys/module/%s\n' "$1"
}

module_is_loaded() {
    [[ -d "$(module_sys_path "$1")" ]]
}

print_module_status() {
    local name path refs holder

    info "Selected module status:"
    for name in "${SELECTED_NAMES[@]}"; do
        path="$(module_sys_path "${name}")"
        if ! module_is_loaded "${name}"; then
            info "  ${name}: not loaded"
            continue
        fi
        refs=unknown
        if [[ -r "${path}/refcnt" ]]; then
            read -r refs < "${path}/refcnt" || refs=unknown
        fi
        info "  ${name}: loaded, use count=${refs}"
        for holder in "${path}/holders/"*; do
            [[ -e "${holder}" ]] || continue
            info "    dependent module: ${holder##*/}"
        done
    done
}

check_usbmon_clean() {
    local path
    local clean=0

    for path in /sys/class/usbmon /sys/devices/virtual/usbmon /sys/devices/pci*/*/usbmon; do
        [[ -e "${path}" ]] || continue
        printf 'warning: residual usbmon sysfs path: %s\n' "${path}" >&2
        clean=1
    done
    return "${clean}"
}

unload_selected_modules() {
    local index name attempt output
    local failed=0

    for ((index=${#SELECTED_NAMES[@]} - 1; index >= 0; index--)); do
        name="${SELECTED_NAMES[${index}]}"
        if ! module_is_loaded "${name}"; then
            info "  not loaded: ${name}"
        else
            for ((attempt=1; attempt<=5; attempt++)); do
                info "  rmmod ${name} (attempt ${attempt}/5)"
                if output="$(rmmod "${name}" 2>&1)"; then
                    [[ -z "${output}" ]] || info "${output}"
                else
                    info "${output}"
                fi
                if ! module_is_loaded "${name}"; then
                    info "  unloaded: ${name}"
                    break
                fi
                print_module_status
                [[ "${attempt}" == 5 ]] || sleep 1
            done
            if module_is_loaded "${name}"; then
                printf 'error: %s remains loaded; close readers/release dependencies, then retry\n' "${name}" >&2
                failed=1
            fi
        fi
        if [[ "${name}" == usbmon ]] && ! module_is_loaded "${name}"; then
            if ! check_usbmon_clean; then
                printf 'error: usbmon is unloaded but sysfs cleanup is incomplete; do not reload in this boot\n' >&2
                failed=1
            fi
        fi
    done
    return "${failed}"
}
