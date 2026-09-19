#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Zotero to /usr/lib/zotero ==="
ZOTERO_INSTALL_DIR="/usr/lib/zotero"
ZOTERO_TMP="$(mktemp -d)"
trap 'rm -rf "${ZOTERO_TMP}"' EXIT

if curl -fsSL 'https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64' -o "${ZOTERO_TMP}/zotero.tar.archive"; then
  mkdir -p "${ZOTERO_INSTALL_DIR}"
  tar -xf "${ZOTERO_TMP}/zotero.tar.archive" -C "${ZOTERO_INSTALL_DIR}" --strip-components=1
  "${ZOTERO_INSTALL_DIR}/set_launcher_icon" || true
  if [ -f "${ZOTERO_INSTALL_DIR}/zotero.desktop" ]; then
    install -Dm644 "${ZOTERO_INSTALL_DIR}/zotero.desktop" /usr/share/applications/zotero.desktop
  fi
  ln -sf "${ZOTERO_INSTALL_DIR}/zotero" /usr/bin/zotero
  install -d "${ZOTERO_INSTALL_DIR}/distribution"
  cat >"${ZOTERO_INSTALL_DIR}/distribution/policies.json" <<'EOF'
{
  "policies": {
    "DisableAppUpdate": true
  }
}
EOF
  echo "Zotero successfully installed to ${ZOTERO_INSTALL_DIR}"
else
  echo "WARNING: Failed to download Zotero tarball" >&2
fi
