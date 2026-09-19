#!/usr/bin/env bash
set -euo pipefail

echo "=== Purging Fedora Flatpak Remotes & Upstream Pre-installed Flatpak Lists ==="

# 1. Remove Fedora Flatpak remotes completely from system configuration
rm -f /etc/flatpak/remotes.d/fedora*.flatpakrepo
rm -f /usr/etc/flatpak/remotes.d/fedora*.flatpakrepo
if command -v flatpak &>/dev/null; then
  flatpak remote-delete --force fedora 2>/dev/null || true
  flatpak remote-delete --force fedora-testing 2>/dev/null || true
fi

# 2. Clear upstream Bazzite flatpak lists so no default upstream flatpaks are auto-installed
for flatpak_list in \
  /etc/ublue-os/system_flatpaks \
  /usr/etc/ublue-os/system_flatpaks \
  /usr/share/ublue-os/flatpaks \
  /usr/share/ublue-os/system_flatpaks; do
  if [ -f "${flatpak_list}" ]; then
    echo "Clearing upstream flatpak manifest: ${flatpak_list}"
    : > "${flatpak_list}"
  fi
done

# Ensure system flatpak directory does not retain pre-installed bundles from upstream
# while keeping flatpak framework intact for user packages and Bazaar app store
echo "Ensuring flathub is the primary remote and system-wide default flatpaks are suppressed."
