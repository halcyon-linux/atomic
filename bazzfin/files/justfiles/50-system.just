# vim: set ft=make :

# Bazzite-style system-management recipes for bazzfin. The packages they
# drive (uupd, greenboot, bpftune, cockpit) are baked into the image; the
# shared ublue-os-just package already provides `update`, `toggle-updates`,
# `changelogs`, `clean-system`, `logs-*`, `update-firmware`, etc., and
# 10-rebase.just provides `rebase` -- these are the pieces it doesn't ship.

# Show the current bootc/rpm-ostree deployment status
[group("system")]
status:
    #!/usr/bin/bash
    set -euo pipefail

    if command -v bootc >/dev/null 2>&1; then
        sudo bootc status
    else
        rpm-ostree status
    fi

# Roll back to the previous deployment (undo the last image update),
# then offer to reboot into it
[group("system")]
rollback:
    #!/usr/bin/bash
    set -euo pipefail

    if command -v bootc >/dev/null 2>&1; then
        echo "Running: sudo bootc rollback"
        sudo bootc rollback
    else
        echo "Running: sudo rpm-ostree rollback"
        sudo rpm-ostree rollback
    fi

    echo
    read -r -p "Rollback staged. Reboot into the previous deployment now? [Y/n] " reply
    if [[ -z "$reply" || "$reply" =~ ^[Yy] ]]; then
        echo "Rebooting..."
        systemctl reboot
    else
        echo "Staged. The rollback becomes active after the next reboot."
    fi

# Manage the Cockpit web console (https://localhost:9090 when enabled).
# Options: status | enable | disable
[group("system")]
cockpit ACTION="status":
    #!/usr/bin/bash
    set -euo pipefail

    SVC="cockpit.service"

    case "{{ ACTION }}" in
        status)
            echo "cockpit.service: $(systemctl is-enabled "$SVC" 2>/dev/null || echo disabled) / $(systemctl is-active "$SVC" 2>/dev/null || echo inactive)"
            ;;
        enable)
            sudo systemctl enable --now "$SVC"
            echo "Cockpit enabled -- open https://localhost:9090 (log in with your system user)"
            ;;
        disable)
            sudo systemctl disable --now "$SVC"
            echo "Cockpit disabled"
            ;;
        *)
            echo "Usage: ujust cockpit [status|enable|disable]" >&2
            exit 1
            ;;
    esac

alias bpftune := toggle-bpftune

# Show or toggle the bpftune adaptive-tuning daemon (bpftune-gaming),
# which continuously adjusts network/sysctl settings, Bazzite-style.
# Options: status | enable | disable
[group("system")]
toggle-bpftune ACTION="status":
    #!/usr/bin/bash
    set -euo pipefail

    SVC="bpftune.service"

    case "{{ ACTION }}" in
        status)
            echo "bpftune.service: $(systemctl is-enabled "$SVC" 2>/dev/null || echo disabled) / $(systemctl is-active "$SVC" 2>/dev/null || echo inactive)"
            ;;
        enable)
            sudo systemctl enable --now "$SVC"
            echo "bpftune enabled (adaptive kernel tuning active)"
            ;;
        disable)
            sudo systemctl disable --now "$SVC"
            echo "bpftune disabled"
            ;;
        *)
            echo "Usage: ujust toggle-bpftune [status|enable|disable]" >&2
            exit 1
            ;;
    esac
