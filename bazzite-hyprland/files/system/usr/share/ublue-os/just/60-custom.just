# Custom ujust recipes for bazzite-hyprland
# Installed system-wide to /usr/share/ublue-os/just/60-custom.just

# Display available custom commands for bazzite-hyprland
@custom-help:
    echo "=== bazzite-hyprland custom commands ==="
    echo "  ujust system-upgrade       : Comprehensive system & package upgrade (replaces Topgrade)"
    echo "  ujust rebase-to-custom TAG : Rebase machine to custom image (default tag: latest)"
    echo "  ujust setup-doom           : Set up personal Doom Emacs configuration"
    echo "  ujust setup-nix            : Verify or re-run Determinate Nix initialization"
    echo "  ujust update-nix           : Update Nix channels and flake registries"
    echo "  ujust switch-home-manager  : Apply ~/.config/home-manager/ configuration"
    echo "  ujust sync-dotfiles        : Pull and apply latest dotfiles via Chezmoi"
    echo "  ujust dots-ssh             : Set Chezmoi repository remote to SSH"
    echo "  ujust dots-push MSG        : Commit and push Chezmoi dotfile updates over SSH"
    echo "  ujust dots-status          : Show Chezmoi sync and Git status"
    echo "  ujust update-hyprpm        : Update and rebuild Hyprland plugins"
    echo "  ujust texlive-install PKG  : Install LaTeX package into ~/texmf (user mode)"
    echo "  ujust texlive-update       : Update all user-installed LaTeX packages"
    echo "  ujust bazzite-cleanup      : Collect Nix garbage and clean Flatpak/system caches"
    echo "  ujust brew-bundle          : Install/update all Homebrew packages from the Brewfile"

# Comprehensive upgrade recipe replacing Topgrade and maintaining all userspace tools
system-upgrade:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=========================================="
    echo "  Starting bazzite-hyprland System Upgrade"
    echo "=========================================="

    # Source profile environments if available
    [ -f /etc/profile.d/00-custom-environment.sh ] && . /etc/profile.d/00-custom-environment.sh
    [ -f /etc/profile.d/nix.sh ] && . /etc/profile.d/nix.sh
    [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ] && . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    [ -d /home/linuxbrew/.linuxbrew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null || true)"

    # 1. Distrobox
    if command -v distrobox >/dev/null 2>&1; then
        echo "--> [1/17] Upgrading Distrobox containers..."
        distrobox upgrade --all || true
    fi

    # 2. Firmware (fwupd)
    if command -v fwupdmgr >/dev/null 2>&1; then
        echo "--> [2/17] Checking for firmware updates..."
        fwupdmgr refresh || true
        fwupdmgr update --assume-yes || true
    fi

    # 3. Flatpak User Packages (System flatpaks excluded by design)
    if command -v flatpak >/dev/null 2>&1; then
        echo "--> [3/17] Updating user Flatpak applications..."
        flatpak update --user -y || true
        flatpak uninstall --unused --user -y || true
    fi

    # 4. User Manuals (mandb)
    if command -v mandb >/dev/null 2>&1; then
        echo "--> [4/17] Updating user manuals database..."
        mandb --user-db 2>/dev/null || mandb -u 2>/dev/null || true
    fi

    # 5. Nix flake registry & channels
    if command -v nix >/dev/null 2>&1; then
        echo "--> [5/17] Updating Nix flake registry and channels..."
        nix registry update || true
        nix-channel --update || true
    fi

    # 6. Home-Manager
    if [ -d "$HOME/.config/home-manager" ] && command -v nix >/dev/null 2>&1; then
        echo "--> [6/17] Updating Home-Manager packages..."
        if command -v home-manager >/dev/null 2>&1; then
            home-manager switch --flake "$HOME/.config/home-manager" || true
        else
            nix run home-manager -- switch --flake "$HOME/.config/home-manager" || true
        fi
    fi

    # 7. Hyprland plugins (hyprpm)
    if command -v hyprpm >/dev/null 2>&1 && [ "${XDG_CURRENT_DESKTOP:-}" = "Hyprland" ]; then
        echo "--> [7/17] Updating Hyprland plugins..."
        hyprpm update || true
        hyprpm reload -n || true
    fi

    # 8. Cargo installed binaries
    if command -v cargo-install-update >/dev/null 2>&1; then
        echo "--> [8/17] Updating Cargo crates..."
        cargo install-update -a || true
    fi

    # 9. Doom Emacs
    if [ -x "$HOME/.config/emacs/bin/doom" ]; then
        echo "--> [9/17] Upgrading Doom Emacs packages..."
        "$HOME/.config/emacs/bin/doom" upgrade --force || true
        "$HOME/.config/emacs/bin/doom" sync --gc || true
    fi

    # 10. Visual Studio Code extensions
    if command -v code >/dev/null 2>&1; then
        echo "--> [10/17] Updating Visual Studio Code extensions..."
        code --update-extensions || true
    fi

    # 11. TLDR (tealdeer or tldr)
    if command -v tldr >/dev/null 2>&1; then
        echo "--> [11/17] Updating TLDR cache..."
        tldr --update || true
    fi

    # 12. Pixi
    if command -v pixi >/dev/null 2>&1; then
        echo "--> [12/17] Updating Pixi global packages..."
        pixi global update || true
    fi

    # 13. Containers (Podman auto-update)
    if command -v podman >/dev/null 2>&1; then
        echo "--> [13/17] Running Podman container auto-update..."
        podman auto-update || true
    fi

    # 14. uv tools
    if command -v uv >/dev/null 2>&1; then
        echo "--> [14/17] Updating uv tools..."
        uv tool upgrade --all || true
    fi

    # 15. Bun
    if command -v bun >/dev/null 2>&1; then
        echo "--> [15/17] Checking Bun updates..."
        bun upgrade 2>/dev/null || true
    fi

    # 16. Yazi packages
    if command -v ya >/dev/null 2>&1; then
        echo "--> [16/17] Updating Yazi packages..."
        ya pkg upgrade || true
    fi

    # 17. Homebrew packages (via Brewfile)
    if command -v brew >/dev/null 2>&1; then
        BREWFILE="${HOME}/.config/Brewfile"
        [ -f "${BREWFILE}" ] || BREWFILE="/usr/share/ublue-os/Brewfile"
        if [ -f "${BREWFILE}" ]; then
            echo "--> [Brew] Updating Homebrew packages from ${BREWFILE}..."
            brew bundle --file="${BREWFILE}" || true
        else
            echo "--> [Brew] No Brewfile found; running brew upgrade..."
            brew upgrade || true
        fi
    fi

    # ZSH update
    if command -v zsh >/dev/null 2>&1; then
        echo "--> [17/17] Running custom zsh-update if defined in shell environment..."
        zsh -i -c 'type zsh-update >/dev/null 2>&1 && zsh-update' || true
    fi

    echo "=========================================="
    echo "  All updates completed successfully!     "
    echo "=========================================="

# Rebase current system to the custom bazzite-hyprland container image
rebase-to-custom tag="latest":
    #!/usr/bin/env bash
    set -euo pipefail
    IMAGE="ghcr.io/aahsnr-work/bazzite-hyprland:{{tag}}"
    echo "Rebasing system to ${IMAGE}..."
    if command -v bootc >/dev/null 2>&1; then
        sudo bootc switch "${IMAGE}"
    elif command -v rpm-ostree >/dev/null 2>&1; then
        sudo rpm-ostree rebase "ostree-unverified-registry:${IMAGE}"
    else
        echo "Neither bootc nor rpm-ostree was detected on this system." >&2
        exit 1
    fi
    echo "Rebase prepared successfully!"
    echo "Please reboot when ready to launch the new image deployment:"
    echo "  systemctl reboot"

# Set up personal Doom Emacs configuration after login
setup-doom:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Initializing Doom Emacs Setup ==="
    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git is required but not found." >&2
        exit 1
    fi
    if ! command -v emacs >/dev/null 2>&1; then
        echo "Error: emacs is not installed on the system." >&2
        exit 1
    fi

    if [ ! -d "$HOME/.config/doom" ]; then
        echo "Cloning doom configuration from git@github.com:aahsnr-configs/doom.git..."
        git clone git@github.com:aahsnr-configs/doom.git "$HOME/.config/doom"
    else
        echo "Existing ~/.config/doom found."
    fi

    if [ ! -d "$HOME/.config/emacs" ]; then
        echo "Cloning Doom Emacs framework (github.com/doomemacs/core)..."
        git clone --depth 1 https://github.com/doomemacs/core "$HOME/.config/emacs"
    else
        echo "Existing ~/.config/emacs found."
    fi

    echo "Installing Doom Emacs non-interactively (-y suppresses prompts)..."
    "$HOME/.config/emacs/bin/doom" -y install

    echo "Running doom sync --gc..."
    "$HOME/.config/emacs/bin/doom" sync --gc

    echo "Doom Emacs is now fully installed and configured!"

# Configure Chezmoi source git remote to use SSH
dots-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v chezmoi >/dev/null 2>&1; then
        SOURCE_DIR="$(chezmoi source-path)"
        if [ -d "${SOURCE_DIR}/.git" ]; then
            git -C "${SOURCE_DIR}" remote set-url origin git@github.com:aahsnr-configs/dots.git
            echo "Chezmoi origin remote set to SSH: git@github.com:aahsnr-configs/dots.git"
            git -C "${SOURCE_DIR}" remote -v
        else
            echo "Chezmoi source git repository not initialized. Run 'ujust sync-dotfiles' first." >&2
            exit 1
        fi
    else
        echo "Chezmoi not found in PATH." >&2
        exit 1
    fi

# Commit and push dotfile changes to GitHub over SSH
dots-push message="":
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v chezmoi >/dev/null 2>&1; then
        SOURCE_DIR="$(chezmoi source-path)"
        if [ ! -d "${SOURCE_DIR}/.git" ]; then
            echo "Chezmoi source git repository not found. Run 'ujust sync-dotfiles' first." >&2
            exit 1
        fi
        MSG="{{message}}"
        if [ -z "${MSG}" ]; then
            read -rp "Enter commit message: " MSG
        fi
        if [ -z "${MSG}" ]; then
            MSG="Update dotfiles $(date +'%Y-%m-%d %H:%M:%S')"
        fi
        echo "Staging chezmoi changes..."
        git -C "${SOURCE_DIR}" add -A
        echo "Committing with message: ${MSG}"
        git -C "${SOURCE_DIR}" commit -m "${MSG}" || echo "No changes to commit."
        echo "Pushing changes to remote via SSH..."
        git -C "${SOURCE_DIR}" push origin HEAD
        echo "Dotfiles successfully pushed!"
    else
        echo "Chezmoi not found in PATH." >&2
        exit 1
    fi

# Display Chezmoi sync and Git working tree status
dots-status:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v chezmoi >/dev/null 2>&1; then
        echo "=== Chezmoi Status ==="
        chezmoi status || true
        SOURCE_DIR="$(chezmoi source-path)"
        if [ -d "${SOURCE_DIR}/.git" ]; then
            echo "=== Git Working Tree Status (${SOURCE_DIR}) ==="
            git -C "${SOURCE_DIR}" status -s || true
        fi
    else
        echo "Chezmoi not found in PATH." >&2
        exit 1
    fi

# Verify or manually trigger Determinate Nix setup
setup-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f /nix/receipt.json ]; then
        echo "Determinate Nix is already initialized (/nix/receipt.json exists)."
        systemctl status nix-daemon.service --no-pager || true
    else
        echo "Running Determinate Nix installer with ostree planner..."
        curl --proto "=https" --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install ostree --no-confirm
    fi

# Update Nix flake registries and user channels
update-nix:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f /etc/profile.d/nix.sh ] && . /etc/profile.d/nix.sh
    if command -v nix >/dev/null 2>&1; then
        echo "Updating Nix flake registry..."
        nix registry update || true
        echo "Updating Nix channels..."
        nix-channel --update || true
    else
        echo "Nix is not in PATH. Please run: ujust setup-nix" >&2
        exit 1
    fi

# Re-evaluate and switch Home-Manager configuration from ~/.config/home-manager/
switch-home-manager:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f /etc/profile.d/nix.sh ] && . /etc/profile.d/nix.sh
    [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ] && . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    if ! command -v nix >/dev/null 2>&1; then
        echo "Nix daemon not detected. Run 'ujust setup-nix' first." >&2
        exit 1
    fi
    if [ -d "$HOME/.config/home-manager" ]; then
        echo "Applying Home-Manager configuration..."
        if command -v home-manager >/dev/null 2>&1; then
            home-manager switch --flake "$HOME/.config/home-manager"
        else
            nix run home-manager -- switch --flake "$HOME/.config/home-manager"
        fi
        echo "Home-Manager switch complete."
    else
        echo "No ~/.config/home-manager directory found. Run 'ujust sync-dotfiles' first." >&2
        exit 1
    fi

# Pull and apply latest dotfiles using Chezmoi
sync-dotfiles:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v chezmoi >/dev/null 2>&1; then
        echo "Applying Chezmoi dotfiles..."
        chezmoi update || chezmoi apply
        echo "Dotfiles synchronized successfully."
    else
        echo "Chezmoi not found in PATH." >&2
        exit 1
    fi

# Rebuild and update Hyprland plugins via hyprpm
update-hyprpm:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v hyprpm >/dev/null 2>&1; then
        echo "Updating Hyprland plugins..."
        hyprpm update
        hyprpm reload
        echo "Hyprland plugins updated."
    else
        echo "hyprpm command not found. Ensure you are running a Hyprland session." >&2
        exit 1
    fi

# Install a TeX Live package in user mode into ~/texmf
texlive-install package:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v tlmgr >/dev/null 2>&1; then
        [ -f /etc/profile.d/texlive.sh ] && . /etc/profile.d/texlive.sh
    fi
    if command -v tlmgr >/dev/null 2>&1; then
        if [ ! -d "$HOME/texmf" ]; then
            echo "Initializing TeX Live usertree in $HOME/texmf..."
            tlmgr init-usertree
        fi
        echo "Installing TeX Live package '{{package}}' in user mode..."
        tlmgr --usermode install "{{package}}"
        echo "Package '{{package}}' installed successfully into $HOME/texmf."
    else
        echo "tlmgr not found in PATH." >&2
        exit 1
    fi

# Update all user-installed TeX Live packages in ~/texmf
texlive-update:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v tlmgr >/dev/null 2>&1; then
        [ -f /etc/profile.d/texlive.sh ] && . /etc/profile.d/texlive.sh
    fi
    if command -v tlmgr >/dev/null 2>&1; then
        echo "Updating user TeX Live packages in $HOME/texmf..."
        tlmgr --usermode update --all
    else
        echo "tlmgr not found in PATH." >&2
        exit 1
    fi

# Reclaim disk space (Nix garbage collection, Flatpak unused runtimes, cache trim)
bazzite-cleanup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Cleaning up system and user caches ==="
    if command -v nix-collect-garbage >/dev/null 2>&1; then
        echo "Collecting Nix garbage (deleting old derivations)..."
        nix-collect-garbage -d || true
    fi
    if command -v flatpak >/dev/null 2>&1; then
        echo "Uninstalling unused Flatpak runtimes..."
        flatpak uninstall --unused -y || true
    fi
    echo "Trimming journald logs..."
    journalctl --vacuum-time=7d || true
    echo "Cleanup complete!"

# Install or update all Homebrew packages declared in the Brewfile
# Uses ~/.config/Brewfile (personal) if it exists, else /usr/share/ublue-os/Brewfile (system default)
brew-bundle:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -d /home/linuxbrew/.linuxbrew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null || true)"
    if ! command -v brew >/dev/null 2>&1; then
        echo "Error: brew not found. Ensure brew-setup.service has run (reboot or: sudo systemctl start brew-setup.service)." >&2
        exit 1
    fi
    BREWFILE="${HOME}/.config/Brewfile"
    if [ ! -f "${BREWFILE}" ]; then
        BREWFILE="/usr/share/ublue-os/Brewfile"
    fi
    if [ ! -f "${BREWFILE}" ]; then
        echo "No Brewfile found at ~/.config/Brewfile or /usr/share/ublue-os/Brewfile." >&2
        exit 1
    fi
    echo "Installing/updating Homebrew packages from ${BREWFILE}..."
    brew bundle --file="${BREWFILE}"
    echo "All Homebrew packages are up to date!"
