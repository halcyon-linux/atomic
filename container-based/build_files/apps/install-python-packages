#!/usr/bin/env bash
# build-scripts.yml — install-python-packages.sh
# Installs every staged Python package under /usr/src/python-packages into
# ONE shared venv at /usr/lib/halcyon-python (all packages are stdlib-only,
# so a shared venv has no dependency conflicts), then symlinks each console
# script separately into /usr/bin — 11 independent binaries, one venv.
# Verifies per-binary in build-scripts-verify.sh.
set -euo pipefail

STAGED_ROOT="/usr/src/python-packages"
VENV_DIR="/usr/lib/halcyon-python"
# package dir name : console script name (identical for this family)
readonly EXPECTED=(
  dump-to-markdown
  fconf
  fe
  ff
  fkill
  fp
  fssh
  rmi
  rmtmp
  screenshot
  se
)

echo "::group::install-python-packages — staged packages check"
missing=()
for pkg in "${EXPECTED[@]}"; do
  if [ ! -f "${STAGED_ROOT}/${pkg}/pyproject.toml" ]; then
    missing+=("${pkg}")
  fi
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "  FAIL  missing staged packages: ${missing[*]} — files-module staging did not run"
  echo "::endgroup::"
  exit 1
fi
echo "  OK    all ${#EXPECTED[@]} staged packages present"
echo "::endgroup::"

# Snapshot the staged tree into /var/tmp before building: pip's egg_info
# step writes into the source tree, and this keeps the installer working
# even if the staging mount is read-only. Also removed wholesale at cleanup,
# so nothing ever deletes the module-staged original through a mount.
echo "::group::install-python-packages — snapshot staged sources"
install -d -m 1777 /var/tmp  # 1777 like the base/tmp.conf: the built image
                             # strips /var, so create it canonically — a plain
                             # mkdir would leave a non-sticky 0755 dir behind
WORK_ROOT="$(mktemp -d /var/tmp/python-packages.XXXXXX)"
mv "${STAGED_ROOT}"/* "${WORK_ROOT}/"
echo "  OK    staged sources snapshotted to ${WORK_ROOT}"
echo "::endgroup::"

echo "::group::install-python-packages — shared virtualenv"
echo "--- Creating virtualenv at ${VENV_DIR} ---"
rm -rf "${VENV_DIR}"
python3 -m venv "${VENV_DIR}"
echo "  OK    virtualenv created ($(python3 --version))"

echo "--- Upgrading pip / build tools ---"
"${VENV_DIR}/bin/pip" install --no-cache-dir --upgrade pip setuptools wheel
echo "  OK    pip/setuptools/wheel up to date"
echo "::endgroup::"

echo "::group::install-python-packages — pip install (11 packages)"
for pkg in "${EXPECTED[@]}"; do
  echo "--- Installing ${pkg} ---"
  "${VENV_DIR}/bin/pip" install --no-cache-dir "${WORK_ROOT}/${pkg}" \
    || { echo "  FAIL  pip install ${pkg}"; echo "::endgroup::"; exit 1; }
  echo "  OK    ${pkg} installed"
done
echo "::endgroup::"

echo "::group::install-python-packages — console script symlinks"
for pkg in "${EXPECTED[@]}"; do
  script="${VENV_DIR}/bin/${pkg}"
  if [ ! -x "${script}" ]; then
    echo "  FAIL  console script ${script} missing after install"
    echo "::endgroup::"
    exit 1
  fi
  ln -sf "${script}" "/usr/bin/${pkg}"
  echo "  OK    /usr/bin/${pkg} → ${script}"
done
echo "::endgroup::"

echo "::group::install-python-packages — secure virtualenv permissions"
chown -R root:root "${VENV_DIR}"
chmod -R go-w "${VENV_DIR}"
echo "  OK    ${VENV_DIR} permissions secured (root:root, non-world-writable)"
echo "::endgroup::"

echo "::group::install-python-packages — smoke tests"
dump_version="$(dump-to-markdown --version)"
echo "  OK    dump-to-markdown ${dump_version}"

# Some tools need fd/bat/rg/fzf at runtime — these are RPMs installed by
# 40-devtools.sh (the brew payload is retired, MIGRATION §8.7), so the plain
# PATH is enough. Run each binary and fail the build on a real problem.
failed=()
for pkg in fconf fe ff fkill fp fssh rmi rmtmp screenshot se; do
  if "/usr/bin/${pkg}" -h >/dev/null 2>&1 || "/usr/bin/${pkg}" --version >/dev/null 2>&1; then
    echo "  OK    ${pkg} smoke"
  else
    failed+=("${pkg}")
  fi
done
if [ "${#failed[@]}" -gt 0 ]; then
  echo "  FAIL  ${failed[*]} — -h/--version failed"
  echo "::endgroup::"
  exit 1
fi
echo "  OK    all 10 helper smokes passed"
echo "::endgroup::"

echo "::group::install-python-packages — cleanup staged sources"
rm -rf "${WORK_ROOT}"
rm -rf "${STAGED_ROOT}" 2>/dev/null || true
echo "  INFO  removed snapshot ${WORK_ROOT} and staged source ${STAGED_ROOT} (installed copies live in ${VENV_DIR})"
echo "--- install-python-packages complete: ${#EXPECTED[@]} binaries in /usr/bin ---"
echo "::endgroup::"
