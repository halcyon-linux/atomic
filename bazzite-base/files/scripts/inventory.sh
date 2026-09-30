#!/usr/bin/env bash
# halcyon Step A — detection / inventory (prompt §5.1)
set -uo pipefail
INVENTORY=/tmp/halcyon-inventory.txt
{
  echo "### halcyon inventory $(date -u +%Y-%m-%dT%H:%M:%SZ) ###"
  echo
  echo '## bloat candidates (rpm -qa greps)'
  for pat in \
    'waydroid' 'decky' 'bluebubble' 'hhd' 'inputplumber' 'steamos-manager*' \
    'powerstation' 'jupiter*' 'steamdeck*' 'galileo*' 'powerbuttond' \
    'sdgyrodsu' 'vpower' 'hid-replay' 'fastfetch' 'yafti' 'sddm' 'gdm' \
    'cage' 'gnome-shell*' 'gnome-*' 'firefox*' 'ptyxis' 'nautilus*'; do
    echo "-- *${pat}*"
    rpm -qa "*${pat}*" || true
  done
  echo
  echo '## fonts'
  rpm -qa '*fonts*'
  echo
  echo '## /etc/yum.repos.d/'
  ls -1 /etc/yum.repos.d/ || true
  echo
  echo '## enabled repos'
  dnf5 repolist --enabled || true
  echo
  echo '## flatpak remotes.d'
  ls -1 /etc/flatpak/remotes.d/ || true
  echo
  echo '## keeper spot-checks'
  rpm -q bazaar bazzite-portal scx-scheds scx-tools steamos-manager \
    terra-gamescope umu-launcher lutris steam gamemode \
    gamescope-session-ogui-steam jq perl python3 || true
  printf 'distroshelf-helper file: '
  test -f /usr/bin/distroshelf-helper && echo present || echo absent
  echo
  echo '## unit enablement state (build-container view; informational)'
  for u in sddm gdm nvidia-powerd nvidia-persistenced scx_loader \
    inputplumber bazzite-autologin brew-setup bazzite-flatpak-manager; do
    printf '%s: ' "$u"
    systemctl is-enabled "$u" 2>&1 || true
  done
  echo
  echo '## brew payload'
  ls -d /usr/share/homebrew* 2>/dev/null || echo 'no /usr/share/homebrew*'
  echo
  echo '## default user shell'
  grep '^SHELL' /etc/default/useradd || true
  echo
  echo '## non-RPM dirs under /usr/share/gnome-shell/extensions/'
  if [ -d /usr/share/gnome-shell/extensions ]; then
    for d in /usr/share/gnome-shell/extensions/*/; do
      d="${d%/}"
      name="$(basename "$d")"
      if rpm -qf "$d" >/dev/null 2>&1; then
        echo "RPM-owned: ${name} ($(rpm -qf "$d"))"
      else
        echo "non-RPM:   ${name}"
      fi
    done
  else
    echo 'directory absent'
  fi
  echo
  echo '## reverse dependencies (whatrequires)'
  for p in sddm cage steamos-manager gnome-settings-daemon; do
    echo "-- whatrequires ${p}"
    dnf -q repoquery --installed --whatrequires "$p" 2>/dev/null || true
  done
} 2>&1 | tee "$INVENTORY"
echo "inventory written to ${INVENTORY}"
