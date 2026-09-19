#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Brave Browser & Brave Origin ==="

# On ostree/bootc images, /opt is a symlink to var/opt.
# Because /var/opt does not exist in the base image, RPM/cpio fails when creating
# subdirectories under /opt ("failed to open dir opt of /opt/...: cpio: mkdir failed - File exists").
# Ensuring /opt points to /usr/lib/opt allows RPM to unpack /opt files directly
# into the read-only OSTree system tree under /usr/lib/opt.
mkdir -p /usr/lib/opt
if [[ -L /opt && "$(readlink /opt)" == "var/opt" ]]; then
  rm -f /opt
  ln -s usr/lib/opt /opt
fi

# Import Brave GPG key and add the Brave repository
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
curl -fsSLo /etc/yum.repos.d/brave-browser.repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

# Install brave-browser and brave-origin
dnf5 -y --setopt=install_weak_deps=False install brave-browser brave-origin

# Clean up repo file so it does not persist on the immutable system
rm -f /etc/yum.repos.d/brave-browser.repo

echo "Brave Browser and Brave Origin successfully installed."
