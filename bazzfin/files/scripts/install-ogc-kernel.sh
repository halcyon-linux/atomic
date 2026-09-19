#!/usr/bin/env bash
#
# install-ogc-kernel.sh - swap the stock Fedora kernel for Universal
# Blue's "ogc" (Open Gaming Collective) kernel -- the same
# gaming/handheld-oriented kernel Bazzite ships.
#
# The RPMs themselves are staged into /tmp/ogc-kernel-rpms by the
# `copy` module in recipe.yml, pulled straight from the ublue-os/akmods
# cache image (ghcr.io/ublue-os/akmods:ogc-<fedora_version>) -- the
# exact same artifact Bazzite's own install-kernel-akmods script
# consumes:
#   https://github.com/ublue-os/bazzite/blob/main/build_files/install-kernel-akmods
#
# This script only swaps the kernel* packages themselves. Third-party
# kmods and the NVIDIA driver that must match this kernel are handled
# afterwards by the `akmods` module in recipe.yml with `base: ogc`.
#
set -euo pipefail

RPM_DIR="/tmp/ogc-kernel-rpms"
KERNEL_INSTALL_DIR="/usr/lib/kernel/install.d"

if [[ ! -d "${RPM_DIR}" ]]; then
  echo "ERROR: ${RPM_DIR} not found -- did the 'copy' module that stages" >&2
  echo "the ogc akmods kernel-rpms run before this script?" >&2
  exit 1
fi

echo "== Kernel before swap =="
rpm -q kernel-core || echo "(no kernel-core currently installed?)"

# --- Shim kernel-install triggers -------------------------------------
# The post-install scriptlets a stock `dnf5 install` runs for a kernel
# package hand off to rpm-ostree/dracut, both of which assume a live,
# booted system (mounted /boot, an active deployment, ...) that simply
# doesn't exist inside an image build. Bazzite works around this with
# this exact throwaway shim; the *real* initramfs is generated once, at
# the very end of the build, by the `initramfs` module in recipe.yml --
# this shim only needs to survive the `dnf5 install` below.
pushd "${KERNEL_INSTALL_DIR}" >/dev/null
mv 05-rpmostree.install 05-rpmostree.install.bak
mv 50-dracut.install 50-dracut.install.bak
printf '%s\n' '#!/bin/sh' 'exit 0' >05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' >50-dracut.install
chmod +x 05-rpmostree.install 50-dracut.install
popd >/dev/null

# --- Remove the stock kernel -------------------------------------------
# --nodeps because dnf/rpm dependency-resolution would otherwise try to
# drag along (or refuse to remove) everything that formally depends on
# these packages. Individual erases are tolerated if a package isn't
# installed at all -- base-main is desktop-free, so it may be missing
# kernel-tools/kernel-modules-extra etc. that a fuller base would have.
for pkg in kernel kernel-core kernel-modules kernel-modules-core \
  kernel-modules-extra kernel-tools-libs kernel-tools; do
  rpm --erase "${pkg}" --nodeps 2>/dev/null || true
done
rm -rf /usr/lib/modules

# --- Install the ogc kernel ---------------------------------------------
dnf5 -y install \
  "${RPM_DIR}"/kernel-[0-9]*.rpm \
  "${RPM_DIR}"/kernel-core-*.rpm \
  "${RPM_DIR}"/kernel-modules-*.rpm \
  "${RPM_DIR}"/kernel-devel-*.rpm

# Keep anything later in *this build* (or a future `ujust update` /
# `rpm-ostree upgrade` run against a layered package, in the unlikely
# case someone does that on top of this image) from silently dragging
# the kernel back to Fedora's own stock build.
dnf5 versionlock add kernel kernel-devel kernel-devel-matched kernel-core kernel-modules

# --- Restore the real triggers, then clean up ---------------------------
pushd "${KERNEL_INSTALL_DIR}" >/dev/null
mv -f 05-rpmostree.install.bak 05-rpmostree.install
mv -f 50-dracut.install.bak 50-dracut.install
popd >/dev/null

rm -rf "${RPM_DIR}"
dnf5 -y clean all

echo "== Kernel after swap =="
rpm -q kernel-core
