#!/usr/bin/env bash
# halcyon branding.yml verification (prompt §5.11)
set -euo pipefail

echo "::group::branding-verify — OS identity & theming checks"

# --- OS release name ---
echo "--- Checking /etc/os-release identity ---"
pretty=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"' || true)
if echo "${pretty}" | grep -qi 'halcyon'; then
  echo "  PASS  PRETTY_NAME=\"${pretty}\""
else
  echo "  FAIL  PRETTY_NAME does not contain 'halcyon' — got: \"${pretty}\""
  echo "::endgroup::"
  exit 1
fi

# --- Plymouth theme ---
echo "--- Checking Plymouth theme ---"
# build-plymouth-assets.sh (earlier in this module) generated the assets and
# selected the theme via /etc/plymouth/plymouthd.conf; the initramfs module
# (after branding.yml) regenerates the initrd. Verify the results here.
if [ -f /etc/plymouth/plymouthd.conf ] && grep -q '^Theme=halcyon' /etc/plymouth/plymouthd.conf; then
  echo "  PASS  plymouthd.conf selects Theme=halcyon"
else
  echo "  FAIL  /etc/plymouth/plymouthd.conf does not select Theme=halcyon"
  echo "::endgroup::"
  exit 1
fi
missing_assets=()
if [ -s /usr/share/plymouth/themes/halcyon/background.png ]; then
  echo "  PASS  background.png present"
else
  missing_assets+=("background.png")
fi
throbbers=$(find /usr/share/plymouth/themes/halcyon -name 'throbber-*.png' 2>/dev/null | wc -l)
if [ "${throbbers}" -ge 24 ]; then
  echo "  PASS  throbber frames present (${throbbers})"
else
  missing_assets+=("throbber frames (${throbbers}/24+)")
fi
if [ -f /usr/share/plymouth/themes/halcyon/entry.png ]; then
  echo "  PASS  entry.png present (password box will render)"
else
  echo "  WARN  entry.png missing — password box may render blank (spinner theme absent?)"
fi
if [ "${#missing_assets[@]}" -eq 0 ]; then
  echo "  PASS  all required theme assets generated"
else
  echo "  FAIL  missing Plymouth assets: ${missing_assets[*]}"
  echo "::endgroup::"
  exit 1
fi

# --- MOTD ---
echo "--- Checking MOTD ---"
if test -f /etc/motd.d/motd.txt; then
  lines=$(wc -l < /etc/motd.d/motd.txt)
  echo "  PASS  /etc/motd.d/motd.txt present (${lines} lines)"
else
  echo "  FAIL  /etc/motd.d/motd.txt missing"
  echo "::endgroup::"
  exit 1
fi

# --- Backgrounds ---
echo "--- Checking halcyon backgrounds directory ---"
if test -d /usr/share/backgrounds/halcyon; then
  count=$(find /usr/share/backgrounds/halcyon -maxdepth 1 -type f | wc -l)
  echo "  PASS  /usr/share/backgrounds/halcyon/ present (${count} file(s))"
else
  echo "  FAIL  /usr/share/backgrounds/halcyon/ missing"
  echo "::endgroup::"
  exit 1
fi

echo "--- branding-verify complete — all checks passed ---"
echo "::endgroup::"
