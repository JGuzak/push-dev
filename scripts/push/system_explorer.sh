#!/usr/bin/env bash
#
# system_explorer.sh — Explore an undocumented Linux system with proper YAML output + live streaming logs with timestamps
#

set -euo pipefail

VERBOSE=false
OUTPUT_FILE=""
REMOTE_HOST=""

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Explore a Linux system for OS, hardware, cron jobs, services, and package manager.

Options:
  --help               Show this help message
  --verbose, -v        Print collected information to stdout (live streaming with timestamps)
  --output, -o FILE    Save results to a YAML file
  --remote, -r HOST    SSH into HOST (user@hostname) and run commands remotely

Examples:
  $0 --verbose
  $0 --output system_info.yaml
  $0 --remote user@192.168.1.10 --output remote_info.yaml --verbose
EOF
    exit 0
}

yaml_block() {
    local key="$1"
    local cmd="$2"
    echo "$key:"
    $cmd 2>/dev/null | while IFS= read -r line; do
        if [ -n "$line" ]; then
            printf "  - %s\n" "$line"
        fi
    done
}

yaml_kv_block() {
    local key="$1"
    local cmd="$2"
    echo "$key:"
    $cmd 2>/dev/null | while IFS= read -r line; do
        if [[ "$line" == *:* ]]; then
            printf "  %s\n" "$line"
        else
            printf "  - %s\n" "$line"
        fi
    done
}

collect_data() {
    local CMD_PREFIX="$1"

    {
        echo "os_info:"
        echo "  uname: \"$($CMD_PREFIX uname -a 2>/dev/null)\""
        $CMD_PREFIX cat /etc/*release 2>/dev/null | while IFS= read -r line; do
            printf "  %s\n" "$line"
        done

        yaml_kv_block "hardware_info" "$CMD_PREFIX lscpu"
        yaml_block "block_devices" "$CMD_PREFIX lsblk"
        yaml_block "memory" "$CMD_PREFIX free -h"
        yaml_block "disk_usage" "$CMD_PREFIX df -h"

        yaml_block "network_info" "$CMD_PREFIX ip addr show"
        yaml_block "routes" "$CMD_PREFIX ip route show"

        echo "cron_jobs:"
        $CMD_PREFIX crontab -l 2>/dev/null | while IFS= read -r line; do
            printf "  - %s\n" "$line"
        done || echo "  - No user cron jobs found"
        yaml_block "cron_system" "$CMD_PREFIX ls -l /etc/cron*"

        yaml_block "services" "$CMD_PREFIX systemctl list-units --type=service --all || service --status-all"

        yaml_block "users" "$CMD_PREFIX cat /etc/passwd"

        yaml_block "environment_variables" "$CMD_PREFIX printenv"

        echo "package_manager:"
        local pkgmgr=""
        for pm in apt yum dnf zypper pacman apk; do
            if $CMD_PREFIX command -v $pm >/dev/null 2>&1; then
                pkgmgr=$pm
                break
            fi
        done
        if [ -n "$pkgmgr" ]; then
            echo "  name: \"$pkgmgr\""
            echo "  path: \"$($CMD_PREFIX command -v $pkgmgr 2>/dev/null)\""
        else
            echo "  name: null"
            echo "  path: null"
        fi
    }
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) usage ;;
        --verbose|-v) VERBOSE=true ;;
        --output|-o) OUTPUT_FILE="$2"; shift ;;
        --remote|-r) REMOTE_HOST="$2"; shift ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

if [ -n "$REMOTE_HOST" ]; then
    CMD_PREFIX="ssh -o ConnectTimeout=5 $REMOTE_HOST"
else
    CMD_PREFIX=""
fi

TMP_FILE=$(mktemp)

if [ "$VERBOSE" = true ]; then
    collect_data "$CMD_PREFIX" | tee "$TMP_FILE" | while IFS= read -r line; do
        printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$line"
    done
else
    collect_data "$CMD_PREFIX" > "$TMP_FILE"
fi

if [ -n "$OUTPUT_FILE" ]; then
    mv "$TMP_FILE" "$OUTPUT_FILE"
    [ "$VERBOSE" = true ] && echo "Data saved to $OUTPUT_FILE"
else
    rm "$TMP_FILE"
fi
