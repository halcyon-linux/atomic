# shellcheck shell=sh
# halcyon image-path.sh — add helper scripts to PATH for all POSIX login/interactive shells.
#
# Homebrew PATH wiring lives in /etc/profile.d/brew.sh (interactive shells)
# and /etc/environment.d/10-homebrew.conf (all sessions); only the halcyon
# helper scripts directory is added here.
case ":${PATH}:" in
  *:/usr/libexec/halcyon-image:*) ;;
  *) export PATH="${PATH}:/usr/libexec/halcyon-image" ;;
esac
