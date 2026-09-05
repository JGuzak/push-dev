#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/module-common.sh"

usage() {
    cat <<'EOF'
Usage:
  uninstall.sh [options]

Options:
  -p, -path, --path <path>  Directory containing packaged *.ko files.
                            Default: this script's directory.
  -h, -help, --help          Show this help.

Run as root on the target. Unloads only modules identified by the selected files,
in reverse order, with at most five attempts per module. Never forces removal or
kills readers. Files, device nodes, preferences, and boot hooks are not removed.
EOF
}

main() {
    local package_path="${SCRIPT_DIR}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|-path|--path)
                [[ $# -ge 2 ]] || die "$1 requires a directory"
                package_path="$2"
                shift 2
                ;;
            -h|-help|--help) usage; return 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    require_root
    require_command modinfo
    require_command rmmod
    require_command sleep
    select_modules "${package_path}"
    # Recovery must work even when the package checksum or kernel version changed.
    print_module_status
    if ! unload_selected_modules; then
        print_module_status
        die "uninstall incomplete; see module use counts and lifecycle warnings above"
    fi
    print_module_status
    info "Uninstall complete. Package files were retained."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
