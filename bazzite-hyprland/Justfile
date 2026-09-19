image_name := "bazzite-hyprland"
default_tag := "latest"

# Build image locally using the BlueBuild CLI
build:
    bluebuild build recipes/recipe.yml

# Validate and lint the BlueBuild recipe file
validate:
    @if command -v bluebuild >/dev/null 2>&1; then \
        bluebuild validate recipes/recipe.yml; \
    else \
        podman run --rm -v "$PWD":/work:Z -w /work ghcr.io/blue-build/cli:latest bluebuild validate recipes/recipe.yml; \
    fi

# Dry-run: Generate the compiled Containerfile from the recipe without building
dry-run:
    @if command -v bluebuild >/dev/null 2>&1; then \
        bluebuild generate recipes/recipe.yml; \
    else \
        podman run --rm -v "$PWD":/work:Z -w /work ghcr.io/blue-build/cli:latest bluebuild generate recipes/recipe.yml; \
    fi

# Switch this machine to the locally-built image (must already be on a bootc/rpm-ostree system; run as root)
switch tag=default_tag:
    bootc switch --transport containers-storage "localhost/{{image_name}}:{{tag}}"

# Run all lint and syntax checks (shell scripts and BlueBuild recipe)
check:
    bash -n files/scripts/*.sh
    @just validate

