#!/usr/bin/env bash
# halcyon apps.yml post-install verification (prompt §5.3)
# NOTE: BlueBuild dnf module's repos.cleanup only DISABLES COPRs — it does not
# remove files:/URL-added repo files in CLI v0.9.37 (add_repos returns empty
# repo IDs; see NOTES.md deviation R), so this script removes them explicitly.
set -euo pipefail

echo "::group::apps-verify — repo hygiene cleanup"

# --- Explicit repo file cleanup ---
echo "--- Restoring terra base state (§1.11) ---"
if dnf5 repolist --enabled 2>/dev/null | grep -q '^terra'; then
  dnf5 config-manager setopt terra.enabled=0
  echo "  OK    terra repo was enabled — now disabled"
else
  echo "  OK    terra repo already disabled (cleanup ran before this script)"
fi

echo "--- Removing leftover COPR / vendor repo files ---"
removed=0
for pattern in \
    /etc/yum.repos.d/_copr*sneexy* \
    /etc/yum.repos.d/_copr_sneexy* \
    /etc/yum.repos.d/vscode.repo \
    /etc/yum.repos.d/brave-browser*.repo; do
  for f in ${pattern}; do
    [ -f "${f}" ] || continue
    rm -f "${f}"
    echo "  REMOVED  ${f}"
    removed=$((removed + 1))
  done
done
[ "${removed}" -eq 0 ] && echo "  OK    no lingering COPR/vendor repo files found"

echo "::endgroup::"

# --- Binary availability ---
echo "::group::apps-verify — binary availability"
echo "--- Checking installed app binaries ---"
for bin in code brave-browser zen-browser zed emacs; do
  if command -v "${bin}" &>/dev/null; then
    echo "  PASS  ${bin} → $(command -v "${bin}")"
  else
    echo "  FAIL  ${bin} not found in PATH"
    echo "::endgroup::"
    exit 1
  fi
done
echo "::endgroup::"

# --- Provenance checks (§1.21) ---
echo "::group::apps-verify — RPM vendor provenance"
echo "--- Full vendor report ---"
rpm -q --qf '  %{name} (vendor: %{VENDOR})\n' \
  code brave-browser brave-origin zen-browser zed emacs-pgtk 2>/dev/null || true

echo "--- Vendor gates ---"

v="$(rpm -q --qf '%{VENDOR}' zen-browser 2>/dev/null)"
if echo "${v}" | grep -qi 'sneexy'; then
  echo "  PASS  zen-browser vendor OK (${v})"
else
  echo "  FAIL  zen-browser vendor '${v}' — must be the sneexy COPR (user directive)"
  echo "::endgroup::"
  exit 1
fi

v="$(rpm -q --qf '%{VENDOR}' zed 2>/dev/null)"
if echo "${v}" | grep -qi 'terra'; then
  echo "  PASS  zed vendor OK (${v})"
else
  echo "  FAIL  zed vendor '${v}' — must be terra"
  echo "::endgroup::"
  exit 1
fi

v="$(rpm -q --qf '%{VENDOR}' code 2>/dev/null)"
if echo "${v}" | grep -qi 'microsoft'; then
  echo "  PASS  code vendor OK (${v})"
else
  echo "  FAIL  code vendor '${v}' — must be Microsoft"
  echo "::endgroup::"
  exit 1
fi

v="$(rpm -q --qf '%{VENDOR}' brave-browser 2>/dev/null)"
if echo "${v}" | grep -qi 'brave'; then
  echo "  PASS  brave-browser vendor OK (${v})"
else
  echo "  FAIL  brave-browser vendor '${v}' — must be Brave"
  echo "::endgroup::"
  exit 1
fi

if rpm -q brave-origin &>/dev/null; then
  ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' brave-origin)
  echo "  PASS  brave-origin-${ver} installed"
else
  echo "  NOTE  brave-origin unavailable this run (skip-unavailable) — non-fatal"
fi

echo "::endgroup::"

# --- /opt auto-relocation check (CLI >= v0.9.23, §1.19o) ---
echo "::group::apps-verify — Brave /opt relocation"
echo "--- Checking /opt auto-relocation ---"
if ls -d /usr/lib/opt/brave.com 2>/dev/null; then
  echo "  PASS  Brave content at /usr/lib/opt/brave.com (auto-relocated)"
elif ls -d /opt/brave.com 2>/dev/null; then
  echo "  PASS  Brave content at /opt/brave.com (legacy path)"
else
  echo "  FAIL  Brave /opt content missing — check BlueBuild CLI version (need >= v0.9.23)"
  echo "::endgroup::"
  exit 1
fi

echo "--- tmpfiles.d entries for Brave ---"
tmpfiles_hits=$(ls /usr/lib/tmpfiles.d/ 2>/dev/null | grep -i brave || true)
if [ -n "${tmpfiles_hits}" ]; then
  echo "  INFO  tmpfiles.d entries found: ${tmpfiles_hits}"
else
  echo "  INFO  no Brave tmpfiles.d entries (may be normal depending on CLI version)"
fi
echo "::endgroup::"

# --- Repo hygiene gates ---
echo "::group::apps-verify — repo hygiene gates"
echo "--- Verifying no app repos remain enabled ---"

enabled_repos=$(dnf5 repolist --enabled 2>/dev/null | grep -Ei 'brave|^code|zen|terra' || true)
if [ -n "${enabled_repos}" ]; then
  echo "  FAIL  the following repos should have been disabled but are still enabled:"
  echo "${enabled_repos}" | sed 's/^/          /'
  echo "::endgroup::"
  exit 1
else
  echo "  PASS  brave/code/zen/terra repos not in enabled repolist"
fi

leftover_files=$(ls /etc/yum.repos.d/ 2>/dev/null | grep -Ei 'brave|vscode|sneexy' || true)
if [ -n "${leftover_files}" ]; then
  echo "  FAIL  leftover repo files found in /etc/yum.repos.d/:"
  echo "${leftover_files}" | sed 's/^/          /'
  echo "::endgroup::"
  exit 1
else
  echo "  PASS  no leftover brave/vscode/sneexy repo files in /etc/yum.repos.d/"
fi

echo "--- apps-verify complete — all checks passed ---"
echo "::endgroup::"
