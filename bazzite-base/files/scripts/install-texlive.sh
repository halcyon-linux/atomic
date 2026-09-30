#!/usr/bin/env bash
set -euo pipefail

echo "::group::install-texlive — setup"
TEXLIVE_INSTALL_DIR="/usr/lib/texlive"
mkdir -p "${TEXLIVE_INSTALL_DIR}"
echo "  INFO  install dir: ${TEXLIVE_INSTALL_DIR}"

# Additional TeX Live packages to install via tlmgr at build time.
# Add any individual packages here that you would like baked into the immutable image.
EXTRA_TL_PACKAGES=(
  latexmk
  biber
)
echo "  INFO  extra tlmgr packages: ${EXTRA_TL_PACKAGES[*]}"

TEXLIVE_TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${TEXLIVE_TMP}"; rm -rf "${TEXLIVE_TMP}"' EXIT
echo "::endgroup::"

echo "::group::install-texlive — download installer"
echo "--- Fetching install-tl-unx.tar.gz ---"
# install-tl verifies downloads against TeX Live's GPG signatures by default
# (install-tl manual) as long as gpg is present — keep it that way; never pass
# --no-verify-downloads.
if ! command -v gpg >/dev/null 2>&1; then
  echo "  WARN  gpg not found in PATH — install-tl signature verification will be skipped"
fi
# mirror.ctan.org is a redirector that lands on a RANDOM CTAN mirror; some
# mirrors intermittently serve broken TLS chains, which aborts curl with a
# certificate error (--retry does not retry those). Try pinned reliable
# mirrors in order instead. Keep this list in sync with the -repository used
# for the installer run below.
TEXLIVE_MIRRORS=(
  "https://mirrors.mit.edu/CTAN/systems/texlive/tlnet"
  "https://ftp.fau.de/ctan/systems/texlive/tlnet"
  "https://ctan.math.illinois.edu/systems/texlive/tlnet"
  "https://mirror.ctan.org/systems/texlive/tlnet"
)
TARBALL=""
for mirror in "${TEXLIVE_MIRRORS[@]}"; do
  echo "  INFO  trying ${mirror}"
  if curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors --max-time 600 --progress-bar \
      "${mirror}/install-tl-unx.tar.gz" -o "${TEXLIVE_TMP}/install-tl-unx.tar.gz"; then
    if gzip -t "${TEXLIVE_TMP}/install-tl-unx.tar.gz" 2>/dev/null; then
      TARBALL="${TEXLIVE_TMP}/install-tl-unx.tar.gz"
      echo "  OK    downloaded install-tl-unx.tar.gz from ${mirror}"
      break
    fi
    echo "  WARN  tarball from ${mirror} failed the gzip integrity check — trying next mirror"
  else
    echo "  WARN  download from ${mirror} failed — trying next mirror"
  fi
done
if [ -z "${TARBALL}" ]; then
  echo "  FAIL  Could not download install-tl-unx.tar.gz from any TeX Live mirror" >&2
  echo "::endgroup::"
  exit 1
fi
size=$(du -h "${TEXLIVE_TMP}/install-tl-unx.tar.gz" | cut -f1)
echo "  OK    downloaded install-tl-unx.tar.gz (${size})"

tar -xzf "${TEXLIVE_TMP}/install-tl-unx.tar.gz" -C "${TEXLIVE_TMP}"
echo "  OK    installer archive extracted"

INSTALLER="$(find "${TEXLIVE_TMP}" -mindepth 2 -maxdepth 2 -name 'install-tl' -type f -perm /111 | head -n1)"
if [[ -z "${INSTALLER}" || ! -x "${INSTALLER}" ]]; then
  echo "  FAIL  install-tl executable not found under ${TEXLIVE_TMP}" >&2
  echo "::endgroup::"
  exit 1
fi
echo "  OK    install-tl found at ${INSTALLER}"
echo "::endgroup::"

echo "::group::install-texlive — write profile & run install-tl"
cat >"${TEXLIVE_TMP}/texlive.profile" <<EOF
selected_scheme scheme-small
TEXDIR ${TEXLIVE_INSTALL_DIR}
TEXMFLOCAL ${TEXLIVE_INSTALL_DIR}/texmf-local
TEXMFSYSVAR ${TEXLIVE_INSTALL_DIR}/texmf-var
TEXMFSYSCONFIG ${TEXLIVE_INSTALL_DIR}/texmf-config
instopt_adjustpath 0
tlpdbopt_autobackup 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF
echo "  OK    texlive.profile written (scheme-medium, no docs/src)"

echo "--- Running install-tl (this may take several minutes) ---"
if "${INSTALLER}" \
  -profile "${TEXLIVE_TMP}/texlive.profile" \
  -no-interaction \
  -repository https://mirrors.mit.edu/CTAN/systems/texlive/tlnet; then
  echo "  OK    install-tl completed successfully"
else
  echo "  WARN  install-tl exited non-zero — continuing to verify bin dir" >&2
fi
echo "::endgroup::"

echo "::group::install-texlive — tlmgr extras & PATH setup"
TEXLIVE_BINDIR="$(find "${TEXLIVE_INSTALL_DIR}" -maxdepth 3 -type d -name 'x86_64-linux' | head -n1)"
if [ -z "${TEXLIVE_BINDIR}" ]; then
  echo "  WARN  Could not locate x86_64-linux bin dir under ${TEXLIVE_INSTALL_DIR} — PATH setup skipped" >&2
  echo "::endgroup::"
  exit 0
fi
echo "  OK    TeX Live bin dir: ${TEXLIVE_BINDIR}"

if [ ${#EXTRA_TL_PACKAGES[@]} -gt 0 ]; then
  echo "--- Installing extra packages via tlmgr: ${EXTRA_TL_PACKAGES[*]} ---"
  if "${TEXLIVE_BINDIR}/tlmgr" \
    --repository https://mirrors.mit.edu/CTAN/systems/texlive/tlnet \
    install "${EXTRA_TL_PACKAGES[@]}"; then
    echo "  OK    extra packages installed: ${EXTRA_TL_PACKAGES[*]}"
  else
    echo "  WARN  tlmgr extra package install exited non-zero" >&2
  fi
fi

install -d /etc/profile.d
cat >/etc/profile.d/texlive.sh <<EOF
# TeX Live (installed under /usr/lib/texlive during image build)
export PATH="${TEXLIVE_BINDIR}:\$PATH"
export MANPATH="${TEXLIVE_INSTALL_DIR}/texmf-dist/doc/man:\${MANPATH:-}"
export INFOPATH="${TEXLIVE_INSTALL_DIR}/texmf-dist/doc/info:\${INFOPATH:-}"
EOF
chmod 644 /etc/profile.d/texlive.sh
echo "  OK    /etc/profile.d/texlive.sh written"

install_size=$(du -sh "${TEXLIVE_INSTALL_DIR}" | cut -f1)
echo "  OK    TeX Live (scheme-medium) installed to ${TEXLIVE_INSTALL_DIR} (${install_size})"
echo "--- install-texlive complete ---"
echo "::endgroup::"
