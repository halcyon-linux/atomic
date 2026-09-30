#!/usr/bin/env bash
# halcyon build-scripts.yml verification (prompt §5.8)
# NOTE (deviation S): the prompt's `dnf -y remove gcc` is NOT performed — dnf5's
# remove cascades into dependents, and Fedora's emacs-pgtk (native-comp) has a
# runtime `Requires: gcc`: build 11 removed 225 packages including the freshly
# installed emacs-pgtk. gcc stays (it is pulled in by emacs-pgtk anyway); the
# pypr-client C helper still compiled during install-pyprland.sh.
set -euo pipefail

echo "::group::build-scripts-verify — installed tool checks"

# --- Obsidian ---
echo "--- Checking Obsidian ---"
if test -x /usr/bin/obsidian; then
  echo "  PASS  /usr/bin/obsidian executable"
else
  echo "  FAIL  /usr/bin/obsidian missing or not executable"
  echo "::endgroup::"
  exit 1
fi

if test -f /usr/share/applications/obsidian.desktop; then
  echo "  PASS  obsidian.desktop present"
else
  echo "  FAIL  /usr/share/applications/obsidian.desktop missing"
  echo "::endgroup::"
  exit 1
fi

echo "  INFO  Checking Obsidian Electron shared-library deps..."
if ldd /usr/lib/obsidian/obsidian 2>/dev/null | grep -i 'not found'; then
  echo "  FAIL  obsidian Electron deps missing (ldd reported 'not found' above)"
  echo "::endgroup::"
  exit 1
else
  echo "  PASS  obsidian Electron deps satisfied"
fi

# --- Zotero ---
echo "--- Checking Zotero ---"
if test -x /usr/bin/zotero; then
  echo "  PASS  /usr/bin/zotero executable"
else
  echo "  FAIL  /usr/bin/zotero missing or not executable"
  echo "::endgroup::"
  exit 1
fi

if grep -q DisableAppUpdate /usr/lib/zotero/distribution/policies.json; then
  echo "  PASS  Zotero DisableAppUpdate policy present"
else
  echo "  FAIL  DisableAppUpdate policy missing from Zotero distribution/policies.json"
  echo "::endgroup::"
  exit 1
fi

# --- Pyprland ---
echo "--- Checking Pyprland ---"
if test -x /usr/bin/pypr; then
  echo "  PASS  /usr/bin/pypr executable"
else
  echo "  FAIL  /usr/bin/pypr missing or not executable"
  echo "::endgroup::"
  exit 1
fi

if test -f /usr/lib/systemd/user/pyprland.service; then
  echo "  PASS  pyprland.service user unit present"
else
  echo "  FAIL  /usr/lib/systemd/user/pyprland.service missing"
  echo "::endgroup::"
  exit 1
fi

# --- TeX Live ---
echo "--- Checking TeX Live ---"
if test -d /usr/lib/texlive; then
  echo "  PASS  /usr/lib/texlive directory present"
else
  echo "  FAIL  /usr/lib/texlive directory missing"
  echo "::endgroup::"
  exit 1
fi

if test -f /etc/profile.d/texlive.sh; then
  echo "  PASS  /etc/profile.d/texlive.sh present"
else
  echo "  FAIL  /etc/profile.d/texlive.sh missing"
  echo "::endgroup::"
  exit 1
fi

# --- Deliberately retained packages (deviation S) ---
echo "--- Checking deliberately retained packages ---"
echo "  INFO  gcc, perl, python3, jq are intentionally kept (gcc: emacs native-comp dep — NOTES.md §4 S)"
for pkg in gcc perl python3 jq; do
  if rpm -q "${pkg}" &>/dev/null; then
    ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "${pkg}")
    echo "  PASS  ${pkg}-${ver} installed"
  else
    echo "  FAIL  ${pkg} not installed (expected to be retained)"
    echo "::endgroup::"
    exit 1
  fi
done

echo "--- Checking emacs-pgtk survived gcc cascade guard ---"
if rpm -q emacs-pgtk &>/dev/null; then
  ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' emacs-pgtk)
  echo "  PASS  emacs-pgtk-${ver} installed (gcc cascade guard held)"
else
  echo "  FAIL  emacs-pgtk missing — gcc removal cascaded into it (regression!)"
  echo "::endgroup::"
  exit 1
fi

# --- python-packages family (shared venv, 11 binaries) ---
echo "--- Checking shared python venv ---"
if test -d /usr/lib/halcyon-python; then
  echo "  PASS  /usr/lib/halcyon-python virtualenv present"
else
  echo "  FAIL  /usr/lib/halcyon-python virtualenv missing"
  echo "::endgroup::"
  exit 1
fi

if test ! -d /usr/src/python-packages; then
  echo "  PASS  staged sources cleaned up (/usr/src/python-packages absent)"
else
  echo "  FAIL  staged sources still present at /usr/src/python-packages (cleanup skipped?)"
  echo "::endgroup::"
  exit 1
fi

echo "--- Checking the 11 console binaries ---"
BINARIES="dump-to-markdown fconf fe ff fkill fp fssh rmi rmtmp screenshot se"
for bin_name in ${BINARIES}; do
  if test -x "/usr/bin/${bin_name}"; then
    echo "  PASS  /usr/bin/${bin_name} executable"
  else
    echo "  FAIL  /usr/bin/${bin_name} missing or not executable"
    echo "::endgroup::"
    exit 1
  fi
done

dtm_version="$(/usr/bin/dump-to-markdown --version)"
if echo "${dtm_version}" | grep -q "1.2.0"; then
  echo "  PASS  dump-to-markdown version reported (${dtm_version})"
else
  echo "  FAIL  unexpected dump-to-markdown --version output: ${dtm_version}"
  echo "::endgroup::"
  exit 1
fi

for bin_name in fconf fe ff fkill fp fssh rmi rmtmp screenshot se; do
  if /usr/bin/${bin_name} -h >/dev/null 2>&1 || /usr/bin/${bin_name} --version >/dev/null 2>&1; then
    echo "  PASS  ${bin_name} -h/--version smoke"
  else
    echo "  FAIL  ${bin_name} -h/--version exited non-zero"
    echo "::endgroup::"
    exit 1
  fi
done

echo "--- Security: venv/payload ownership and modes ---"
ww_files="$(find /usr/lib/halcyon-python ! -type l -perm -0002 -print 2>/dev/null || true)"
if [ -n "${ww_files}" ]; then
  echo "  FAIL  world-writable files inside /usr/lib/halcyon-python:"
  echo "${ww_files}" | head -n 10 | sed 's/^/          /'
  echo "::endgroup::"
  exit 1
else
  echo "  PASS  no world-writable files in /usr/lib/halcyon-python"
fi

venv_owner="$(stat -c '%U:%G' /usr/lib/halcyon-python)"
if [ "${venv_owner}" = "root:root" ]; then
  echo "  PASS  venv owned by root:root"
else
  echo "  FAIL  venv owner is ${venv_owner}, expected root:root"
  echo "::endgroup::"
  exit 1
fi

payload_mode="$(stat -c '%a' /usr/share/halcyon/brew-bundle.tar.zst)"
if [ "${payload_mode}" = "644" ]; then
  echo "  PASS  brew payload mode 644 (root-owned, not world-writable)"
else
  echo "  FAIL  brew payload mode is ${payload_mode}, expected 644"
  echo "::endgroup::"
  exit 1
fi

echo "--- Functional smoke: dump a tiny tree ---"
DTM_TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${DTM_TMP}"; rm -rf "${DTM_TMP}"' EXIT
mkdir -p "${DTM_TMP}/smoke/src"
echo "x = 1" >"${DTM_TMP}/smoke/src/a.py"
# shellcheck disable=SC2016  # heading pattern is a literal, backticks included
if /usr/bin/dump-to-markdown --root "${DTM_TMP}/smoke" --output "${DTM_TMP}/smoke-dump.md"; then
  if grep -q '^## `smoke/src/a.py`$' "${DTM_TMP}/smoke-dump.md" &&
    grep -q '^```python$' "${DTM_TMP}/smoke-dump.md"; then
    echo "  PASS  smoke dump produced expected heading + fence ($(wc -l <"${DTM_TMP}/smoke-dump.md") lines)"
  else
    echo "  FAIL  smoke dump missing expected heading/fence content"
    echo "::endgroup::"
    exit 1
  fi
else
  echo "  FAIL  dump-to-markdown exited non-zero on smoke tree"
  echo "::endgroup::"
  exit 1
fi

echo "--- Functional smoke: ff pattern search ---"
mkdir -p "${DTM_TMP}/smoke"
if echo "hello" >"${DTM_TMP}/smoke/hello.txt" && /usr/bin/ff -g "*.txt" "${DTM_TMP}/smoke" | grep -q "hello.txt"; then
  echo "  PASS  ff found the seeded file"
else
  echo "  FAIL  ff smoke search failed"
  echo "::endgroup::"
  exit 1
fi

echo "--- Functional smoke: brew-dep tools via payload bin (fconf/fe/se/fssh -h) ---"
# fd/bat/rg/fzf live in the brew payload, not the build container — extract
# the payload's bin tree once and prepend it to PATH for these help smokes.
seed_tmp="$(mktemp -d)"
tar --zstd -xf /usr/share/halcyon/brew-bundle.tar.zst -C "${seed_tmp}" home/linuxbrew/.linuxbrew/bin
PAY_BIN="${seed_tmp}/home/linuxbrew/.linuxbrew/bin"
for bin_name in fconf fe se fssh; do
  if PATH="${PAY_BIN}:${PATH}" /usr/bin/${bin_name} -h >/dev/null 2>&1; then
    echo "  PASS  ${bin_name} -h (payload tools on PATH)"
  else
    echo "  FAIL  ${bin_name} -h failed even with payload tools on PATH"
    echo "::endgroup::"
    exit 1
  fi
done
rm -rf "${seed_tmp}"

echo "--- build-scripts-verify complete — all checks passed ---"
echo "::endgroup::"
