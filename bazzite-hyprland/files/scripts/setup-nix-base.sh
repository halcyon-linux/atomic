#!/usr/bin/env bash
set -euo pipefail

echo "=== Preparing /nix mountpoint for Atomic OSTree ==="
# Creates /nix directory in root so systemd can bind-mount /var/nix to /nix
mkdir -p /nix
chmod 0755 /nix
