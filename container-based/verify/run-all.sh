#!/usr/bin/env bash
# verify/run-all.sh — one-stop local verification of everything the task list
# requires, against a built image.
#
# Usage:
#   verify/run-all.sh [IMAGE[:TAG]]          # default: localhost/halcyon:latest
#
# Host-side checks (no image needed):
#   - .github audit (verify/verify-github.sh)
#   - repo-wide syntax gates (just check, just lint)
# Image-side checks (each script is mounted into the image and executed):
#   - brew integration      (verify/verify-brew.sh)
#   - chezmoi integration   (verify/verify-chezmoi.sh)
#   - ujust/--choose        (verify/verify-ujust.sh)
set -uo pipefail

IMAGE="${1:-localhost/halcyon:latest}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
overall=0

rule() { printf '\n%s\n' "══════════════════════════════════════════════════════════════════════"; }

rule
printf 'HALCYON VERIFICATION SUITE — image: %s\n' "${IMAGE}"
rule

echo "▶ [1/5] .github audit (host-side)"
bash "${HERE}/verify-github.sh" || overall=1

echo
echo "▶ [2/5] just check (host-side)"
just check || overall=1

echo
echo "▶ [3/5] just lint (host-side)"
just lint || overall=1

if ! podman image exists "${IMAGE}"; then
  echo
  echo "⚠ image ${IMAGE} not present — skipping image-side checks (build it first: just build)"
  if [ "${overall}" -eq 0 ]; then exit 0; else exit "${overall}"; fi
fi

for checker in verify-brew.sh verify-chezmoi.sh verify-ujust.sh; do
  echo
  echo "▶ image-side: ${checker}"
  podman run --rm --entrypoint /bin/bash \
    -v "${HERE}:/verify:ro" \
    "${IMAGE}" "/verify/${checker}" || overall=1
done

rule
if [ "${overall}" -eq 0 ]; then
  echo "✔ ALL VERIFICATIONS PASSED"
else
  echo "✖ SOME VERIFICATIONS FAILED — see the FAIL lines above"
fi
rule
exit "${overall}"
