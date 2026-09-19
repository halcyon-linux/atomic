#!/usr/bin/env bash
#
# build.sh - the main build driver for the bazzite-fork image.
#
# The Containerfile calls this script for each build stage. All COPR
# repositories are enabled together as a group (``stage repos``) and disabled
# together as a group (``stage disable-repos``) so that every dnf install that
# ships from them can resolve packages without any repository being active in
# the finished image.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# COPR repositories used by this image. Enable and disable stay in sync.
# ---------------------------------------------------------------------------
COPR_REPOS=(
  "lionheartp/Hyprland"      # hyprland-git, noctalia-git, nwg-look, qt6ct,
                             # xdg-desktop-portal-hyprland, cliphist
  "sneexy/zen-browser"      # zen-browser
)

# The Hyprland COPR must win over the Fedora repository (qt6ct is also in
# Fedora) and over the lionheartp packages from other repos.
PRIORITY_COPR=98

# ---------------------------------------------------------------------------
# Package lists (mirroring the attached recipe.yml, install-weak-deps off)
# ---------------------------------------------------------------------------
FEDORA_PACKAGES=(
  accountsservice
  bleachbit
  bluez-tools
  brightnessctl
  cargo
  chezmoi
  cmake
  cronie
  curl
  ddcutil
  direnv
  distrobox
  emacs-pgtk
  fail2ban
  file-roller
  fontconfig
  fonts-filesystem
  gcc-c++
  git
  gnome-keyring
  gnome-tweaks
  go
  grim
  gsettings-desktop-schemas
  gtk4-layer-shell
  gzip
  ImageMagick
  imv
  inotify-tools
  jq
  kitty
  kitty-shell-integration
  kitty-terminfo
  libinput-utils
  logrotate
  ly
  lynis
  man-db
  mpv
  neovim
  ninja-build
  nodejs
  npm
  papers
  papirus-icon-theme
  pipx
  pkgconf-pkg-config
  policycoreutils-python-utils
  pymol
  qt5ct
  slurp
  sqlite
  swappy
  transmission-gtk
  tree-sitter-cli
  udiskie
  xdg-desktop-portal
  xdg-user-dirs
  xdg-user-dirs-gtk
  xhost
  xorg-x11-server-Xorg
  xorg-x11-server-Xwayland
  xorg-x11-xauth
  zathura
  zathura-pdf-poppler
  zathura-plugins-all
  zsh
)

# hyprland-git, noctalia-git, nwg-look, qt6ct, xdg-desktop-portal-hyprland
# and cliphist come from the lionheartp/Hyprland COPR; zen-browser from
# sneexy/zen-browser. hyprland-devel must NOT be pulled in explicitly.
COPR_PACKAGES=(
  cliphist
  hyprland-git
  noctalia-git
  nwg-look
  qt6ct
  xdg-desktop-portal-hyprland
  zen-browser
)

# Terra URL used by the recipe (subatomic-repos)
TERRA_REPO_URL="https://raw.githubusercontent.com/terrapkg/subatomic-repos/main/terra.repo"

# ---------------------------------------------------------------------------
# COPR group handling
# ---------------------------------------------------------------------------
enable_coprs() {
  for copr in "${COPR_REPOS[@]}"; do
    echo "::group::Enabling COPR ${copr}"
    dnf5 -y copr enable "${copr}"
    dnf5 -y config-manager setopt \
      "copr:copr.fedorainfracloud.org:${copr////:}".priority=${PRIORITY_COPR}
    echo "::endgroup::"
  done
  unset copr
}

disable_coprs() {
  for copr in "${COPR_REPOS[@]}"; do
    echo "::group::Disabling COPR ${copr}"
    dnf5 -y copr disable "${copr}"
    echo "::endgroup::"
  done
  unset copr
}

# ---------------------------------------------------------------------------
# External repositories
# ---------------------------------------------------------------------------
setup_terra() {
  mkdir -p /etc/yum.repos.d
  curl -fsSL "${TERRA_REPO_URL}" -o /etc/yum.repos.d/terra.repo
  dnf5 -y config-manager setopt terra.priority=1
}

disable_terra() {
  dnf5 -y config-manager setopt terra.enabled=0
}

# ---------------------------------------------------------------------------
# Stages
# ---------------------------------------------------------------------------
stage_repos() {
  dnf5 config-manager setopt keepcache=1
  enable_coprs
  setup_terra
  dnf5 config-manager setopt skip_if_unavailable=1
}

stage_remove() {
  /ctx/global-remove
}

stage_install_base() {
  dnf5 -y --setopt=install_weak_deps=False install "${FEDORA_PACKAGES[@]}"

  # ly (display manager on tty2) comes from the official Fedora repository
  systemctl enable ly@tty2.service
  systemctl mask getty@tty2.service

  # Set SELinux file context for ly (xdm_exec_t) to prevent session launch transition denials (#494)
  semanage fcontext -a -t xdm_exec_t /usr/bin/ly 2>/dev/null || semanage fcontext -m -t xdm_exec_t /usr/bin/ly 2>/dev/null || true
  restorecon -v /usr/bin/ly 2>/dev/null || true
}

stage_install_hyprland() {
  dnf5 -y --setopt=install_weak_deps=False install "${COPR_PACKAGES[@]}"
}

stage_install_zed() {
  # only zed is taken from the Terra repository
  dnf5 -y --setopt=install_weak_deps=False install --enablerepo=terra zed
}

stage_disable_repos() {
  disable_terra
  disable_coprs
}

# ---------------------------------------------------------------------------
# Kernel guard: the akmods image is pulled from a rolling tag that tracks the
# newest kernel for the flavour. Verify that its kmod was built for exactly the
# kernel installed in the base image; fail loudly on a mismatch so that a
# silently broken image is never produced. CI's daily cron retries until the
# base image and akmods align again (zero manual work).
# Usage: build.sh verify-kernel <akmods rpms mount point>
# ---------------------------------------------------------------------------
stage_verify_kernel() {
  local akmods_path="${1:?usage: build.sh verify-kernel <akmods rpms dir>}"

  BASE_KERNEL="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core 2>/dev/null || rpm -q --qf '%{VERSION}-%{RELEASE}' kernel-core)"
  echo "Base image kernel : ${BASE_KERNEL}"

  KMOD_RPM="$(find "${akmods_path}"/kmods -maxdepth 1 -name 'kmod-nvidia-*.rpm' 2>/dev/null | head -n1)"
  if [[ -z "${KMOD_RPM}" ]]; then
    echo "ERROR: no kmod-nvidia-*.rpm found under ${akmods_path}/kmods" >&2
    exit 1
  fi

  # Preferred: the kmod RPM declares 'kernel-uname-r = <version>' as a requirement.
  AKMODS_KERNEL="$(rpm -qp --qf '%{REQUIRENAME}\n' "${KMOD_RPM}" \
    | grep -oP 'kernel-uname-r = \K.*' | head -n1 || true)"

  # Fallback: parse the kernel out of the RPM file name
  #   kmod-nvidia-<kernel>-<akmod-version>.<arch>.rpm
  if [[ -z "${AKMODS_KERNEL}" ]]; then
    AKMODS_KERNEL="$(basename "${KMOD_RPM}" \
      | sed -E 's/^kmod-nvidia-(.*)-[0-9]+\.[0-9]+\..*/\1/')"
  fi

  echo "akmods kmod kernel: ${AKMODS_KERNEL}"
  BASE_KERNEL_NOARCH="${BASE_KERNEL%.*}"
  AKMODS_KERNEL_NOARCH="${AKMODS_KERNEL%.*}"

  if [[ "${BASE_KERNEL}" != "${AKMODS_KERNEL}" && "${BASE_KERNEL_NOARCH}" != "${AKMODS_KERNEL_NOARCH}" ]]; then
    echo "ERROR: kernel mismatch -- akmods image is built for '${AKMODS_KERNEL}'" >&2
    echo "       but the base image ships '${BASE_KERNEL}'." >&2
    echo "       This is transient: the daily CI cron retries until the base" >&2
    echo "       image and the akmods rolling tag align." >&2
    exit 1
  fi
  echo "Kernel match verified."
}

stage_services() {
  # system services
  systemctl enable accounts-daemon.service
  systemctl enable podman.socket
  systemctl enable brew-setup.service
  systemctl enable brew-update.timer brew-upgrade.timer
  systemctl enable system-flatpak-setup.timer

  # user services (run for every user on their first login)
  systemctl --global enable chezmoi-init.service chezmoi-update.timer
  systemctl --global enable pyprland.service
  systemctl --global enable user-flatpak-setup.timer
  systemctl --global enable brew-packages-setup.service
}

main() {
  local stage="${1:?usage: build.sh <stage>}"
  case "${stage}" in
    repos)           stage_repos ;;
    remove)          stage_remove ;;
    install-base)    stage_install_base ;;
    install-hyprland) stage_install_hyprland ;;
    install-zed)     stage_install_zed ;;
    disable-repos)   stage_disable_repos ;;
    verify-kernel)   stage_verify_kernel "${2:?usage: build.sh verify-kernel <dir>}" ;;
    services)        stage_services ;;
    *)
      echo "Unknown build stage: ${stage}" >&2
      exit 1
      ;;
  esac
}

main "$@"
