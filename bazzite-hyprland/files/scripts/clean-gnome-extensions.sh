#!/usr/bin/env bash
set -euo pipefail

echo "=== Safely Reversing Bazzite's build-gnome-extensions ==="

EXT_DIR="/usr/share/gnome-shell/extensions"

# 1. Remove all extension directories built/installed by build-gnome-extensions
extensions=(
  "logomenu@aryan_k"
  "compiz-windows-effect@hermes83.github.com"
  "compiz-alike-magic-lamp-effect@hermes83.github.com"
  "hotedge@jonathan.jdoda.ca"
  "restartto@tiagoporsch.github.io"
  "appindicatorsupport@rgcjonas.gmail.com"
  "add-to-steam@pupper.space"
  "caffeine@patapon.info"
  "burn-my-windows@schneegans.github.com"
  "desktop-cube@schneegans.github.com"
  "blur-my-shell@aunetx"
  "bazaar-integration@kolunmi.github.io"
  "tmp"
)

for ext in "${extensions[@]}"; do
  target="${EXT_DIR}/${ext}"
  if [ -d "${target}" ] || [ -f "${target}" ]; then
    echo "Removing extension: ${target}"
    rm -rf "${target}"
  fi
done

# Since bazzite-hyprland completely removes GNOME Shell, clean up any remaining extensions
if [ -d "${EXT_DIR}" ]; then
  echo "Cleaning any remaining extensions from ${EXT_DIR}..."
  rm -rf "${EXT_DIR:?}"/*
  rmdir "${EXT_DIR}" 2>/dev/null || true
fi

# Clean parent gnome-shell directory if empty
if [ -d "/usr/share/gnome-shell" ]; then
  rmdir "/usr/share/gnome-shell" 2>/dev/null || true
fi

# 2. Remove upstream GLib schema overrides enabling these extensions
override_files=(
  "/usr/share/glib-2.0/schemas/zz0-03-bazzite-desktop-silverblue-extensions.gschema.override"
  "/usr/share/ublue-os/dconfs/desktop-silverblue/zz0-03-bazzite-desktop-silverblue-extensions.gschema.override"
  "/etc/dconf/db/distro.d/10-bazzite-deck-silverblue-logomenu"
  "/usr/share/ublue-os/dconfs/desktop-silverblue/10-bazzite-deck-silverblue-logomenu"
)

for override in "${override_files[@]}"; do
  if [ -f "${override}" ]; then
    echo "Removing schema/dconf override: ${override}"
    rm -f "${override}"
  fi
done

# Remove any other extension-specific overrides matching patterns
rm -f /usr/share/glib-2.0/schemas/*extensions*.gschema.override 2>/dev/null || true
rm -f /usr/share/glib-2.0/schemas/*logomenu*.gschema.override 2>/dev/null || true
rm -f /etc/dconf/db/distro.d/*logomenu* 2>/dev/null || true

# 3. Recompile GLib schemas cleanly
if command -v glib-compile-schemas >/dev/null 2>&1 && [ -d "/usr/share/glib-2.0/schemas" ]; then
  echo "Re-compiling system GLib schemas..."
  glib-compile-schemas /usr/share/glib-2.0/schemas
fi

# 4. Update dconf database if dconf is installed
if command -v dconf >/dev/null 2>&1; then
  echo "Updating dconf database..."
  dconf update || true
fi

echo "Successfully reversed build-gnome-extensions and purged leftover schemas."
