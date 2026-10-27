#!/usr/bin/env bash
set -euo pipefail

log_info() {
    local message="${1}"
    printf '[INFO] %s\n' "${message}"
}

log_error() {
    local message="${1}"
    printf '[ERROR] %s\n' "${message}" >&2
}

require_command() {
    local cmd="${1}"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        log_error "Required command not found: ${cmd}"
        return 1
    fi
}

require_fedora() {
    local os_release="${1}"
    local line=""
    local id=""

    if [[ ! -f "${os_release}" ]]; then
        log_error "This installer requires Fedora"
        return 1
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == ID=* ]]; then
            id="${line#ID=}"
            id="${id#\"}"
            id="${id%\"}"
        fi
    done < "${os_release}"

    if [[ "${id}" != "fedora" ]]; then
        log_error "This installer requires Fedora"
        return 1
    fi
}

run_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

ensure_dnf_plugins() {
    if dnf config-manager --help >/dev/null 2>&1 && dnf copr --help >/dev/null 2>&1; then
        return 0
    fi
    log_info "Installing dnf5-plugins"
    run_root dnf -y install dnf5-plugins
}

enable_fedora_workstation() {
    log_info "Enabling fedora-workstation"
    run_root dnf config-manager setopt fedora-workstation.enabled=1
}

enable_copr() {
    local repo="${1}"
    log_info "Enabling COPR ${repo}"
    run_root dnf -y copr enable "${repo}"
}

install_nier_desktop() {
    log_info "Installing nier-desktop"
    run_root dnf -y install nier-desktop
}

desktop_user() {
    local euid="${1}"
    local sudo_user="${2}"
    local current_user="${3}"

    if [[ "${euid}" -ne 0 ]]; then
        printf '%s\n' "${current_user}"
        return 0
    fi
    if [[ -n "${sudo_user}" && "${sudo_user}" != "root" ]]; then
        printf '%s\n' "${sudo_user}"
        return 0
    fi
    log_error "nier apply must run as the desktop user. Run this script as that user, or with sudo from that user."
    return 1
}

apply_system_wide() {
    local nier_bin="${1}"
    log_info "Running nier apply --system-wide"
    run_root "${nier_bin}" apply --system-wide
}

apply_user() {
    local nier_bin="${1}"
    local user="${2}"
    local euid="${3}"
    log_info "Running nier apply"
    if [[ "${euid}" -eq 0 ]]; then
        runuser -u "${user}" -- "${nier_bin}" apply
    else
        "${nier_bin}" apply
    fi
}

main() {
    local os_release="/etc/os-release"
    local nier_bin="/usr/local/bin/nier"
    local -a copr_repos=(
        "byte0/hyprland"
        "byte0/quickshell"
        "byte0/nier"
    )
    local repo=""
    local user=""
    local current_user="${USER:-}"

    require_fedora "${os_release}"
    require_command dnf
    if [[ "${EUID}" -ne 0 ]]; then
        require_command sudo
    else
        require_command runuser
    fi
    if [[ -z "${current_user}" ]]; then
        current_user="$(id -un)"
    fi

    ensure_dnf_plugins
    enable_fedora_workstation
    for repo in "${copr_repos[@]}"; do
        enable_copr "${repo}"
    done
    install_nier_desktop

    if [[ ! -x "${nier_bin}" ]]; then
        log_error "nier was not installed at ${nier_bin}"
        return 1
    fi

    apply_system_wide "${nier_bin}"
    user="$(desktop_user "${EUID}" "${SUDO_USER:-}" "${current_user}")"
    apply_user "${nier_bin}" "${user}" "${EUID}"
}

main "$@"
