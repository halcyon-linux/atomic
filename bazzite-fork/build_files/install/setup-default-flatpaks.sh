#!/usr/bin/env bash
set -euo pipefail

echo "=== Registering default-flatpaks configuration ==="

# ---------------------------------------------------------------------------
# Flatpaks to install for each scope, on every boot / login. Add Flatpak IDs
# here (one per array entry) to have them baked into the image's default
# configuration. This mirrors the `install:` lists of the upstream
# `default-flatpaks` BlueBuild module (see references/default-flatpaks/),
# adapted to this image's plain-bash build pipeline.
# ---------------------------------------------------------------------------
SYSTEM_FLATPAKS=(
)

USER_FLATPAKS=(
)

FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
CONFIG_DIR="/etc/hyprland-image"
CONFIG_FILE="${CONFIG_DIR}/default-flatpaks.json"

install -d "${CONFIG_DIR}"

to_json_array() {
  local -a items=("$@")
  if [[ ${#items[@]} -eq 0 ]]; then
    printf '[]'
  else
    printf '%s\n' "${items[@]}" | jq -R . | jq -s .
  fi
}

SYSTEM_JSON="$(to_json_array "${SYSTEM_FLATPAKS[@]}")"
USER_JSON="$(to_json_array "${USER_FLATPAKS[@]}")"

jq -n \
  --argjson system_install "${SYSTEM_JSON}" \
  --argjson user_install "${USER_JSON}" \
  --arg flathub_url "${FLATHUB_URL}" \
  '[
    {
      scope: "system",
      notify: true,
      keep_fedora: false,
      repo: { url: $flathub_url, name: "flathub", title: "Flathub" },
      install: $system_install
    },
    {
      scope: "user",
      notify: true,
      keep_fedora: false,
      repo: { url: $flathub_url, name: "flathub", title: "Flathub" },
      install: $user_install
    }
  ]' > "${CONFIG_FILE}"

echo "Wrote default-flatpaks configuration to ${CONFIG_FILE}:"
cat "${CONFIG_FILE}"

# ---------------------------------------------------------------------------
# Safe-check: verify every configured Flatpak ID exists on Flathub, so a
# typo fails the build instead of silently failing on every boot.
# ---------------------------------------------------------------------------
check_flathub_ids() {
  local id app_id
  for id in "$@"; do
    [[ -z "${id}" ]] && continue
    app_id="${id%%//*}" # strip an optional //branch suffix
    if ! curl -fLsS --retry 5 --retry-all-errors -o /dev/null \
        "https://flathub.org/api/v2/stats/${app_id}"; then
      echo "ERROR: Flatpak ID '${id}' was not found on Flathub. Check the spelling in build_files/install/setup-default-flatpaks.sh." >&2
      exit 1
    fi
  done
}

if [[ ${#SYSTEM_FLATPAKS[@]} -gt 0 ]]; then
  echo "Validating system Flatpak IDs against Flathub..."
  check_flathub_ids "${SYSTEM_FLATPAKS[@]}"
fi

if [[ ${#USER_FLATPAKS[@]} -gt 0 ]]; then
  echo "Validating user Flatpak IDs against Flathub..."
  check_flathub_ids "${USER_FLATPAKS[@]}"
fi

echo "default-flatpaks configuration registered."
