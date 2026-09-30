#!/usr/bin/env bash
# halcyon brew.yml verification — install-brew-bundle.sh runs first in the
# same module, so the payload it bakes must already exist here.
set -euo pipefail

echo "::group::brew-verify — base brew payload"
BREW_TARBALL=/usr/share/homebrew.tar.zst
if test -f "${BREW_TARBALL}"; then
  size=$(du -h "${BREW_TARBALL}" | cut -f1)
  echo "  PASS  ${BREW_TARBALL} present (${size})"
else
  echo "  FAIL  ${BREW_TARBALL} missing — brew.yml base payload not installed"
  echo "::endgroup::"
  exit 1
fi
echo "::endgroup::"

echo "::group::brew-verify — baked bundle payload"
PAYLOAD=/usr/share/halcyon/brew-bundle.tar.zst
BREWFILE=/usr/share/ublue-os/homebrew/Brewfile

echo "--- Checking Brewfile ---"
if test -f "${BREWFILE}"; then
  formula_count=$(grep -cE '^[[:space:]]*brew "?[^" ]+"?' "${BREWFILE}" || true)
  echo "  PASS  ${BREWFILE} present (${formula_count} formulas)"
else
  echo "  FAIL  ${BREWFILE} missing — brew.yml files module did not stage it"
  echo "::endgroup::"
  exit 1
fi

echo "--- Checking baked payload ---"
PAYLIST="$(mktemp)"
trap 'rm -f "${PAYLIST}"' EXIT
if test -f "${PAYLOAD}"; then
  tar --zstd -tf "${PAYLOAD}" >"${PAYLIST}"
  size=$(du -h "${PAYLOAD}" | cut -f1)
  entries=$(wc -l <"${PAYLIST}")
  echo "  PASS  ${PAYLOAD} present (${size}, ${entries} entries)"
else
  echo "  FAIL  ${PAYLOAD} missing — install-brew-bundle.sh did not run/bake"
  echo "::endgroup::"
  exit 1
fi

echo "--- Checking every Brewfile formula is inside the payload ---"
# "Inside" means a COMPLETE pour: Cellar/<name>/<version>/INSTALL_RECEIPT.json.
# NOTE: use grep -c (no -q, no early exit) for the two-stage match — a
# `grep | grep -q` pipeline under pipefail can fail with SIGPIPE (141) when
# the upstream grep is still emitting later matches after the -q grep has
# already found its first match and exited. That false negative is exactly
# what failed the CI run for btop/chafa/gnuplot.
missing=0
while IFS= read -r name; do
  [ -z "${name}" ] && continue
  receipts=$(grep -F "Cellar/${name}/" "${PAYLIST}" 2>/dev/null | grep -cF "INSTALL_RECEIPT.json" || true)
  if [ "${receipts}" -gt 0 ]; then
    echo "  PASS  payload contains a complete pour of Cellar/${name} (${receipts} receipt(s))"
  else
    echo "  FAIL  Cellar/${name} not found (complete) in payload — payload entries for it:"
    grep -F "Cellar/${name}/" "${PAYLIST}" 2>/dev/null | head -5 | sed 's/^/        /' || true
    missing=$((missing + 1))
  fi
# Cellar dirs are named by formula only — strip any "tap/" prefix and
# tolerate quoted or unquoted entries, so new Brewfile lines of any
# common style are picked up automatically.
done < <(sed -nE 's/^[[:space:]]*brew "?([^" ]+)"?.*/\1/p' "${BREWFILE}" | sed 's|^.*/||')
if [ "${missing}" -gt 0 ]; then
  echo "  FAIL  ${missing} formula(s) missing from the payload"
  echo "::endgroup::"
  exit 1
fi

echo "--- Checking the populated prefix did NOT ship as /var state ---"
if test -e /home/linuxbrew; then
  echo "  FAIL  /home/linuxbrew present in the layer — payload must ride in /usr only"
  echo "::endgroup::"
  exit 1
else
  echo "  PASS  no /home/linuxbrew in the layer (boot-time extraction provides it)"
fi
if test -e /var/home/linuxbrew; then
  echo "  FAIL  /var/home/linuxbrew present in the layer — /var must stay clean"
  echo "::endgroup::"
  exit 1
else
  echo "  PASS  no /var/home/linuxbrew in the layer"
fi
echo "::endgroup::"

if test -f /usr/lib/systemd/user/brew-bundle.service; then
  echo "  PASS  user fallback unit brew-bundle.service present"
else
  echo "  FAIL  /usr/lib/systemd/user/brew-bundle.service missing"
  echo "::endgroup::"
  exit 1
fi
echo "::endgroup::"

# NOTE: the libexec helpers (brew-bundle-extract/brew-bundle-install) and the
# systemd unit wiring are verified in files-verify.sh — they are copied by
# modules that run AFTER this one (files.yml's tree copy), mirroring the
# ordering-aware split this module has always documented.
echo "--- brew-verify complete ---"
