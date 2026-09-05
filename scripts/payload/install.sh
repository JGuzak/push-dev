#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/module-common.sh"

usage() {
    cat <<'EOF'
Usage:
  install.sh [options]

Options:
  -p, -path, --path <path>  Directory containing packaged *.ko files.
                            Default: this script's directory.
  --reload                  Unload selected loaded modules before loading.
                            Not permitted for an already-loaded usbmon.
  -h, -help, --help          Show this help.

Run as root on the target. Already-loaded modules are left unchanged by default.
No forced unloads, dependency auto-loading, Live restarts, or boot hooks.
EOF
}

main() {
    local package_path="${SCRIPT_DIR}"
    local reload=0
    local index name release vermagic

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|-path|--path)
                [[ $# -ge 2 ]] || die "$1 requires a directory"
                package_path="$2"
                shift 2
                ;;
            --reload) reload=1; shift ;;
            -h|-help|--help) usage; return 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    require_root
    require_command modinfo
    require_command insmod
    require_command sha256sum
    require_command grep
    require_command uname
    if [[ "${reload}" == 1 ]]; then
        require_command rmmod
        require_command sleep
    fi
    select_modules "${package_path}"
    verify_package
    release="$(uname -r)"
    # Validate every selected module before changing any running module.
    for index in "${!SELECTED_MODULES[@]}"; do
        name="${SELECTED_NAMES[${index}]}"
        vermagic="$(modinfo -F vermagic "${SELECTED_MODULES[${index}]}")" ||
            die "cannot read vermagic: ${name}"
        [[ "${vermagic%% *}" == "${release}" ]] ||
            die "kernel release mismatch for ${name}: ${vermagic} (running ${release})"
        if [[ "${name}" == usbmon ]]; then
            if module_is_loaded "${name}"; then
                [[ "${reload}" == 0 ]] ||
                    die "usbmon reload is not validated; leaving the loaded module untouched"
            else
                check_usbmon_clean || die "stale usbmon sysfs state; reboot and investigate before loading"
            fi
        fi
    done
    print_module_status
    if [[ "${reload}" == 1 ]]; then
        unload_selected_modules || die "unload failed; no replacement modules were loaded"
    fi
    for index in "${!SELECTED_MODULES[@]}"; do
        name="${SELECTED_NAMES[${index}]}"
        if module_is_loaded "${name}"; then
            info "  already loaded, unchanged: ${name} (not verified against packaged binary)"
            continue
        fi
        info "  loading: ${name}"
        insmod "${SELECTED_MODULES[${index}]}" ||
            die "insmod failed for ${name}; inspect dmesg; previously loaded modules were left in place"
        module_is_loaded "${name}" || die "${name} absent from sysfs after insmod"
    done
    print_module_status
    info "Install complete. No persistent boot configuration was changed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
