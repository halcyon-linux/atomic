#
# Custom gaming / Hyprland image, forked from the bazzite project's build
# structure (https://github.com/ublue-os/bazzite/).
#
# A single image built on top of the plain uBlue "base" image (Universal
# Blue's desktop-free image family -- the same Fedora Atomic/bootc
# foundation as silverblue-main/kinoite-main, with no desktop environment
# baked in) with the NVIDIA open-source driver baked in through the ublue
# akmods pipeline. ly provides the display manager; the desktop is Hyprland
# from the lionheartp/Hyprland COPR.
#
# Everything that is needed at login is baked in at build time: applications,
# fonts, flatpaks, chezmoi dotfiles and the Homebrew packages.
#

ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-base}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"
ARG ARCH="${ARCH:-x86_64}"
ARG BASE_IMAGE="${BASE_IMAGE:-ghcr.io/ublue-os/${BASE_IMAGE_NAME}-main:${FEDORA_VERSION}}"

# Kernel automation: the akmods image is pulled via the ROLLING tag
# "${KERNEL_FLAVOR}-${FEDORA_VERSION}-${ARCH}" (e.g. main-44-x86_64), which
# Universal Blue keeps pointed at the newest kernel build for the flavour.
# There is NO kernel version to pin or bump anywhere in this repo. A build-time
# guard verifies that the akmods kernel modules match the base image's kernel
# and fails loudly on a mismatch; the daily CI cron retries until the two
# align, so the image self-heals with zero manual work.
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-main}"
ARG NVIDIA_FLAVOR="${NVIDIA_FLAVOR:-nvidia-open}"

# ublue akmods image carrying the NVIDIA (open) driver + matching kernel modules.
FROM ghcr.io/ublue-os/akmods-${NVIDIA_FLAVOR}:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${ARCH} AS akmods-nvidia

# Universal Blue Homebrew image: ships the prebuilt /usr/share/homebrew.tar.zst
FROM ghcr.io/ublue-os/brew:latest AS brew

# Build files are bind-mounted into every RUN step as /ctx
FROM scratch AS ctx
COPY build_files /

FROM ${BASE_IMAGE}

ARG IMAGE_NAME="${IMAGE_NAME:-bazzite-fork}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-ublue-os}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-stable}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-base}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"
ARG ARCH="${ARCH:-x86_64}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-main}"
ARG NVIDIA_FLAVOR="${NVIDIA_FLAVOR:-nvidia-open}"
ARG SHA_HEAD_SHORT="${SHA_HEAD_SHORT}"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY}"

# Copy Homebrew files, units, and tarball from the ublue brew image
COPY --from=brew /system_files/ /

# Runtime configuration, systemd units, justfiles and helper scripts
COPY system_files/ /

################
# REPOSITORIES #
################
# COPR repositories are enabled together as a group and, later in the build,
# disabled together as a group -- both from build.sh (see build_files/build.sh)
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh repos && \
    /ctx/cleanup

##############
# UNINSTALL #
##############
# Remove the packages from the `remove:` section of the recipe
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh remove && \
    /ctx/cleanup

######################
# FEDORA PACKAGES  #
######################
# Base packages from the Fedora repositories (always weak-deps disabled)
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh install-base && \
    /ctx/cleanup

####################
# HYPRLAND + WWW  #
####################
# Installed while the COPR group is still enabled
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh install-hyprland && \
    /ctx/cleanup

# zed is installed from the Terra repository only
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh install-zed && \
    /ctx/cleanup

# COPR + Terra repos are disabled (as a group) once every package is baked in
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh disable-repos && \
    /ctx/cleanup

####################################
# APPLICATIONS BAKED FROM SCRIPTS  #
####################################
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install/install-vscode.sh && \
    /ctx/install/install-brave.sh && \
    /ctx/install/install-obsidian.sh && \
    /ctx/install/install-zotero.sh && \
    /ctx/install/install-pyprland.sh && \
    # /ctx/install/install-texlive.sh && \
    /ctx/install/setup-fonts.sh && \
    /ctx/install/setup-flatpaks.sh && \
    /ctx/install/setup-default-flatpaks.sh && \
    /ctx/cleanup

# Homebrew packages manifest
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install/setup-brew-packages.sh && \
    /ctx/cleanup

######################
# DOTFILES (chezmoi) #
######################
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install/setup-dotfiles.sh && \
    /ctx/cleanup

#######################
# NVIDIA (Open) DRIVER #
#######################
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=akmods-nvidia,src=/rpms,dst=/tmp/rpms/nvidia \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh verify-kernel /tmp/rpms/nvidia && \
    /ctx/install/install-nvidia.sh && \
    /ctx/cleanup

#####################
# SERVICES+FINALIZE #
#####################
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh services && \
    /ctx/image-info && \
    /ctx/build-initramfs && \
    /ctx/finalize

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint
