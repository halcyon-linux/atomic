# vim: set ft=make :

alias upgrade := update

# Update everything topgrade would update, adapted for this image-based system
[group("system")]
update:
    #!/usr/bin/bash
    set -uo pipefail

    run_if() {
        local tool="$1"; shift
        if command -v "$tool" >/dev/null 2>&1; then
            echo ":: Running ${tool}"
            "$@"
        else
            echo ":: Skipping ${tool} (not installed)"
        fi
    }

    echo "===== Firmware upgrades (fwupd) ====="
    if command -v fwupdmgr >/dev/null 2>&1; then
        sudo fwupdmgr refresh --force || true
        if sudo fwupdmgr get-updates | grep -q .; then
            sudo fwupdmgr update || true
        else
            echo "Firmware already up to date"
        fi
    fi

    echo "===== Flatpak User Packages ====="
    flatpak update --user -y || true

    echo "===== System Manuals ====="
    sudo mandb || true
    echo "===== User Manuals ====="
    mandb --user-db || true

    echo "===== hyprpm ====="
    run_if hyprpm hyprpm update

    echo "===== Cargo ====="
    run_if cargo-install-update cargo install-update --all

    echo "===== Doom Emacs ====="
    if [[ -x "$HOME/.config/emacs/bin/doom" ]]; then
        "$HOME/.config/emacs/bin/doom" upgrade || true
    fi

    echo "===== Visual Studio Code extensions ====="
    run_if code code --update-extensions

    echo "===== TLDR ====="
    run_if tldr tldr --update

    echo "===== pixi ====="
    run_if pixi pixi self-update
    run_if pixi pixi global update

    echo "===== uv ====="
    if command -v uv >/dev/null 2>&1; then
        uv self update || true
        uv tool upgrade --all || true
        uv python upgrade || true
    fi

    echo "===== Bun (managed by Homebrew) ====="
    run_if brew brew upgrade bun

    echo "===== Yazi packages ====="
    run_if ya ya pkg upgrade

    echo "===== Homebrew ====="
    run_if brew brew update
    run_if brew brew upgrade

    echo "===== Distrobox ====="
    run_if distrobox distrobox upgrade --all

    echo "===== Containers (podman auto-update) ====="
    if command -v podman >/dev/null 2>&1 && systemctl is-enabled podman-auto-update >/dev/null 2>&1; then
        sudo systemctl start podman-auto-update || true
    else
        echo "podman auto-update disabled"
    fi

    echo "===== zsh plugins (zsh-update) ====="
    if [[ -f "$HOME/.zshrc" ]]; then
        zsh -i -c 'zsh-update' 2>/dev/null || true
    fi

    echo
    echo "Note: system (dnf) and system Flatpak updates happen by rebasing to a"
    echo "new image build -- run 'ujust rebase' after this."
