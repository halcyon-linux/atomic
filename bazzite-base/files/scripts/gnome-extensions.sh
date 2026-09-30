#!/usr/bin/env bash
# halcyon Step E — directory-installed GNOME extensions (prompt §5.1)
# (replaces the gnome-extensions module — §11 #1)
set -euo pipefail

echo "::group::gnome-extensions — GNOME shell extension + dconf cleanup"

# --- Remove directory-installed GNOME shell extensions ---
echo "--- Removing /usr/share/gnome-shell/extensions/ (non-RPM dirs §1.9b) ---"
if [ -d /usr/share/gnome-shell/extensions ]; then
  count=$(find /usr/share/gnome-shell/extensions -mindepth 1 -maxdepth 1 -type d | wc -l)
  echo "  INFO  ${count} extension dir(s) present — removing all"
  rm -rf /usr/share/gnome-shell/extensions
  echo "  REMOVED  /usr/share/gnome-shell/extensions/ (${count} dir(s))"
else
  echo "  SKIP  /usr/share/gnome-shell/extensions/ not present (already clean)"
fi

# --- Remove bazzite gschema/dconf overrides (upstream build-gnome-extensions residue) ---
echo "--- Removing bazzite gschema/dconf overrides ---"
removed=0
for f in \
  /usr/share/glib-2.0/schemas/zz0-03-bazzite-desktop-silverblue-extensions.gschema.override \
  /usr/share/ublue-os/dconfs/desktop-silverblue/zz0-03-bazzite-desktop-silverblue-extensions.gschema.override \
  /usr/share/ublue-os/dconfs/desktop-silverblue/10-bazzite-deck-silverblue-logomenu \
  /etc/dconf/db/distro.d/10-bazzite-deck-silverblue-logomenu \
  /usr/share/glib-2.0/schemas/*extensions*.gschema.override; do
  [ -e "${f}" ] || continue
  rm -f "${f}"
  echo "  REMOVED  ${f}"
  removed=$((removed + 1))
done
[ "${removed}" -eq 0 ] && echo "  SKIP  no bazzite gschema/dconf overrides found"

# --- Recompile glib schemas after removing extension overrides ---
echo "--- Recompiling GLib schemas ---"
if glib-compile-schemas /usr/share/glib-2.0/schemas 2>/dev/null; then
  echo "  OK    glib-compile-schemas succeeded"
else
  echo "  NOTE  glib-compile-schemas returned non-zero — non-fatal"
fi

# --- Remove bazzite/gnome dconf local.d overrides ---
echo "--- Removing bazzite/gnome dconf local.d overrides ---"
removed=0
for f in /etc/dconf/db/local.d/*bazzite* /etc/dconf/db/local.d/*gnome*; do
  [ -e "${f}" ] || continue
  rm -f "${f}"
  echo "  REMOVED  ${f}"
  removed=$((removed + 1))
done
[ "${removed}" -eq 0 ] && echo "  SKIP  no bazzite/gnome dconf local.d files found"

# --- Rebuild dconf database ---
echo "--- Rebuilding dconf database ---"
if [ -d /etc/dconf/db ]; then
  if dconf update 2>/dev/null; then
    echo "  OK    dconf database rebuilt"
  else
    echo "  NOTE  dconf update returned non-zero — non-fatal"
  fi
else
  echo "  SKIP  /etc/dconf/db/ absent — dconf update skipped"
fi

echo "--- gnome-extensions complete ---"
echo "::endgroup::"
