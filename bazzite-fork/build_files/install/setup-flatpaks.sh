#!/usr/bin/env bash
set -euo pipefail

echo "=== Removing unwanted system Flatpaks from base image ==="

# Flatpaks to remove from the system scope (from Fedora/base image)
REMOVE_SYSTEM_FLATPAKS=(
  org.fedoraproject.MediaWriter
  org.fedoraproject.Platform
  org.fedoraproject.Platform.CL.default
  org.fedoraproject.Platform.GL.default
  org.fedoraproject.Platform.Locale
  org.gnome.Calculator
  org.gnome.Calendar
  org.gnome.Characters
  org.gnome.Connections
  org.gnome.Contacts
  org.gnome.Extensions
  org.gnome.Logs
  org.gnome.Loupe
  org.gnome.Maps
  org.gnome.NautilusPreviewer
  org.gnome.Papers
  org.gnome.Snapshot
  org.gnome.TextEditor
  org.gnome.Weather
  org.gnome.baobab
  org.gnome.clocks
)

REMOVED=0
ALREADY_ABSENT=0
FAILED=0

if ! command -v flatpak >/dev/null 2>&1; then
  echo "WARNING: 'flatpak' binary not found in the image; skipping removal." >&2
else
  for pkg in "${REMOVE_SYSTEM_FLATPAKS[@]}"; do
    if flatpak --system info "${pkg}" >/dev/null 2>&1; then
      if flatpak --system uninstall --noninteractive --assumeyes "${pkg}"; then
        echo "OK: uninstalled system Flatpak '${pkg}'"
        REMOVED=$((REMOVED + 1))
      else
        echo "WARNING: failed to uninstall system Flatpak '${pkg}'" >&2
        FAILED=$((FAILED + 1))
      fi
    else
      echo "SKIP: system Flatpak '${pkg}' is not installed in the base image"
      ALREADY_ABSENT=$((ALREADY_ABSENT + 1))
    fi
  done
fi

echo
echo "=== System Flatpak removal summary (build time) ==="
echo "  Uninstalled : ${REMOVED}"
echo "  Not present : ${ALREADY_ABSENT}"
echo "  Failed      : ${FAILED}"
if [[ "${FAILED}" -gt 0 ]]; then
  echo "NOTE: failed removals are retried at first login by the user-flatpak-setup service." >&2
fi

# Record the removal manifest in /etc/hyprland-image so the runtime
# system-flatpak-setup service (see the default-flatpaks module,
# build_files/install/setup-default-flatpaks.sh) can retry removing any of
# these Flatpaks that reappear after a base image update.
install -d /etc/hyprland-image
printf '%s\n' "${REMOVE_SYSTEM_FLATPAKS[@]}" > /etc/hyprland-image/system-flatpaks-remove

echo "Flatpak removal manifest created at /etc/hyprland-image/system-flatpaks-remove"
