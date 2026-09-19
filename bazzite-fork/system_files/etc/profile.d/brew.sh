# shellcheck shell=sh
# Homebrew is baked into the image under /home/linuxbrew/.linuxbrew
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
