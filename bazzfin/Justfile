# Developer conveniences for building/testing the image locally with the
# BlueBuild CLI: https://blue-build.org/how-to/local/
# Install it first (see the CLI README for options), e.g.:
#   cargo install --locked blue-build

set shell := ["/usr/bin/bash", "-cu"]

# Print/save the Containerfile that would be generated from the recipe
@generate recipe="recipe.yml":
    bluebuild generate recipes/{{ recipe }} -o Containerfile

# Build the image locally with podman/buildah
@build recipe="recipe.yml":
    bluebuild build recipes/{{ recipe }}

# Validate recipes/recipe.yml against the BlueBuild schema
@validate recipe="recipe.yml":
    bluebuild validate recipes/{{ recipe }}

# Build, then rebase this machine onto the local build (rpm-ostree/bootc)
@switch recipe="recipe.yml":
    bluebuild switch recipes/{{ recipe }}

# Shellcheck all bash scripts. (build-initramfs.sh was removed here --
# initramfs regeneration is now handled by the `initramfs` module in
# recipe.yml instead of a hand-rolled script.) Restricted to *.sh so a
# future non-script file dropped into files/scripts/ doesn't get lint-checked.
@lint:
    find files/scripts -type f -name '*.sh' -exec shellcheck {} +

# Publish wiki/ to the GitHub wiki (bazzfin.wiki.git). Requires push access
# (gh auth or the git@ remote). Creates a first commit in the wiki repo if
# it is empty. One-time alternative: initialize the wiki via the GitHub UI.
@wiki-push org="aahsnr-work" repo="bazzfin":
    #!/usr/bin/bash
    set -euo pipefail

    WIKI_URL="git@github.com:{{ org }}/{{ repo }}.wiki.git"
    HTTPS_URL="https://github.com/{{ org }}/{{ repo }}.wiki.git"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    if git clone --quiet "$WIKI_URL" "$TMP/wiki" 2>/dev/null; then
        echo "cloned $WIKI_URL"
    elif git clone --quiet "$HTTPS_URL" "$TMP/wiki" 2>/dev/null; then
        echo "cloned $HTTPS_URL"
    else
        # Empty wiki repos have no branches; init one manually.
        git init -q -b master "$TMP/wiki"
        echo "initialized a fresh wiki repo at $TMP/wiki"
    fi

    # Copy every page except README.md (repo-side meta doc, not a wiki page)
    find wiki -maxdepth 1 -name '*.md' ! -name README.md -exec cp {} "$TMP/wiki/" ;
    cd "$TMP/wiki"
    git add -A
    if git diff --cached --quiet; then
        echo "wiki already up to date; nothing to push"
        exit 0
    fi
    git -c user.name=bazzfin-wiki -c user.email="wiki@localhost" \
        commit -q -m "Publish wiki from source repo ($(date -u +%Y-%m-%dT%H:%MZ))"
    git push -q origin master 2>/dev/null || git push -q origin main
    echo "wiki published: https://github.com/{{ org }}/{{ repo }}/wiki"
