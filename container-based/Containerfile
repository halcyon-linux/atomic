# halcyon — bootc Containerfile following the ublue-os/bazzite project
# structure (https://github.com/ublue-os/bazzite): scratch `ctx` stage with
# semantic unnumbered build helpers, whole-ctx bind mount per RUN, ARG-only
# configuration, per-RUN third-party repo enable→disable, /ctx/cleanup after
# every image-mutating RUN, bootc container lint as the hermetic final gate.
#
# Build locally:
#   podman build --pull -t localhost/halcyon:latest .
#
# Verification is per-level (main-branch pattern): every install stage is
# immediately followed by its <stage>-verify companion so failures surface at
# that level. Removals run FIRST (remove-packages) — main's removals.yml
# ordering — so dnf computes the removal set on the smallest, pristine graph;
# keeper packages are gated against the FINAL state in final-verify.
#
# Every stage RUN opens with a "████ STAGE nn/17 · name · summary ████" banner
# so a human scrolling a CI log can find stage boundaries instantly; the build
# scripts themselves emit ::group:: folds + OK/FAIL prefixes inside each stage.

ARG FEDORA_VERSION=44

# --- build context: semantic helpers, never baked into the image ---
FROM scratch AS ctx
COPY build_files /
COPY packages.json /
# cosign.pub is consumed by the branding stage (sigstore policy assets)
COPY cosign.pub /

FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION}

# CI passes --build-arg for the two volatile values (bazzite convention:
# version = <fedora-major>.<yyyymmdd>, revision = git sha)
ARG IMAGE_VERSION="44.0"
ARG SOURCE_SHA="unknown"

# The repo LICENSE and every pyproject.toml are Apache-2.0; the label set must
# agree (the Justfile's io.artifacthub.package.license is kept in sync).
LABEL org.opencontainers.image.title="halcyon" \
      org.opencontainers.image.description="Lean Hyprland gaming desktop — fedora-bootc + p03 kernel + NVIDIA open (negativo17 userland) + noctalia greeter + ujust/uupd" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_SHA}" \
      org.opencontainers.image.source="https://github.com/aahsnr-work/halcyon" \
      org.opencontainers.image.url="https://github.com/aahsnr-work/halcyon" \
      org.opencontainers.image.vendor="aahsnr-work" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.authors="aahsnr-work" \
      io.artifacthub.package.readme-url="https://raw.githubusercontent.com/aahsnr-work/halcyon/container/README.md" \
      halcyon.base="fedora-bootc-p03" \
      halcyon.desktop="hyprland-noctalia"

# static system tree (configs, units, ujust modules, theme, wallpaper)
COPY system_files/shared/ /

# dnf5 patience drop-in MUST land in the first RUN — it exists to survive
# Copr 504s during the very stages that follow (libdnf5 reads
# /etc/dnf/libdnf5.conf.d/ before the main config).
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 00/17 · dnf5 patience drop-in ████" \
    && install -Dm0644 /ctx/libdnf5.conf.d/99-halcyon-retries.conf \
      /etc/dnf/libdnf5.conf.d/99-halcyon-retries.conf

# ---- Stage 1: shared external repos + jq/dnf5-plugins bootstrap ------------
# Repos come first so the removals stage can read its list from packages.json;
# jq is installed explicitly because packages-lib cannot parse it without.
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 01/17 · setup-repos · base external repos + jq ████" \
    && /ctx/base/setup-repos && /ctx/cleanup

# ---- Stage 2: removals on the near-pristine base (JSON-driven, main ordering)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 02/17 · remove-packages · removals on pristine base ████" \
    && /ctx/base/remove-packages && /ctx/cleanup

# ---- Stage 3: p03 kernel + prebuilt nvidia-open modules (Stage K1) ---------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 03/17 · install-kernel · p03 + nvidia-open (Stage K1) ████" \
    && /ctx/kernel/install-kernel && /ctx/kernel/kernel-verify && /ctx/cleanup

# ---- Stage 4: programming + core + hardware + editors + desktop + gaming + apps
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 04/17 · install-packages · programming + core + desktop + gaming + apps ████" \
    && /ctx/packages/install-packages && /ctx/packages/packages-verify && /ctx/cleanup

# ---- Stage 5: Terra packages (user-editable list, exclusive resolution) ----
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 05/17 · install-terra · Terra-only resolution ████" \
    && /ctx/packages/install-terra && /ctx/cleanup

# ---- Stage 6: devtools (Fedora brew-formula replacements) ------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 06/17 · install-devtools · Fedora devtools ████" \
    && /ctx/packages/install-devtools && /ctx/cleanup

# ---- Stage 7: Homebrew (core + the formulas Fedora/Terra lack, BAKED into a
#      /usr payload; halcyon-brew-bundle.service seeds it pre-login at boot) --
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 07/17 · install-brew-bundle · Homebrew bake ████" \
    && /ctx/brew/install-brew-bundle && /ctx/brew/brew-verify && /ctx/cleanup

# ---- Stage 8: nix (winter pattern) ------------------------------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 08/17 · install-nix · winter pattern ████" \
    && /ctx/runtime/install-nix && /ctx/runtime/nix-verify && /ctx/cleanup

# ---- Stage 9: flatpak (flathub USER repo only) ------------------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 09/17 · setup-flatpaks · flathub user repo ████" \
    && /ctx/runtime/setup-flatpaks && /ctx/runtime/flatpaks-verify && /ctx/cleanup

# ---- Stage 10: built apps (obsidian/zotero/pyprland/texlive/python) --------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 10/17 · install-built-apps · obsidian/zotero/pyprland/texlive/python ████" \
    && /ctx/apps/install-built-apps && /ctx/apps/built-apps-verify && /ctx/cleanup

# ---- Stage 11: ujust-fedora companions + recipe module registration ---------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 11/17 · setup-ujust · ujust-fedora + module registration ████" \
    && /ctx/runtime/setup-ujust && /ctx/runtime/ujust-verify && /ctx/cleanup

# ---- Stage 12: system config (services, tmpfiles, chezmoi + brew wiring) ----
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 12/17 · configure-system · units + services ████" \
    && /ctx/desktop/configure-system && /ctx/desktop/system-verify && /ctx/cleanup

# ---- Stage 13: branding (os-release identity + plymouth theme + sigstore) ---
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 13/17 · image-info · os-release + plymouth + sigstore policy ████" \
    && /ctx/desktop/image-info && /ctx/desktop/branding-verify && /ctx/cleanup

# ---- Stage 14: initramfs LAST (plymouth theme + nvidia hooks baked in) ------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 14/17 · build-initramfs · dracut for p03 ████" \
    && /ctx/finish/build-initramfs && /ctx/cleanup

# ---- Stage 15: finalize (repo sweep + end-of-build hygiene) -----------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 15/17 · finalize · repo sweep + hygiene ████" \
    && /ctx/finish/finalize

# ---- Stage 16: final cross-cutting verification ------------------------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 16/17 · final-verify · cross-cutting gates ████" \
    && /ctx/finish/final-verify

# ---- Final gate: hermetic bootc lint (bazzite pattern) -----------------------
# shell form here (not exec form) so the banner echo can share the RUN; bootc
# lint is short-lived so shell signal semantics are irrelevant.
RUN --mount=type=tmpfs,target=/run --network=none \
    echo "████ STAGE 17/17 · bootc container lint · hermetic final gate ████" \
    && bootc container lint
