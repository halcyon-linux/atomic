#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Pyprland from GitHub Releases into /usr/lib/pyprland ==="

PYPR_TMP="$(mktemp -d)"
trap 'rm -rf "${PYPR_TMP}"' EXIT

cd "${PYPR_TMP}"

# Query GitHub API for latest release tag with fallback
LATEST_TAG="$(curl -fsSL https://api.github.com/repos/hyprland-community/pyprland/releases/latest 2>/dev/null | jq -r '.tag_name // empty' || true)"

if [ -z "${LATEST_TAG}" ] || [ "${LATEST_TAG}" = "null" ]; then
  LATEST_TAG="3.4.4"
  echo "GitHub API unavailable or rate-limited; using fallback version ${LATEST_TAG}."
else
  echo "Resolved latest Pyprland release: ${LATEST_TAG}"
fi

TARBALL_URL="https://github.com/hyprland-community/pyprland/archive/refs/tags/${LATEST_TAG}.tar.gz"
echo "Downloading Pyprland source from ${TARBALL_URL}..."
curl -fsSL "${TARBALL_URL}" -o pyprland.tar.gz

tar -xzf pyprland.tar.gz
cd "pyprland-${LATEST_TAG}"

# Create isolated Python virtualenv in /usr/lib/pyprland
INSTALL_DIR="/usr/lib/pyprland"
rm -rf "${INSTALL_DIR}"
python3 -m venv "${INSTALL_DIR}"

"${INSTALL_DIR}/bin/pip" install --no-cache-dir --upgrade pip setuptools wheel hatchling
"${INSTALL_DIR}/bin/pip" install --no-cache-dir .

# Compile fast C client if gcc is available
if [ -f "client/pypr-client.c" ] && command -v gcc &>/dev/null; then
  echo "Compiling pypr-client C helper..."
  gcc -O3 client/pypr-client.c -o /usr/bin/pypr-client || true
fi

# Link pypr CLI binaries to /usr/bin
ln -sf "${INSTALL_DIR}/bin/pypr" /usr/bin/pypr
ln -sf "${INSTALL_DIR}/bin/pypr-quickstart" /usr/bin/pypr-quickstart
[ -f "${INSTALL_DIR}/bin/pypr-gui" ] && ln -sf "${INSTALL_DIR}/bin/pypr-gui" /usr/bin/pypr-gui

# Install systemd user service
mkdir -p /usr/lib/systemd/user
if [ -f "systemd-unit/pyprland.service" ]; then
  install -Dm644 "systemd-unit/pyprland.service" /usr/lib/systemd/user/pyprland.service
else
  cat > /usr/lib/systemd/user/pyprland.service <<'EOF'
[Unit]
Description=Starts pyprland daemon
After=graphical-session.target
Wants=graphical-session.target
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=simple
ExecStartPre=/bin/sh -c '[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ] || exit 0'
ExecStart=/usr/bin/pypr
Restart=always
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF
fi

echo "Pyprland ${LATEST_TAG} successfully installed to ${INSTALL_DIR} and linked to /usr/bin/pypr."
