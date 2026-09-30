#!/usr/bin/env bash
# brew.yml — install-brew-bundle.sh
# Bakes the Brewfile's Homebrew formulas into an image payload so they are
# available immediately after login on EVERY deployment path (fresh install
# or rebase): at build time we stage the base's brew tarball, run
# `brew bundle` as a throwaway non-root uid, and repack the populated
# prefix to /usr/share/halcyon/brew-bundle.tar.zst.
# halcyon-brew-bundle.service extracts that payload at boot — pre-login
# and offline; the brew-bundle.service user unit remains as an online
# catch-up fallback at login.
#
# Why repack instead of shipping /var/home/linuxbrew in the layer: /var is
# runtime state — bootc seeds it from the image only on first provisioning,
# never when rebasing an existing system. A /usr payload + boot extraction
# works everywhere, exactly like the base's own homebrew.tar.zst +
# brew-setup.service mechanism.
set -euo pipefail

BREWFILE="/usr/share/ublue-os/homebrew/Brewfile"
BASE_TARBALL="/usr/share/homebrew.tar.zst"
PAYLOAD="/usr/share/halcyon/brew-bundle.tar.zst"
PREFIX="/home/linuxbrew/.linuxbrew"
# Throwaway uid for running brew (it refuses root). The prefix is chowned
# to 1000:1000 before repack, matching brew-setup.service's ownership.
BREW_UID=9000
BREW_HOME="/var/tmp/brew-build-home"
MAX_ATTEMPTS=3
RETRY_DELAY=20

# /var/tmp hosts transient staging dirs; the built image strips /var, so
# guarantee it exists with the canonical sticky mode (1777, matching the
# base and tmp.conf) before anything stages under it.
install -d -m 1777 /var/tmp

echo "::group::install-brew-bundle — payload inputs"
if [ ! -f "${BREWFILE}" ]; then
  echo "  FAIL  ${BREWFILE} missing — brew.yml files module did not stage it"
  echo "::endgroup::"
  exit 1
fi
formula_count=$(grep -cE '^[[:space:]]*brew "?[^" ]+"?' "${BREWFILE}" || true)
echo "  OK    ${BREWFILE} present (${formula_count} formulas)"

# Casks are a macOS concept — on Linux they do not install, and a cask
# entry would otherwise be baked into the payload unverified. Fail loudly
# so the Brewfile stays formulas-only.
if grep -qE '^[[:space:]]*cask "' "${BREWFILE}"; then
  echo "  FAIL  ${BREWFILE} contains cask entries — casks are unsupported on Linux; use formulas only"
  echo "::endgroup::"
  exit 1
fi

if [ ! -f "${BASE_TARBALL}" ]; then
  echo "  FAIL  ${BASE_TARBALL} missing — base brew payload not in image"
  echo "::endgroup::"
  exit 1
fi
echo "  OK    ${BASE_TARBALL} present ($(du -h "${BASE_TARBALL}" | cut -f1))"
echo "::endgroup::"

echo "::group::install-brew-bundle — stage base brew prefix"
# The bundle MUST run with the prefix at its final runtime path
# /home/linuxbrew/.linuxbrew: bottles are relocated at install time to
# whatever prefix they are poured into, so installing into a scratch path
# and moving the tree would bake broken paths into every formula
# (docs.brew.sh/Manpage — bottle relocation). The build container's /home
# is a symlink to var/home with NO /var/home behind it (dangling), so
# /var/home is created here if missing — and removed again after repack:
# the layer must not ship /var state (bootc seeds /var from the initial
# image only; bootc.dev/bootc/filesystem.html).
CREATED_VAR_HOME=0
if [ ! -d /var/home ]; then
  mkdir -p /var/home
  CREATED_VAR_HOME=1
  echo "  INFO  created /var/home (missing in the build container — /home symlink was dangling)"
fi
echo "--- Staging exactly as brew-setup.service does at first boot ---"
rm -rf /home/linuxbrew /tmp/hbrew-stage
mkdir -p /tmp/hbrew-stage /home/linuxbrew
tar --zstd -xf "${BASE_TARBALL}" -C /tmp/hbrew-stage
cp -R -n /tmp/hbrew-stage/home/linuxbrew/.linuxbrew /home/linuxbrew
rm -rf /tmp/hbrew-stage
echo "  OK    prefix staged at ${PREFIX} (final runtime path — correct bottle relocation)"

chown -R "${BREW_UID}:${BREW_UID}" /home/linuxbrew
mkdir -p "${BREW_HOME}"
chown -R "${BREW_UID}:${BREW_UID}" "${BREW_HOME}"
echo "  OK    prefix + HOME owned by uid ${BREW_UID} for the bundle run"
echo "::endgroup::"

echo "::group::install-brew-bundle — brew bundle (network, with retries)"
# HOMEBREW_NO_AUTO_UPDATE=1 is REQUIRED here, not an optimization: with
# auto-update enabled, brew self-updates the CLI in place before pouring
# (6.0.22 from the tarball -> whatever master-adjacent state GitHub serves).
# That mid-run CLI swap made pours nondeterministic — a CI build poured all
# 22 formulas yet the payload lacked INSTALL_RECEIPT.json for 3 of them
# (btop, chafa, gnuplot), and a local reproduction crashed outright on the
# self-updated CLI. Pinned to the tarball's known-good brew, pours are
# deterministic and receipts always land in the Cellar; formula versions
# lag the tarball by design and are converged on the installed system by
# the base's brew-upgrade.timer.
# Primary invocation is the Homebrew 5.2+/6+ CLI (`install` subcommand,
# Brewfile via HOMEBREW_BUNDLE_FILE — both documented by `brew bundle`).
# If it fails, the legacy pre-6 form is tried once before the attempt
# counts as failed — a guard against CLI interface churn. Output streams
# to console AND a log file (PIPESTATUS preserves brew's exit code through
# the tee; set +e keeps the failing pipeline from exiting under pipefail).
for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do
  echo "--- brew bundle attempt ${attempt}/${MAX_ATTEMPTS} ---"
  BUNDLE_LOG="${BREW_HOME}/bundle-attempt-${attempt}.log"
  set +e
  setpriv --reuid="${BREW_UID}" --regid="${BREW_UID}" --clear-groups \
    env HOME="${BREW_HOME}" \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_BUNDLE_FILE="${BREWFILE}" \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_ENV_HINTS=1 \
    "${PREFIX}/bin/brew" bundle install 2>&1 | tee "${BUNDLE_LOG}"
  rc=${PIPESTATUS[0]}
  if [ "${rc}" -ne 0 ]; then
    echo "  WARN  modern 'brew bundle install' failed (rc=${rc}) — trying legacy invocation"
    setpriv --reuid="${BREW_UID}" --regid="${BREW_UID}" --clear-groups \
      env HOME="${BREW_HOME}" \
      HOMEBREW_NO_AUTO_UPDATE=1 \
      HOMEBREW_NO_ANALYTICS=1 \
      HOMEBREW_NO_ENV_HINTS=1 \
      "${PREFIX}/bin/brew" bundle --no-lock --file="${BREWFILE}" 2>&1 | tee -a "${BUNDLE_LOG}"
    rc=${PIPESTATUS[0]}
  fi
  set -e
  if [ "${rc}" -eq 0 ]; then
    echo "  OK    brew bundle completed on attempt ${attempt}"
    break
  fi
  if [ "${attempt}" -eq "${MAX_ATTEMPTS}" ]; then
    echo "  FAIL  brew bundle failed after ${MAX_ATTEMPTS} attempts (log: ${BUNDLE_LOG})"
    echo "::endgroup::"
    exit 1
  fi
  echo "  WARN  attempt ${attempt} failed — retrying in ${RETRY_DELAY}s"
  sleep "${RETRY_DELAY}"
done
echo "::endgroup::"

echo "::group::install-brew-bundle — verify Cellar contents"
# A pour counts only when complete: every pour writes a
# Cellar/<name>/<version>/INSTALL_RECEIPT.json "tab".
missing=0
while IFS= read -r name; do
  [ -z "${name}" ] && continue
  if ls "${PREFIX}/Cellar/${name}"/*/INSTALL_RECEIPT.json >/dev/null 2>&1; then
    echo "  OK    Cellar/${name} poured (receipt present)"
  else
    echo "  FAIL  Cellar/${name} missing or incomplete after brew bundle"
    missing=$((missing + 1))
  fi
# Cellar dirs are named by formula only — strip any "tap/" prefix and
# tolerate quoted or unquoted entries, so new Brewfile lines of any
# common style are picked up automatically.
done < <(sed -nE 's/^[[:space:]]*brew "?([^" ]+)"?.*/\1/p' "${BREWFILE}" | sed 's|^.*/||')
if [ "${missing}" -gt 0 ]; then
  echo "  FAIL  ${missing} formula(s) missing — refusing to repack"
  echo "::endgroup::"
  exit 1
fi
echo "  OK    all ${formula_count} Brewfile formulas installed"
echo "::endgroup::"

echo "::group::install-brew-bundle — repack payload + cleanup"
chown -R 1000:1000 /home/linuxbrew

# Pack from a symlink-free staging path (tar arg paths must not depend on
# /home -> var/home symlink resolution) with the same home/linuxbrew/...
# layout the base tarball uses.
STAGE="/var/tmp/hbrew-pack"
rm -rf "${STAGE}"
mkdir -p "${STAGE}/home/linuxbrew"
mv "${PREFIX}" "${STAGE}/home/linuxbrew/.linuxbrew"
rm -rf /home/linuxbrew

# Drop the /var/home we created for staging — no /var state may ship in
# the layer. Only removed when WE created it this run.
if [ "${CREATED_VAR_HOME}" -eq 1 ]; then
  rm -rf /var/home
  echo "  OK    removed build-time /var/home (created for staging)"
fi

mkdir -p /usr/share/halcyon
tar --zstd -cf "${PAYLOAD}" -C "${STAGE}" home
rm -rf "${STAGE}" "${BREW_HOME}"

entries=$(tar --zstd -tf "${PAYLOAD}" | wc -l)
echo "  OK    payload ${PAYLOAD} ($(du -h "${PAYLOAD}" | cut -f1), ${entries} entries)"

# The populated prefix must NOT ship in the layer: /var is runtime state.
if [ -e /home/linuxbrew ]; then
  echo "  FAIL  ${PREFIX} still present — would ship as /var state"
  echo "::endgroup::"
  exit 1
fi
echo "  OK    staging prefix removed — payload rides in /usr only"
echo "--- install-brew-bundle complete ---"
echo "::endgroup::"
