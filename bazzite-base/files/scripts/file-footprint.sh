#!/usr/bin/env bash
# halcyon Step D — file footprint + service/justfile pruning (prompt §5.1)
set -uo pipefail

echo "::group::file-footprint — Waydroid set removal (§1.12)"
echo "--- Removing Waydroid files ---"
waydroid_files=(
  /etc/default/waydroid-launcher
  /usr/bin/waydroid-launcher
  /usr/bin/waydroid-choose-gpu
  /usr/libexec/waydroid-container-start
  /usr/libexec/waydroid-container-stop
  /usr/libexec/waydroid-container-restart
  /usr/libexec/waydroid-fix-controllers
  /usr/share/applications/waydroid-container-restart.desktop
  /usr/share/polkit-1/actions/org.bazzite.waydroid.policy
  /usr/share/polkit-1/rules.d/30-waydroid.rules
  /usr/share/applications/Waydroid.desktop
  /usr/share/applications/Waydroid-create.desktop
  /usr/share/applications/Waydroid-info.desktop
)
removed=0
for f in "${waydroid_files[@]}"; do
  if [ -e "${f}" ]; then
    rm -f "${f}"
    echo "  REMOVED  ${f}"
    removed=$((removed + 1))
  fi
done
if [ -d /usr/share/applications/waydroid ]; then
  rm -rf /usr/share/applications/waydroid
  echo "  REMOVED  /usr/share/applications/waydroid/ (directory)"
  removed=$((removed + 1))
fi
echo "  OK    ${removed} Waydroid item(s) removed"
echo "::endgroup::"

echo "::group::file-footprint — Bling set removal (§1.6)"
echo "--- Removing bazzite-bling / neofetch files ---"
bling_files=(
  /usr/libexec/bazzite-bling-fastfetch
  /usr/share/ublue-os/bazzite/fastfetch.jsonc
  /usr/share/bazzite-cli/bling.sh
  /usr/share/bazzite-cli/bling.fish
  /etc/profile.d/bazzite-neofetch.sh
)
removed=0
for f in "${bling_files[@]}"; do
  if [ -e "${f}" ]; then
    rm -f "${f}"
    echo "  REMOVED  ${f}"
    removed=$((removed + 1))
  fi
done
echo "  OK    ${removed} bling item(s) removed"
echo "::endgroup::"

echo "::group::file-footprint — bazzite-cli recipe excision from 80-bazzite.just"
JUSTFILE=/usr/share/ublue-os/just/80-bazzite.just
if [ -f "${JUSTFILE}" ] && grep -q 'Enable a Bluefin-style CLI experience' "${JUSTFILE}"; then
  echo "  INFO  bazzite-cli recipe found in ${JUSTFILE} — excising..."
  awk '
    /^# Enable a Bluefin-style CLI experience/ {skip=1; groups=0; body=0}
    skip {
      if ($0 ~ /^\[group\(/) {
        groups++
        if (body > 0 || groups >= 2) { skip=0; print; next }
        next
      }
      if ($0 !~ /^#/ && $0 !~ /^[[:space:]]*$/) body++
      next
    }
    {print}
  ' "${JUSTFILE}" >"${JUSTFILE}.new"
  mv "${JUSTFILE}.new" "${JUSTFILE}"
  echo "  PASS  bazzite-cli recipe excised from 80-bazzite.just"
else
  echo "  SKIP  bazzite-cli recipe not present in ${JUSTFILE} (already clean or file absent)"
fi
echo "::endgroup::"

echo "::group::file-footprint — GNOME config footprint removal (§1.9)"
echo "--- Removing bazzite GNOME dconf/gschema/background files ---"
gnome_files=(
  /etc/dconf/db/distro.d/00-bazzite-desktop-silverblue-global
  /etc/dconf/db/distro.d/01-bazzite-desktop-silverblue-folders
  /etc/dconf/db/distro.d/locks/00-bazzite-desktop-silverblue-global-lock
  /usr/share/backgrounds/default.jxl
  /usr/share/backgrounds/default-dark.jxl
  /usr/lib/systemd/system/dconf-update.service
  /usr/share/ublue-os/motd/tips/30-gnome.md
  /usr/share/applications/gnome-ssh-askpass.desktop
  /usr/share/ublue-os/firefox-config/03-bazzite-gnome.js
  /etc/skel/.config/gnome-initial-setup-done
)
removed=0
for f in "${gnome_files[@]}"; do
  if [ -e "${f}" ]; then
    rm -f "${f}"
    echo "  REMOVED  ${f}"
    removed=$((removed + 1))
  fi
done
# gschema overrides (broader pattern — NOTES.md §5: build 12 revealed 6th variant)
gschema_count=0
for f in /usr/share/glib-2.0/schemas/*bazzite*-silverblue-*.gschema.override; do
  [ -e "${f}" ] || continue
  rm -f "${f}"
  echo "  REMOVED  ${f}"
  gschema_count=$((gschema_count + 1))
done
[ "${gschema_count}" -gt 0 ] && echo "  OK    ${gschema_count} bazzite gschema override(s) removed"

if [ -d /usr/share/gnome-background-properties ]; then
  rm -rf /usr/share/gnome-background-properties
  echo "  REMOVED  /usr/share/gnome-background-properties/ (directory)"
  removed=$((removed + 1))
fi
if [ -d /etc/skel/.local/share/org.gnome.Ptyxis ]; then
  rm -rf /etc/skel/.local/share/org.gnome.Ptyxis
  echo "  REMOVED  /etc/skel/.local/share/org.gnome.Ptyxis/ (directory)"
  removed=$((removed + 1))
fi
echo "  OK    ${removed} GNOME file(s) removed (+ ${gschema_count} gschema override(s))"

echo "--- Cleaning GNOME entries from /etc/xdg/mimeapps.list ---"
if [ -f /etc/xdg/mimeapps.list ]; then
  sed -i '/org\.gnome\./d' /etc/xdg/mimeapps.list || true
  echo "  OK    removed org.gnome.* entries from mimeapps.list"
else
  echo "  SKIP  /etc/xdg/mimeapps.list not present"
fi
echo "::endgroup::"

echo "::group::file-footprint — SDDM/autologin cleanup"
if [ -d /etc/sddm.conf.d ]; then
  rm -rf /etc/sddm.conf.d
  echo "  REMOVED  /etc/sddm.conf.d/ (directory)"
else
  echo "  SKIP  /etc/sddm.conf.d not present"
fi
echo "::endgroup::"

echo "::group::file-footprint — dangling service disable"
echo "--- Disabling system services ---"
system_services=(
  inputplumber.service
  powerstation.service
  jupiter-fan-control.service
  vpower.service
  jupiter-biosupdate.service
  jupiter-controller-update.service
  sdgyrodsu.service
  waydroid-container.service
  bazzite-autologin.service
  dconf-update.service
)
for svc in "${system_services[@]}"; do
  if systemctl disable "${svc}" 2>/dev/null; then
    echo "  DISABLED  ${svc}"
  else
    echo "  SKIP  ${svc} (not enabled or not found)"
  fi
done

echo "--- Disabling global user services ---"
for svc in sdgyrodsu.service steamos-powerbuttond.service; do
  if systemctl --global disable "${svc}" 2>/dev/null; then
    echo "  DISABLED  ${svc} (global)"
  else
    echo "  SKIP  ${svc} (global) — not enabled or not found"
  fi
done

echo "--- Removing steamos-powerbuttond wants symlink ---"
f=/usr/lib/systemd/user/gamescope-session-plus@ogui-steam.service.wants/steamos-powerbuttond.service
if [ -L "${f}" ] || [ -f "${f}" ]; then
  rm -f "${f}"
  echo "  REMOVED  ${f}"
else
  echo "  SKIP  ${f} not present"
fi

echo "--- Pruning dangling .wants symlinks ---"
dangling=$(find /etc/systemd /usr/lib/systemd -name '*.wants' -type d -exec find {} -xtype l -print \; 2>/dev/null || true)
if [ -n "${dangling}" ]; then
  count=$(echo "${dangling}" | wc -l)
  echo "${dangling}" | while read -r link; do
    rm -f "${link}"
    echo "  REMOVED  dangling symlink: ${link}"
  done
  echo "  OK    ${count} dangling .wants symlink(s) pruned"
else
  echo "  OK    no dangling .wants symlinks found"
fi
echo "::endgroup::"

echo "::group::file-footprint — justfile pruning"
echo "--- Removing subsystem justfiles and import lines ---"
UBLUE_JUST=/usr/share/ublue-os/just
for jf in 82-bazzite-waydroid.just 91-bazzite-decky.just 95-bazzite-deck-session.just 90-bazzite-de.just; do
  target="${UBLUE_JUST}/${jf}"
  if [ -f "${target}" ]; then
    rm -f "${target}"
    echo "  REMOVED  ${target}"
  else
    echo "  SKIP  ${target} not present"
  fi
  if [ -f /usr/share/ublue-os/justfile ]; then
    if grep -q "${jf}" /usr/share/ublue-os/justfile; then
      sed -i "\|${jf}|d" /usr/share/ublue-os/justfile
      echo "  REMOVED  import line for ${jf} from justfile"
    fi
  fi
done

deck_count=0
for f in "${UBLUE_JUST}"/*deck-variant*.just; do
  [ -f "${f}" ] || continue
  rm -f "${f}"
  echo "  REMOVED  ${f}"
  deck_count=$((deck_count + 1))
done
[ "${deck_count}" -eq 0 ] && echo "  SKIP  no *deck-variant*.just files found"

echo "--- Reporting recipes referencing removed subsystems (non-fatal) ---"
# KEEP: 82-bazzite-apps.just / 94-bazzite-protonplus.just / 95-bazzite-nvidia.just
stale=$(grep -l 'gnome-shell\|gdm\|sddm\|waydroid\|decky' "${UBLUE_JUST}"/*.just 2>/dev/null || true)
if [ -n "${stale}" ]; then
  echo "  WARN  the following justfiles still reference removed subsystems (manual follow-up):"
  echo "${stale}" | while read -r f; do
    echo "          ${f}"
    echo "${f}" >> /tmp/halcyon-inventory.txt
  done
else
  echo "  OK    no justfiles reference removed subsystems"
fi
echo "::endgroup::"

echo "::group::file-footprint — steamos-manager desktop target fix"
PLATFORM_TOML=/usr/share/steamos-manager/platform.toml
if [ -f "${PLATFORM_TOML}" ] && grep -q 'desktop = "gnome.desktop"' "${PLATFORM_TOML}"; then
  sed -i 's/desktop = "gnome.desktop"/desktop = "hyprland.desktop"/' "${PLATFORM_TOML}"
  echo "  PATCHED  ${PLATFORM_TOML}: gnome.desktop → hyprland.desktop"
else
  echo "  SKIP  ${PLATFORM_TOML} not present or already patched"
fi
echo "::endgroup::"

echo "::group::file-footprint — default shell fix"
echo "--- Ensuring SHELL=/bin/bash in /etc/default/useradd ---"
if grep -q '^SHELL=/bin/bash' /etc/default/useradd; then
  echo "  OK    SHELL already set to /bin/bash"
else
  sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd
  new_val=$(grep '^SHELL=' /etc/default/useradd)
  echo "  PATCHED  /etc/default/useradd → ${new_val}"
fi
echo "::endgroup::"

echo "--- file-footprint complete ---"
exit 0
