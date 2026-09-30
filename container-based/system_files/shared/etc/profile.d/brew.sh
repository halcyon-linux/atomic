#!/usr/bin/env bash

# Prioritize system binaries to prevent brew overriding things like dbus
# (upstream ublue-os/brew /etc/profile.d/brew.sh, verbatim).
# HOMEBREW_* env vars for ALL sessions (incl. non-interactive) come from
# /etc/profile.d/../environment.d/10-homebrew.conf via
# systemd-environment-d-generator; this hook only fixes up interactive shells.
if [[ $- == *i* && -z "${HOMEBREW_PREFIX:-}" && -d /home/linuxbrew/.linuxbrew && ! "$PATH" =~ "/home/linuxbrew.linuxbrew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv | grep -Ev '\bPATH=')"
  HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
  export PATH="${PATH}:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin"
fi
