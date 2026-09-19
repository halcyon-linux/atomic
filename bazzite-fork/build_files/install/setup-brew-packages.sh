#!/usr/bin/env bash
set -euo pipefail

echo "=== Registering Homebrew package manifest ==="

# Packages to be installed by Homebrew for the user
BREW_PACKAGES=(
  atuin
  bat
  btop
  bun
  cava
  chafa
  direnv
  dust
  eza
  fd
  fzf
  git
  gh
  git-lfs
  gnuplot
  lazygit
  pandoc
  pixi
  ripgrep
  starship
  tealdeer
  uv
  yazi
  zellij
)

install -d /etc/hyprland-image
printf '%s\n' "${BREW_PACKAGES[@]}" > /etc/hyprland-image/brew-packages

echo "Registered ${#BREW_PACKAGES[@]} Homebrew packages in /etc/hyprland-image/brew-packages"
