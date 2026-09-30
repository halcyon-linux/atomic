#!/usr/bin/env bash
# halcyon — build the real Plymouth theme assets from the baked astronaut
# wallpaper (branding.yml, runs before branding-verify.sh). The two-step
# plugin degrades to solid colors when files are missing, which is why the
# theme used to render blank; this generates everything it loads:
#   background.png          — wallpaper, cropped 1920x1080, darkened + blurred
#   throbber-0001..0030.png — 30 rotating-arc spinner frames (128px, alpha)
#   entry.png etc.          — password-entry widgets copied from the stock
#                             spinner theme (plymouth-theme-spinner is a core.yml
#                             install); without them the password box is invisible
# Then selects the theme via /etc/plymouth/plymouthd.conf (written directly —
# `plymouth-set-default-theme` would also try to rebuild the initrd, which is
# the initramfs module's job in this build).
set -euo pipefail

THEME_DIR=/usr/share/plymouth/themes/halcyon
WALLPAPER=/usr/share/backgrounds/halcyon/astronaut.png
SPINNER=/usr/share/plymouth/themes/spinner
FRAMES=30

echo "::group::build-plymouth-assets — inputs"
for f in "${WALLPAPER}" "${THEME_DIR}/theme.plymouth"; do
  if [ ! -f "${f}" ]; then
    echo "  FAIL  ${f} missing" >&2
    echo "::endgroup::"
    exit 1
  fi
done
if ! command -v magick >/dev/null 2>&1; then
  echo "  FAIL  ImageMagick (magick) not available — core.yml must install it first" >&2
  echo "::endgroup::"
  exit 1
fi
echo "  OK    inputs present (wallpaper + theme.plymouth + magick)"
echo "::endgroup::"

echo "::group::build-plymouth-assets — background.png"
magick "${WALLPAPER}" \
  -resize 1920x1080^ -gravity center -extent 1920x1080 \
  -modulate 55,65 -gaussian-blur 0x5 -depth 8 \
  "${THEME_DIR}/background.png"
echo "  OK    background.png generated ($(du -h "${THEME_DIR}/background.png" | cut -f1))"
echo "::endgroup::"

echo "::group::build-plymouth-assets — throbber frames (${FRAMES})"
for i in $(seq 0 $((FRAMES - 1))); do
  start=$((i * 360 / FRAMES))
  end=$((start + 130))
  frame=$(printf 'throbber-%04d.png' $((i + 1)))
  magick -size 128x128 xc:none \
    -stroke 'srgb(122,150,255)' -strokewidth 9 \
    -draw "arc 14,14 114,114 ${start},${end}" -depth 8 \
    "${THEME_DIR}/${frame}"
done
throbber_count=$(find "${THEME_DIR}" -name 'throbber-*.png' | wc -l)
if [ "${throbber_count}" -ne "${FRAMES}" ]; then
  echo "  FAIL  expected ${FRAMES} throbber frames, found ${throbber_count}" >&2
  echo "::endgroup::"
  exit 1
fi
echo "  OK    ${throbber_count} throbber frames generated"
echo "::endgroup::"

echo "::group::build-plymouth-assets — entry widgets from stock spinner theme"
copied=0
for f in entry.png entry-nolock.png lock.png keyboard.png bullet.png capslock.png; do
  if [ -f "${SPINNER}/${f}" ]; then
    cp "${SPINNER}/${f}" "${THEME_DIR}/${f}"
    copied=$((copied + 1))
  fi
done
if [ "${copied}" -eq 0 ]; then
  echo "  WARN  no spinner entry widgets found at ${SPINNER} — password box may render blank" >&2
else
  echo "  OK    ${copied} entry widget(s) copied from the stock spinner theme"
fi
echo "::endgroup::"

echo "::group::build-plymouth-assets — select theme"
install -d /etc/plymouth
cat >/etc/plymouth/plymouthd.conf <<'EOF'
# Created by build-plymouth-assets.sh (build time). The initramfs module
# regenerates the initrd after this, so the theme is active at boot.
[Daemon]
Theme=halcyon
EOF
echo "  OK    /etc/plymouth/plymouthd.conf → Theme=halcyon"
echo "::endgroup::"

echo "--- build-plymouth-assets complete ---"
