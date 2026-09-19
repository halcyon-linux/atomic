#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Obsidian from AppImage into /usr/lib/obsidian ==="
OBSIDIAN_TMP="$(mktemp -d)"
trap 'rm -rf "${OBSIDIAN_TMP}"' EXIT

cd "${OBSIDIAN_TMP}"

# Query GitHub API for the latest Obsidian AppImage URL, with fallback
APPIMAGE_URL="$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest 2>/dev/null |
  jq -r '.assets[] | select(.name | test("(?i)\\.appimage$")) | .browser_download_url' |
  head -n1 || true)"

if [ -z "${APPIMAGE_URL}" ] || [ "${APPIMAGE_URL}" = "null" ]; then
  # Fallback known release URL
  APPIMAGE_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.7/Obsidian-1.8.7.AppImage"
fi

echo "Downloading Obsidian AppImage from ${APPIMAGE_URL}..."
curl -fsSL "${APPIMAGE_URL}" -o obsidian.AppImage
chmod +x obsidian.AppImage

echo "Extracting AppImage contents..."
./obsidian.AppImage --appimage-extract

INSTALL_DIR="/usr/lib/obsidian"
mkdir -p "${INSTALL_DIR}"
cp -rf squashfs-root/* "${INSTALL_DIR}/"

# Link binary
ln -sf "${INSTALL_DIR}/obsidian" /usr/bin/obsidian

# Desktop entry integration
if [ -f "${INSTALL_DIR}/obsidian.desktop" ]; then
  install -Dm644 "${INSTALL_DIR}/obsidian.desktop" /usr/share/applications/obsidian.desktop
  sed -i 's|^Exec=.*|Exec=/usr/bin/obsidian %U|' /usr/share/applications/obsidian.desktop
  sed -i 's|^Icon=.*|Icon=obsidian|' /usr/share/applications/obsidian.desktop
fi

# Icon integration
for icon in "${INSTALL_DIR}"/usr/share/icons/hicolor/*/apps/obsidian.png "${INSTALL_DIR}/obsidian.png"; do
  if [ -f "${icon}" ]; then
    install -Dm644 "${icon}" /usr/share/icons/hicolor/512x512/apps/obsidian.png
    break
  fi
done

update-desktop-database /usr/share/applications &>/dev/null || true
gtk-update-icon-cache /usr/share/icons/hicolor &>/dev/null || true

echo "Obsidian successfully baked into /usr/lib/obsidian"
