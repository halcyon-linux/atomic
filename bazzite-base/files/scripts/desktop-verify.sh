#!/usr/bin/env bash
# halcyon desktop.yml post-install verification (prompt §5.2)
set -euo pipefail

echo "::group::desktop-verify — Hyprland stack checks"

# --- Repo hygiene (full T17 hygiene §1.19d) ---
echo "--- Cleaning up lionheartp COPR repo files ---"
removed=0
for f in /etc/yum.repos.d/_copr*lionheartp* /etc/yum.repos.d/_copr_lionheartp_Hyprland.repo; do
  if [ -f "${f}" ]; then
    rm -f "${f}"
    echo "  REMOVED  ${f}"
    removed=$((removed + 1))
  fi
done
[ "${removed}" -eq 0 ] && echo "  OK    no lingering lionheartp COPR repo files found"

# --- Core package presence ---
echo "--- Checking core Hyprland packages ---"
for pkg in hyprland-git hyprland-guiutils noctalia-git noctalia-greeter-git greetd xdg-desktop-portal-gtk xdg-desktop-portal-hyprland; do
  if rpm -q "${pkg}" &>/dev/null; then
    ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "${pkg}")
    echo "  PASS  ${pkg}-${ver}"
  else
    echo "  FAIL  ${pkg} not installed"
    echo "::endgroup::"
    exit 1
  fi
done

# --- ABI consistency guard (§1.15) ---
echo "--- Checking Hyprland -git ABI (ldd) ---"
if ldd /usr/bin/Hyprland 2>/dev/null | grep -i 'not found'; then
  echo "  FAIL  hyprland-git ABI break — missing shared libraries listed above"
  echo "::endgroup::"
  exit 1
else
  echo "  PASS  Hyprland shared-library deps all satisfied"
fi

# --- Provenance guard (§1.15) ---
# dnf5 history/from-repo tracking is unavailable on rpm-ostree images;
# provenance is checked via RPM VENDOR — COPR stamps "Fedora Copr - user lionheartp".
echo "--- Checking COPR provenance (RPM VENDOR field) ---"
echo "  INFO  Full vendor report:"
rpm -q --qf '  %{name} (vendor: %{VENDOR})\n' \
  hyprland-git noctalia-git hyprgraphics hyprlang aquamarine hyprcursor hyprutils 2>/dev/null || true

for p in hyprgraphics hyprlang aquamarine hyprcursor; do
  if ! rpm -q "${p}" >/dev/null 2>&1; then
    echo "  SKIP  ${p} not installed — skipping vendor check"
    continue
  fi
  vendor="$(rpm -q --qf '%{VENDOR}' "${p}")"
  if echo "${vendor}" | grep -qi 'lionheartp'; then
    echo "  PASS  ${p} vendor OK (${vendor})"
  else
    echo "  FAIL  ${p} vendor '${vendor}' — resolved outside the lionheartp COPR; mixed -git stack risk (§1.15)."
    echo "        Remediation: raise COPR repo priority (dnf5 config-manager setopt '*lionheartp*'.priority=1)"
    echo "        between copr-enable and install, via two dnf module entries + interleaved script."
    echo "::endgroup::"
    exit 1
  fi
done

# --- Session desktop file ---
echo "--- Checking Hyprland Wayland session entry ---"
if test -f /usr/share/wayland-sessions/hyprland.desktop; then
  echo "  PASS  /usr/share/wayland-sessions/hyprland.desktop present"
else
  echo "  FAIL  /usr/share/wayland-sessions/hyprland.desktop missing"
  echo "::endgroup::"
  exit 1
fi

# --- greetd system user (§1.18). The config.toml consistency + noctalia
#     wiring gates live in files-verify.sh: they check the halcyon
#     config.toml, which files.yml only copies AFTER this module runs
#     (here /etc/greetd/config.toml is still the greetd RPM's stock
#     `agreety` config) ---
echo "--- Checking greetd system user ---"
if id greetd &>/dev/null; then
  uid=$(id -u greetd)
  echo "  PASS  greetd system user present (uid=${uid})"
else
  echo "  FAIL  greetd user missing — config.toml user directive will break login"
  echo "::endgroup::"
  exit 1
fi

# --- session launcher (Hyprland 0.53+ mandates start-hyprland) ---
if command -v start-hyprland >/dev/null 2>&1; then
  echo "  PASS  start-hyprland present (wayland session command)"
else
  echo "  FAIL  start-hyprland not on PATH — the Hyprland wayland session would fail"
  echo "::endgroup::"
  exit 1
fi

# --- Repo cleanup gate ---
echo "--- Verifying lionheartp COPR is disabled ---"
if dnf5 repolist --enabled 2>/dev/null | grep -Ei 'lionheartp'; then
  echo "  FAIL  lionheartp COPR still enabled in dnf5 repolist — cleanup incomplete"
  echo "::endgroup::"
  exit 1
else
  echo "  PASS  lionheartp COPR not in enabled repolist"
fi

echo "--- desktop-verify complete — all checks passed ---"
echo "::endgroup::"
