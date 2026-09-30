# halcyon — repo task runner (adapted from ublue-os/image-template's Justfile;
# ISO/bootc-image-builder recipes deliberately omitted — see MIGRATION.md).
set dotenv-filename := "halcyon.env"

export image_name := env_var("IMAGE_NAME")
export repo_organization := env_var("REPO_ORGANIZATION")
export image_desc := env_var("IMAGE_DESC")
export image_keywords := env_var("IMAGE_KEYWORDS")
export image_logo_url := env_var("IMAGE_LOGO_URL")
export default_tag := env_var("DEFAULT_TAG")
export fedora_version := env_var("FEDORA_VERSION")

default:
    @just --list

# Check Justfile + all build_files scripts + recipe bodies + verify helpers
[group('Just')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    status=0
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile || status=1

    echo "::group::bash -n — build_files scripts"
    while read -r file; do
        echo "Checking syntax: $file"
        bash -n "$file" || status=1
    done < <(find build_files -type f \
               ! -path "*libdnf5.conf.d*" ! -path "*python-packages*" \
               ! -name "*.json" ! -name "README*")
    echo "::endgroup::"

    echo "::group::packages.json — validity + group-consumer consistency"
    # jq rejects comments and malformed JSON; packages_validate would only
    # surface that at Stage 02 of a ~40-minute build. Catch it here, and catch
    # the dangling-group-name class at the same time: every group build_files
    # consume via packages_for (and flatpak key via flatpak_apps) must exist
    # in the catalog.
    if jq -e . packages.json >/dev/null; then
        echo "packages.json parses — OK"
    else
        echo "packages.json is NOT valid JSON (comments break jq — notes belong in _docs)"
        status=1
    fi
    while read -r group; do
        if jq -e --arg g "${group}" '.all.include | has($g)' packages.json >/dev/null; then
            echo "group '${group}' present — OK"
        else
            echo "packages.json: build_files consume group '${group}' but all.include has no such key"
            status=1
        fi
    done < <(grep -rhoE 'packages_for [A-Za-z0-9_-]+' build_files | awk '{print $2}' | sort -u)
    while read -r key; do
        if jq -e --arg k "${key}" '.flatpak | has($k)' packages.json >/dev/null; then
            echo "flatpak key '${key}' present — OK"
        else
            echo "packages.json: build_files consume flatpak key '${key}' but .flatpak has no such key"
            status=1
        fi
    done < <(grep -rhoE 'flatpak_apps [A-Za-z0-9_-]+' build_files | awk '{print $2}' | sort -u)
    echo "::endgroup::"

    echo "::group::bash -n — verify/ helpers + workflow shell code"
    for file in verify/*.sh .github/log-helpers.sh; do
        [ -e "$file" ] || continue
        echo "Checking syntax: $file"
        bash -n "$file" || status=1
    done
    echo "::endgroup::"

    echo "::group::recipe bodies — parse + bash -n (ujust runtime syntax)"
    for module in system_files/shared/usr/share/ublue-os/just/*.just; do
        just --justfile "$module" --list >/dev/null 2>&1 \
            || { echo "Recipe module does not parse: $module"; status=1; continue; }
        for recipe in $(just --justfile "$module" --summary); do
            body="$(just --justfile "$module" --show "$recipe" 2>/dev/null)" || continue
            # just --show prints attributes ([group(...)]), the recipe header,
            # then the body; bodies are bash shebang scripts — take everything
            # from the first `#!` line on (empty for non-script recipes, and
            # `bash -n` passes on empty input).
            if printf '%s\n' "$body" | awk 'f{print} /^#!/{f=1}' | bash -n; then
                echo "Checking recipe: $(basename "$module")::$recipe — OK"
            else
                echo "Recipe body FAILED bash -n: $(basename "$module")::$recipe"
                status=1
            fi
        done
    done
    echo "::endgroup::"

    exit "$status"

# Fix Justfile formatting
[group('Just')]
fix:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt -f Justfile

# Lint every build_files script with shellcheck (extensionless bash)
[group('Just')]
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v shellcheck >/dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    status=0
    # while-read + explicit status accumulation: `find -exec` would report
    # only the LAST invocation's exit code and silently mask earlier failures.
    # -x follows `# shellcheck source=` directives. ShellCheck resolves those
    # relative to its WORKING DIRECTORY (the repo root, where this recipe runs),
    # which is why the directives read build_files/packages-lib.
    while read -r file; do
        if shellcheck --shell=bash -x "$file"; then
            echo "shellcheck OK: $file"
        else
            echo "shellcheck FAILED: $file"
            status=1
        fi
    done < <(find build_files -type f \
        ! -path "*libdnf5.conf.d*" ! -path "*python-packages*" \
        ! -name "*.json" ! -name "README*")
    exit "$status"

# Static-check the python helpers for undefined names and syntax errors
[group('Just')]
lint-python:
    #!/usr/bin/env bash
    set -euo pipefail
    cd build_files/python-packages
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip ruff
    # F821/F822/F823 = undefined names — the bug class that shipped in `rmi`
    # (a missing `datetime` import). The build-time `-h` smoke test never
    # reaches that code and py_compile only checks syntax, so neither sees it.
    # E9 = syntax errors.
    .venv/bin/ruff check --select E9,F821,F822,F823 .

# Run the python helper test suites (not reached by check/lint)
[group('Just')]
test-python:
    #!/usr/bin/env bash
    set -euo pipefail
    cd build_files/python-packages
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip
    for pkg in dump-to-markdown rmi; do
        echo "::group::pytest — ${pkg}"
        .venv/bin/pip install --quiet -e "./${pkg}[dev]"
        .venv/bin/pytest "${pkg}"
        echo "::endgroup::"
    done

# Audit the .github tree (host-side; no image required)
[group('Just')]
check-github:
    #!/usr/bin/env bash
    set -euo pipefail
    bash verify/verify-github.sh

# Build the container image with the CI label scheme
[group('Build')]
build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail

    BUILD_ARGS=()
    LABELS=()
    GIT_SHA=$(git rev-parse --short HEAD)
    # consumed by the Containerfile ARGs (bazzite convention:
    # version = <fedora-major>.<yyyymmdd>, revision = git sha)
    BUILD_ARGS+=("--build-arg" "FEDORA_VERSION=${fedora_version}")
    BUILD_ARGS+=("--build-arg" "IMAGE_VERSION=${fedora_version}.$(date +%Y%m%d)")
    BUILD_ARGS+=("--build-arg" "SOURCE_SHA=${GIT_SHA}")

    if [[ -z "$(git status -s)" ]]; then
        LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ repo_organization }}/{{ image_name }}/${GIT_SHA}/README.md")
        LABELS+=("--label" "org.opencontainers.image.version={{ default_tag }}.$(date +%Y%m%d)-${GIT_SHA}")
    fi
    LABELS+=("--label" "io.artifacthub.package.deprecated=false")
    LABELS+=("--label" "io.artifacthub.package.keywords={{ image_keywords }}")
    # Must match LICENSE and the Containerfile's org.opencontainers.image.licenses
    LABELS+=("--label" "io.artifacthub.package.license=Apache-2.0")
    LABELS+=("--label" "io.artifacthub.package.logo-url={{ image_logo_url }}")
    LABELS+=("--label" "io.artifacthub.package.prerelease=false")
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    LABELS+=("--label" "org.opencontainers.image.description={{ image_desc }}")
    LABELS+=("--label" "org.opencontainers.image.title={{ image_name }}")
    LABELS+=("--label" "org.opencontainers.image.vendor={{ repo_organization }}")

    podman build "${BUILD_ARGS[@]}" "${LABELS[@]}" \
        --pull=newer --platform linux/amd64 \
        --tag "${target_image}:${tag}" --file Containerfile .

# Run the image-side verification suite against a built image
[group('Build')]
verify-image $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    status=0
    for checker in verify-brew.sh verify-chezmoi.sh verify-ujust.sh; do
        echo "::group::image-side — ${checker}"
        podman run --rm --entrypoint /bin/bash \
            -v "$PWD/verify:/verify:ro" \
            "${target_image}:${tag}" "/verify/${checker}" || status=1
        echo "::endgroup::"
    done
    exit "$status"

# Generate the full alias-tag set (template scheme)
# Image Name (template recipe — CI resolves the image name through it)
[group('Utility')]
[private]
image_name $target_image=image_name:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "${target_image}"

[group('Utility')]
generate-default-tag $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail
    echo "${tag}"

[group('Utility')]
generate-build-tags $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail

    DATE=$(date +%Y%m%d)
    BUILD_TAGS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        BUILD_TAGS+=("${tag}-${GIT_SHA}")
        BUILD_TAGS+=("${tag}-${DATE}-${GIT_SHA}")
        BUILD_TAGS+=("${DATE}-${GIT_SHA}")
    fi
    BUILD_TAGS+=("${DATE}")
    BUILD_TAGS+=("${tag}")
    BUILD_TAGS+=("${tag}-${DATE}")
    BUILD_TAGS+=("${fedora_version}")
    BUILD_TAGS+=("${DATE}-${fedora_version}")

    echo "${BUILD_TAGS[@]}"

# Re-tag one built image with the whole alias set
[group('Utility')]
tag-images $target_image=image_name $tag=default_tag tags="":
    #!/usr/bin/env bash
    set -euox pipefail

    IMAGE=$(podman inspect ${target_image}:${tag} | jq -r .[].Id)
    podman untag ${IMAGE}
    for tag in {{ tags }}; do
        podman tag $IMAGE "${target_image}:${tag}"
    done
    podman images

# Report the installed package count of a built image (mirrors the CI step)
[group('Utility')]
package-count $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail
    INFO=$(podman run --rm --entrypoint /bin/bash "${target_image}:${tag}" -c \
        'echo "count=$(rpm -qa | wc -l)"; echo "kernel=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel-p03 2>/dev/null || echo n/a)"')
    COUNT=$(sed -n 's/^count=//p' <<< "${INFO}")
    KVER=$(sed -n 's/^kernel=//p' <<< "${INFO}")
    echo "total installed RPM packages: ${COUNT}"
    echo "p03 kernel: ${KVER}"
