#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing fonts (technique borrowed from the blue-build fonts module) ==="
FONT_TMP="$(mktemp -d)"
trap 'rm -rf "${FONT_TMP}"' EXIT

# --- Nerd Fonts --------------------------------------------------------------
NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
NERD_DEST="/usr/share/fonts/nerd-fonts"
NERD_FONTS=("JetBrainsMono" "NerdFontsSymbolsOnly")

for FONT in "${NERD_FONTS[@]}"; do
  [ -n "${FONT}" ] || continue
  rm -rf "${NERD_DEST:?}/${FONT:?}"
  mkdir -p "${NERD_DEST}/${FONT}"
  echo "Downloading ${FONT} from ${NERD_URL}/${FONT}.tar.xz"
  curl -fLsS --retry 5 --create-dirs "${NERD_URL}/${FONT}.tar.xz" -o "${FONT_TMP}/${FONT}.tar.xz"
  tar -xf "${FONT_TMP}/${FONT}.tar.xz" -C "${NERD_DEST}/${FONT}"
done

# --- Google Fonts ------------------------------------------------------------
GOOGLE_DEST="/usr/share/fonts/google-fonts"
GOOGLE_FONTS=("JetBrains Mono" "Noto Emoji" "Noto Color Emoji")

for FONT in "${GOOGLE_FONTS[@]}"; do
  [ -n "${FONT}" ] || continue
  rm -rf "${GOOGLE_DEST:?}/${FONT:?}"
  mkdir -p "${GOOGLE_DEST}/${FONT}"

  readarray -t FILE_REFS < <(
    if JSON=$(curl -fLsS --retry 5 "https://fonts.google.com/download/list?family=${FONT// /%20}" | tail -n +2); then
      echo "$JSON" | jq -c '.manifest.fileRefs[]' 2>/dev/null
    fi
  )

  if [ ${#FILE_REFS[@]} -eq 0 ]; then
    echo "Could not find download information for ${FONT}"
    continue
  fi

  for FILE_REF in "${FILE_REFS[@]}"; do
    if FILENAME=$(echo "${FILE_REF}" | jq -er '.filename' 2>/dev/null); then
      if URL=$(echo "${FILE_REF}" | jq -er '.url' 2>/dev/null); then
        echo "Downloading ${FILENAME} from ${URL}"
        curl -fLsS --retry 5 --create-dirs "${URL}" -o "${GOOGLE_DEST}/${FONT}/${FILENAME##*/}"
      else
        echo "Failed to extract URLs for: ${FONT}" >&2
      fi
    else
      echo "Failed to extract filenames for: ${FONT}" >&2
    fi
  done
done

# Refresh the font cache used by the system
fc-cache --system-only --really-force /usr/share/fonts

echo "Fonts installed."
