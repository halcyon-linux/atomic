# vim: set ft=make :

alias update-image := rebase

# Rebase this machine onto the latest build of the image
[group("system")]
rebase tag="latest":
    #!/usr/bin/bash
    set -euo pipefail

    INFO="/usr/share/ublue-os/image-info.json"
    if [[ ! -f "$INFO" ]]; then
        echo "image-info.json not found; can't determine image" >&2
        exit 1
    fi

    NAME="$(jq -r '.image-name' "$INFO")"
    VENDOR="$(jq -r '.image-vendor' "$INFO")"
    REF="ghcr.io/${VENDOR}/${NAME}"
    TAG="{{ tag }}"

    if command -v bootc >/dev/null 2>&1; then
        if [[ "$TAG" == "latest" ]]; then
            echo "Running: sudo bootc upgrade"
            sudo bootc upgrade
        else
            echo "Running: sudo bootc switch ostree-image-signed:docker://${REF}:${TAG}"
            sudo bootc switch "ostree-image-signed:docker://${REF}:${TAG}"
        fi
    else
        if [[ "$TAG" == "latest" ]]; then
            echo "Running: sudo rpm-ostree upgrade"
            sudo rpm-ostree upgrade
        else
            echo "Running: sudo rpm-ostree rebase ostree-image-signed:docker://${REF}:${TAG}"
            sudo rpm-ostree rebase "ostree-image-signed:docker://${REF}:${TAG}"
        fi
    fi

    echo
    echo "Rebase complete. A reboot is required to boot the new image:"
    echo "  systemctl reboot"
