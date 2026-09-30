# shellcheck shell=sh
# halcyon image-path.sh — add helper scripts to PATH for all POSIX login/interactive shells.
#
# NOTE: Homebrew PATH is already handled for interactive shells by the base Bazzite
# /etc/profile.d/brew.sh (from ublue-os/brew), which appends brew *after* system
# paths to preserve system-binary priority (dbus etc.). We only add the
# halcyon helper scripts directory here; do not duplicate or pre-empt brew's own
# PATH management to avoid breakage.
case ":${PATH}:" in
  *:/usr/libexec/halcyon-image:*) ;;
  *) export PATH="${PATH}:/usr/libexec/halcyon-image" ;;
esac
