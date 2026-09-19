#!/usr/bin/env bash
set -euo pipefail

echo "=== Setting up chezmoi dotfiles ==="

DOTFILE_REPOSITORY="https://github.com/aahsnr-configs/dots"

# Apply the dotfiles into the system skeleton. New users (i.e. the deploy
# user after rebasing) therefore start with the dotfiles already in place.
#
# file-conflict-policy: replace  (from the recipe's chezmoi module config)
HOME=/etc/skel \
  /usr/bin/chezmoi init --apply --force --no-tty "${DOTFILE_REPOSITORY}"

# The chezmoi user services live in system_files; the init service re-applies
# when a user has no chezmoi git repository yet, the timer keeps them updated.
echo "Dotfiles have been applied to /etc/skel."
