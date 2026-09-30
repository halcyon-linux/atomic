#!/usr/bin/env bash
# halcyon files.yml verification (prompt §5.9) — also verifies the brew assets
# that are only present after this module's files copy (see NOTES.md deviation O).
set -euo pipefail

echo "::group::files-verify — dotfile & brew asset checks"
trap 'echo "::endgroup::"' EXIT

# --- Target paths ---
HALCYON_LIBEXEC="/usr/libexec/halcyon-image"
IMAGE_PATH_SH="/etc/profile.d/image-path.sh"
JUST60="/usr/share/ublue-os/just/60-custom.just"
BREWFILE="/usr/share/ublue-os/homebrew/Brewfile"
BREW_SERVICE="/usr/lib/systemd/user/brew-bundle.service"
BREW_ENV="/etc/environment.d/10-homebrew.conf"
BREW_INSTALLER="/usr/libexec/halcyon-image/brew-bundle-install"

# --- Script permissions ---
echo "--- Fixing and checking script permissions ---"
if [[ -d "${HALCYON_LIBEXEC}" ]]; then
  find "${HALCYON_LIBEXEC}" -maxdepth 1 -type f -exec chmod 0755 {} +
  script_count=$(find "${HALCYON_LIBEXEC}" -maxdepth 1 -type f -perm -0111 | wc -l)
  if [[ "${script_count}" -gt 0 ]]; then
    echo "  PASS  ${HALCYON_LIBEXEC}/* executable (${script_count} scripts)"
  else
    echo "  FAIL  no executable scripts found in ${HALCYON_LIBEXEC}"
    exit 1
  fi
else
  echo "  FAIL  ${HALCYON_LIBEXEC} directory missing"
  exit 1
fi

# --- Core files & environment ---
echo "--- Checking core installed files & environment ---"
if [[ -f "${IMAGE_PATH_SH}" ]]; then
  echo "  PASS  ${IMAGE_PATH_SH} present"
else
  echo "  FAIL  ${IMAGE_PATH_SH} missing"
  exit 1
fi

if grep -q '/usr/libexec/halcyon-image' "${IMAGE_PATH_SH}"; then
  echo "  PASS  halcyon helper-scripts PATH export present in ${IMAGE_PATH_SH}"
else
  echo "  FAIL  /usr/libexec/halcyon-image PATH missing from ${IMAGE_PATH_SH}"
  exit 1
fi

# Brew PATH for non-login sessions (Wayland, GUI apps, systemd --user) lives in
# environment.d — brew.sh (from Bazzite base) covers interactive login shells.
if [[ -f "${BREW_ENV}" ]]; then
  echo "  PASS  ${BREW_ENV} present"
  if grep -q '/home/linuxbrew/.linuxbrew/bin' "${BREW_ENV}"; then
    echo "  PASS  Homebrew bin PATH entry present in ${BREW_ENV}"
  else
    echo "  FAIL  Homebrew bin PATH entry missing from ${BREW_ENV}"
    exit 1
  fi
  # environment.d generators can run without PATH in their environment; a bare
  # $PATH then expands to empty and poisons every session inheriting it.
  if grep -qE '^PATH=\$\{PATH:-' "${BREW_ENV}"; then
    echo "  PASS  ${BREW_ENV} guards against empty \$PATH expansion"
  else
    echo "  FAIL  ${BREW_ENV} uses a bare \$PATH — poisons session PATH when the generator env has none"
    exit 1
  fi
else
  echo "  FAIL  ${BREW_ENV} missing — brew packages will be invisible to Wayland/GUI apps"
  exit 1
fi

# --- PATH fail-safe + regression test for the empty-PATH login failure ---
echo "--- Checking PATH guard and login-shell regression ---"
if [[ -r /etc/profile.d/00-path-guard.sh ]]; then
  echo "  PASS  /etc/profile.d/00-path-guard.sh present"
else
  echo "  FAIL  /etc/profile.d/00-path-guard.sh missing — profile.d has no PATH fail-safe"
  exit 1
fi

# Regression test for the exact deployed failure: a login shell inheriting an
# empty PATH must still resolve system binaries once /etc/profile has run.
if env -i PATH= HOME=/root /bin/bash -lc 'command -v grep >/dev/null' 2>/dev/null; then
  echo "  PASS  login shell with empty inherited PATH can find system binaries"
else
  echo "  FAIL  login shell with empty inherited PATH cannot find grep — PATH guard broken"
  exit 1
fi

if command -v chezmoi >/dev/null 2>&1; then
  echo "  PASS  chezmoi in PATH ($(command -v chezmoi))"
  chezmoi_version="$(chezmoi --version 2>/dev/null)"
  if echo "${chezmoi_version}" | grep -q "v2\."; then
    echo "  PASS  chezmoi version OK (${chezmoi_version})"
  else
    echo "  WARN  unexpected chezmoi version output: ${chezmoi_version}"
  fi
else
  echo "  FAIL  chezmoi not found in PATH"
  exit 1
fi

# --- Chezmoi wiring (chezmoi module: user units + --global enablement) ---
echo "--- Checking chezmoi init/update wiring ---"
for unit in chezmoi-init.service chezmoi-update.service chezmoi-update.timer; do
  if [[ -f "/usr/lib/systemd/user/${unit}" ]]; then
    echo "  PASS  /usr/lib/systemd/user/${unit} present"
  else
    echo "  FAIL  /usr/lib/systemd/user/${unit} missing"
    exit 1
  fi
done

# Enablement paths follow each unit's WantedBy: init → default.target,
# timer → timers.target (both created by the module's --global enable).
if [[ -L "/etc/systemd/user/default.target.wants/chezmoi-init.service" ]]; then
  echo "  PASS  chezmoi-init.service enabled --global (default.target.wants)"
else
  echo "  FAIL  default.target.wants/chezmoi-init.service missing — dots would not apply at login"
  exit 1
fi

if [[ -L "/etc/systemd/user/timers.target.wants/chezmoi-update.timer" ]]; then
  echo "  PASS  chezmoi-update.timer enabled --global (timers.target.wants)"
else
  echo "  FAIL  timers.target.wants/chezmoi-update.timer missing — dots would never auto-update"
  exit 1
fi

# --- Justfile recipes ---
echo "--- Checking 60-custom.just recipes ---"
if [[ ! -f "${JUST60}" ]]; then
  echo "  FAIL  ${JUST60} missing"
  exit 1
fi

for recipe in doom-setup home-manager-setup; do
  if grep -q "${recipe}" "${JUST60}"; then
    echo "  PASS  ${recipe} recipe present in 60-custom.just"
  else
    echo "  FAIL  ${recipe} recipe missing from ${JUST60}"
    exit 1
  fi
done

# --- Modular personal justfiles (imported into 60-custom.just) ---
echo "--- Checking personal justfiles ---"
declare -A JUST_RECIPES=(
  [rebase.just]="rebase-to-custom"
  [texlive.just]="texlive-install texlive-update"
  [cleanup.just]="halcyon-cleanup"
  [dots.just]="dots-ssh dots-push dots-status"
)
for jf in rebase.just texlive.just cleanup.just dots.just; do
  target="/usr/share/bluebuild/justfiles/${jf}"
  if [[ -f "${target}" ]]; then
    echo "  PASS  ${target} present"
  else
    echo "  FAIL  ${target} missing"
    exit 1
  fi
  if grep -qF "import \"/usr/share/bluebuild/justfiles/${jf}\"" "${JUST60}"; then
    echo "  PASS  ${jf} imported in 60-custom.just"
  else
    echo "  FAIL  ${jf} not imported in ${JUST60}"
    exit 1
  fi
  if /usr/bin/just --justfile "${target}" --list >/dev/null 2>&1; then
    echo "  PASS  ${jf} parses (just --list)"
  else
    echo "  FAIL  ${jf} does not parse — just --list failed"
    exit 1
  fi
  for recipe in ${JUST_RECIPES[$jf]}; do
    if grep -q "${recipe}" "${target}"; then
      echo "  PASS  ${recipe} recipe present in ${jf}"
    else
      echo "  FAIL  ${recipe} recipe missing from ${jf}"
      exit 1
    fi
  done
done

if grep -q "ghcr.io/aahsnr-work/halcyon" /usr/share/bluebuild/justfiles/rebase.just && ! grep -q "bazzite-hyprland" /usr/share/bluebuild/justfiles/rebase.just; then
  echo "  PASS  rebase recipe targets the halcyon image"
else
  echo "  FAIL  rebase recipe does not target ghcr.io/aahsnr-work/halcyon"
  exit 1
fi

# --- greetd PAM keyring unlock stack ---
echo "--- Checking greetd PAM stack ---"
if [[ -f /etc/pam.d/greetd ]] && grep -q "pam_gnome_keyring.so" /etc/pam.d/greetd; then
  echo "  PASS  /etc/pam.d/greetd present with gnome-keyring unlock"
else
  echo "  FAIL  /etc/pam.d/greetd missing or lacks pam_gnome_keyring"
  exit 1
fi

# --- greetd + noctalia-greeter wiring ---
# Checked here (not in desktop-verify.sh) because /etc/greetd/config.toml is
# copied by THIS module's files tree — when desktop.yml ran earlier, the file
# on disk was still the greetd RPM's stock `agreety` config.
echo "--- Checking greetd + noctalia-greeter wiring ---"
if [[ -f /etc/greetd/config.toml ]]; then
  echo "  PASS  /etc/greetd/config.toml present"
else
  echo "  FAIL  /etc/greetd/config.toml missing"
  exit 1
fi

GREETER_CMD=$(awk -F'"' '/^[[:space:]]*command[[:space:]]*=/{print $2; exit}' /etc/greetd/config.toml 2>/dev/null || true)
if [[ "${GREETER_CMD}" == "/usr/bin/noctalia-greeter-session" ]]; then
  echo "  PASS  config.toml command is /usr/bin/noctalia-greeter-session"
else
  echo "  FAIL  config.toml command '${GREETER_CMD:-<unset>}' is not /usr/bin/noctalia-greeter-session"
  exit 1
fi

cfg_user=$(awk -F'"' '/^[[:space:]]*user[[:space:]]*=/{print $2; exit}' /etc/greetd/config.toml 2>/dev/null || true)
if [[ -n "${cfg_user}" ]] && id "${cfg_user}" >/dev/null 2>&1; then
  echo "  PASS  config.toml user '${cfg_user}' exists"
else
  echo "  FAIL  config.toml user '${cfg_user:-<unset>}' does not exist — greetd would crash-loop"
  exit 1
fi

if [[ -x /usr/bin/noctalia-greeter-session ]]; then
  echo "  PASS  /usr/bin/noctalia-greeter-session present and executable"
else
  echo "  FAIL  /usr/bin/noctalia-greeter-session missing or not executable"
  exit 1
fi

if [[ -f /usr/lib/tmpfiles.d/noctalia-greeter-state.conf ]]; then
  echo "  PASS  /var/lib/noctalia-greeter tmpfiles rule present"
else
  echo "  FAIL  noctalia-greeter state-dir tmpfiles missing — greeter state would not persist"
  exit 1
fi

# --- Brew assets (Brewfile staged by brew.yml; units by the systemd
#     module's file copy; payload itself is verified in brew-verify.sh) ---
echo "--- Checking brew assets ---"
if [[ ! -f "${BREWFILE}" ]]; then
  echo "  FAIL  ${BREWFILE} missing"
  exit 1
fi
echo "  PASS  Brewfile present"

brew_count=$(grep -c '^[[:space:]]*brew ' "${BREWFILE}" || true)
if [[ "${brew_count}" -gt 0 ]]; then
  echo "  PASS  Brewfile contains ${brew_count} brew entries"
else
  echo "  FAIL  Brewfile contains no valid 'brew' entries"
  exit 1
fi

if [[ -f "${BREW_SERVICE}" ]]; then
  echo "  PASS  brew-bundle.service user unit present"
else
  echo "  FAIL  ${BREW_SERVICE} missing"
  exit 1
fi

if [[ -x "${BREW_INSTALLER}" ]]; then
  echo "  PASS  ${BREW_INSTALLER} present and executable"
else
  echo "  FAIL  ${BREW_INSTALLER} missing or not executable"
  exit 1
fi

# Boot-time seeding wiring (all present by this module: libexec helpers via
# the files tree copy, units via the systemd module's unit copy, payload
# baked by brew.yml's install-brew-bundle.sh).
BREW_EXTRACTOR="${HALCYON_LIBEXEC}/brew-bundle-extract"
BREW_SYSTEM_UNIT="/usr/lib/systemd/system/halcyon-brew-bundle.service"
BREW_PAYLOAD="/usr/share/halcyon/brew-bundle.tar.zst"

if [[ -x "${BREW_EXTRACTOR}" ]]; then
  echo "  PASS  ${BREW_EXTRACTOR} present and executable"
else
  echo "  FAIL  ${BREW_EXTRACTOR} missing or not executable"
  exit 1
fi

if [[ -f "${BREW_SYSTEM_UNIT}" ]]; then
  echo "  PASS  ${BREW_SYSTEM_UNIT} present"
else
  echo "  FAIL  ${BREW_SYSTEM_UNIT} missing"
  exit 1
fi

if [[ -f "${BREW_PAYLOAD}" ]]; then
  echo "  PASS  ${BREW_PAYLOAD} present ($(du -h "${BREW_PAYLOAD}" | cut -f1))"
else
  echo "  FAIL  ${BREW_PAYLOAD} missing — brew.yml did not bake the bundle"
  exit 1
fi

echo "--- files-verify complete — all checks passed ---"
