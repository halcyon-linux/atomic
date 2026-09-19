#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing NVIDIA (open) driver from the ublue akmods image ==="

# The driver bundle ships the firmware blobs; remove the base package if it is
# present on the Silverblue image (tolerant of it being absent).
dnf5 -y remove nvidia-gpu-firmware || true

# The akmods-nvidia image is bind-mounted at /tmp/rpms/nvidia by the
# Containerfile. MULTILIB=0 skips the i686 (32-bit multilib) packages that
# bazzite pulls from the negativo17 multimedia repository, which is not part
# of the plain Silverblue base.
IMAGE_NAME="SKIP_PACKAGE_INSTALL" \
AKMODNV_PATH="/tmp/rpms/nvidia" \
MULTILIB=0 \
  /tmp/rpms/nvidia/ublue-os/nvidia-install.sh

# Remove the nouveau ICDs so the NVIDIA driver handles Vulkan
rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json || true

# Symlink expected by some applications
ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so

# Services shipped with the driver / ublue addons
systemctl enable nvidia-powerd.service || true
if [[ -e /usr/lib/systemd/system/ublue-nvidia-flatpak-runtime-sync.service ]]; then
  systemctl enable ublue-nvidia-flatpak-runtime-sync
fi
if [[ -e /usr/lib/systemd/system/ublue-nvidia-flatpak-runtime-verify.service ]]; then
  systemctl enable ublue-nvidia-flatpak-runtime-verify
fi

echo "NVIDIA (open) driver is installed."
