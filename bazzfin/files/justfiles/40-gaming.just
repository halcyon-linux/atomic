# vim: set ft=make :

# Bazzite-style gaming utilities for bazzfin. The heavy lifting
# (mangohud, gamescope, sched-ext schedulers, umu, input-remapper) is
# baked into the image; these recipes just automate the common bits.

alias scx := toggle-scx

# Show or toggle the sched-ext scheduler daemon (scx_loader), which
# auto-starts the scx_lavd scheduler (Bazzite's default) at boot.
# Options: status | enable | disable
[group("gaming")]
toggle-scx ACTION="status":
    #!/usr/bin/bash
    set -euo pipefail

    SVC="scx_loader.service"

    case "{{ ACTION }}" in
        status)
            echo "scx_loader.service: $(systemctl is-enabled "$SVC" 2>/dev/null || echo 'not found') / $(systemctl is-active "$SVC" 2>/dev/null || echo 'inactive')"
            echo
            echo "Running schedulers (scxctl):"
            if command -v scxctl >/dev/null 2>&1; then
                echo "  current: $(scxctl get 2>/dev/null || echo 'loader not active / none running')"
                echo "  available: $(scxctl list 2>/dev/null | tr '\n' ' ')"
            else
                echo "  scxctl not found -- is the scx-tools package installed?"
            fi
            ;;
        enable)
            sudo systemctl enable --now "$SVC"
            echo "scx_loader enabled: scx_lavd starts at boot (config: /etc/scx_loader/config.toml)"
            ;;
        disable)
            sudo systemctl disable --now "$SVC"
            echo "scx_loader disabled (any running sched-ext scheduler was stopped)"
            ;;
        *)
            echo "Usage: ujust toggle-scx [status|enable|disable]" >&2
            exit 1
            ;;
    esac

# Reinstall the Steam Flatpak -- Bazzite's `fix-reset-steam` equivalent,
# for when a Steam client update leaves the install broken. Your games
# and Proton prefixes (~/.steam, ~/.var/app/com.valvesoftware.Steam) are
# NOT touched.
[group("gaming")]
fix-reset-steam:
    #!/usr/bin/bash
    set -euo pipefail

    APP="com.valvesoftware.Steam"

    if flatpak --user list --app --columns=application 2>/dev/null | grep -qx "${APP}"; then
        SCOPE=(--user)
    elif flatpak --system list --app --columns=application 2>/dev/null | grep -qx "${APP}"; then
        SCOPE=(--system)
    else
        SCOPE=(--user)
        echo "Steam is not installed; installing it fresh (user installation)."
    fi

    flatpak uninstall -y "${SCOPE[@]}" "${APP}" || true
    flatpak install -y "${SCOPE[@]}" flathub "${APP}"

    echo
    echo "Done. Launch Steam again from your app launcher."

# Run protontricks (Flatpak build, so it can see the Flatpak Steam).
# Examples:
#   ujust protontricks -s                       # list installed games
#   ujust protontricks 440 winetricks d3dcompiler_47
#   ujust protontricks --gui                    # GUI mode
[group("gaming")]
protontricks *ARGS="":
    #!/usr/bin/bash
    set -euo pipefail

    if [[ -z "{{ ARGS }}" ]]; then
        exec flatpak run com.github.Matoking.protontricks
    fi
    exec flatpak run com.github.Matoking.protontricks {{ ARGS }}
