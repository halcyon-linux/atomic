#!/usr/bin/env bash
set -euo pipefail

echo "::group::install-zotero — download & extract"
ZOTERO_INSTALL_DIR="/usr/lib/zotero"
ZOTERO_TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${ZOTERO_TMP}"; rm -rf "${ZOTERO_TMP}"' EXIT

echo "--- Downloading Zotero Linux x86_64 tarball ---"
# Integrity note: Zotero deliberately publishes no checksum files (upstream
# position: TLS-protected downloads + the archive's internal gzip checksum
# suffice — forums.zotero.org discussion 70280). Accepted risk: the download
# below is TLS-authenticated to www.zotero.org and nothing else.
DOWNLOAD_URL='https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64'
echo "  INFO  URL: ${DOWNLOAD_URL}"

if ! curl -fsSL --progress-bar "${DOWNLOAD_URL}" -o "${ZOTERO_TMP}/zotero.tar.archive"; then
  echo "  FAIL  Failed to download Zotero tarball" >&2
  echo "::endgroup::"
  exit 1
fi
size=$(du -h "${ZOTERO_TMP}/zotero.tar.archive" | cut -f1)
echo "  OK    downloaded zotero.tar.archive (${size})"

echo "--- Extracting to ${ZOTERO_INSTALL_DIR} ---"
mkdir -p "${ZOTERO_INSTALL_DIR}"
tar -xf "${ZOTERO_TMP}/zotero.tar.archive" -C "${ZOTERO_INSTALL_DIR}" --strip-components=1
install_size=$(du -sh "${ZOTERO_INSTALL_DIR}" | cut -f1)
echo "  OK    extracted to ${ZOTERO_INSTALL_DIR} (${install_size})"
echo "::endgroup::"

echo "::group::install-zotero — launcher icon & desktop entry"
echo "--- Setting launcher icon ---"
if "${ZOTERO_INSTALL_DIR}/set_launcher_icon" 2>/dev/null; then
  echo "  OK    set_launcher_icon succeeded"
else
  echo "  NOTE  set_launcher_icon returned non-zero — non-fatal"
fi

echo "--- Installing desktop entry ---"
if [ -f "${ZOTERO_INSTALL_DIR}/zotero.desktop" ]; then
  install -Dm644 "${ZOTERO_INSTALL_DIR}/zotero.desktop" /usr/share/applications/zotero.desktop
  echo "  OK    /usr/share/applications/zotero.desktop installed"
else
  echo "  WARN  zotero.desktop not found in install dir — skipping"
fi

echo "--- Creating /usr/bin/zotero symlink ---"
ln -sf "${ZOTERO_INSTALL_DIR}/zotero" /usr/bin/zotero
echo "  OK    /usr/bin/zotero → ${ZOTERO_INSTALL_DIR}/zotero"
echo "::endgroup::"

echo "::group::install-zotero — distribution policies"
echo "--- Writing DisableAppUpdate policy ---"
install -d "${ZOTERO_INSTALL_DIR}/distribution"
cat >"${ZOTERO_INSTALL_DIR}/distribution/policies.json" <<'POLICY'
{
  "policies": {
    "DisableAppUpdate": true
  }
}
POLICY
echo "  OK    ${ZOTERO_INSTALL_DIR}/distribution/policies.json written (DisableAppUpdate: true)"
echo "--- install-zotero complete ---"
echo "::endgroup::"
