#!/usr/bin/env bash
#
# Remove packages inherited unconditionally from the base image. Missing
# packages (e.g. Bazzite/SteamDeck-specific ones absent on a plain
# Universal Blue base) are tolerated; anything installed is removed.
#
# Kept as a script instead of the `dnf` module's `remove:` list because
# several entries below are glob patterns ('vim*', 'steamdeck*', ...),
# which that list doesn't support.
#
set -eoux pipefail

REMOVE_ALL=(
  bluez-cups
  cage
  'cardwire*'
  epiphany-runtime
  erlang-srpm-macros
  firefox
  firefox-langpacks
  fish
  fzf
  go-srpm-macros
  google-noto-sans-balinese-fonts
  google-noto-sans-cjk-fonts
  google-noto-sans-javanese-fonts
  google-noto-sans-sundanese-fonts
  gstreamer1-plugins-good-qt
  gstreamer1-plugins-good-qt6
  jupiter-sd-mounting-btrfs
  htop
  hunspell-en-AU
  nano
  nano-default-editor
  NetworkManager-ssh-gnome
  openrazer
  papers-libs
  papers-nautilus
  papers-previewer
  papers-thumbnailer
  ptyxis
  twitter-twemoji-fonts
  rom-properties
  rom-properties-common
  rom-properties-gtk4
  rom-properties-localsearch3
  rom-properties-utils
  'steamdeck*'
  tree-sitter-srpm-macros
  'vim*'
  yad
  ydotool
  zenergy
  zenergy-akmod-modules
  zinnia
  zinnia-tomoe-ja
)

TO_REMOVE=()
for pkg in "${REMOVE_ALL[@]}"; do
  mapfile -t MATCHES < <(rpm -qa --queryformat '%{NAME}\n' "${pkg}" 2>/dev/null || true)
  for match in "${MATCHES[@]}"; do
    [[ -n "${match}" ]] && TO_REMOVE+=("${match}")
  done
done

if [[ ${#TO_REMOVE[@]} -gt 0 ]]; then
  mapfile -t UNIQUE_REMOVE < <(printf '%s\n' "${TO_REMOVE[@]}" | sort -u)
  echo "Removing ${#UNIQUE_REMOVE[@]} installed package(s): ${UNIQUE_REMOVE[*]}"
  dnf5 -y remove "${UNIQUE_REMOVE[@]}"
else
  echo "None of the specified packages are installed; skipping removal."
fi
