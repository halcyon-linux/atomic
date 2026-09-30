#!/usr/bin/env bash
# verify/verify-brew.sh — run INSIDE the built image (or container) to verify
# the Homebrew integration end-to-end:
#   podman run --rm --entrypoint /bin/bash -v "$PWD/verify:/verify:ro" \
#     localhost/halcyon:latest /verify/verify-brew.sh
set -uo pipefail

fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then printf '  PASS  %s\n' "$desc"; else printf '  FAIL  %s\n' "$desc"; fail=1; fi; }

echo "::group::verify-brew — baked payload"
gate "brew payload present"           test -s /usr/share/halcyon/brew-bundle.tar.zst
gate "Brewfile shipped"               test -s /usr/share/ublue-os/homebrew/Brewfile
formula_count=$(grep -cE '^[[:space:]]*brew "?[^" ]+"?' /usr/share/ublue-os/homebrew/Brewfile 2>/dev/null || echo 0)
echo "  INFO  Brewfile formulas: ${formula_count}"
gate "Brewfile non-empty"             test "${formula_count}" -gt 0
gate "brew core inside payload"       sh -c 'tar --zstd -tf /usr/share/halcyon/brew-bundle.tar.zst 2>/dev/null | grep -qF "home/linuxbrew/.linuxbrew/bin/brew"'
echo "::endgroup::"

echo "::group::verify-brew — every Brewfile formula poured in the payload"
PAYLIST="$(mktemp)"; trap 'rm -f "${PAYLIST}"' EXIT
tar --zstd -tf /usr/share/halcyon/brew-bundle.tar.zst >"${PAYLIST}" 2>/dev/null
while IFS= read -r name; do
  [ -z "${name}" ] && continue
  receipts=$(grep -F "Cellar/${name}/" "${PAYLIST}" | grep -cF "INSTALL_RECEIPT.json" || true)
  if [ "${receipts}" -gt 0 ]; then
    printf '  PASS  Cellar/%s (%s receipt(s))\n' "${name}" "${receipts}"
  else
    printf '  FAIL  Cellar/%s missing/incomplete\n' "${name}"
    fail=1
  fi
done < <(sed -nE 's/^[[:space:]]*brew "?([^" ]+)"?.*/\1/p' /usr/share/ublue-os/homebrew/Brewfile | sed 's|^.*/||')
echo "::endgroup::"

echo "::group::verify-brew — units + helpers + environment"
gate "halcyon-brew-bundle.service"    test -f /usr/lib/systemd/system/halcyon-brew-bundle.service
gate "brew-bundle.service (user)"     test -f /usr/lib/systemd/user/brew-bundle.service
gate "brew-update.service/.timer"     sh -c 'test -f /usr/lib/systemd/system/brew-update.service && test -f /usr/lib/systemd/system/brew-update.timer'
gate "brew-upgrade.service/.timer"    sh -c 'test -f /usr/lib/systemd/system/brew-upgrade.service && test -f /usr/lib/systemd/system/brew-upgrade.timer'
gate "boot extractor executable"      test -x /usr/libexec/halcyon-image/brew-bundle-extract
gate "login fallback executable"      test -x /usr/libexec/halcyon-image/brew-bundle-install
gate "environment.d PATH"             grep -q 'linuxbrew/.linuxbrew/bin' /etc/environment.d/10-homebrew.conf
gate "profile.d interactive hook"     test -f /etc/profile.d/brew.sh
gate "tmpfiles runtime dirs"          grep -q 'var/home/linuxbrew' /usr/lib/tmpfiles.d/zz-halcyon-homebrew.conf
gate "seeding unit enabled"           systemctl is-enabled halcyon-brew-bundle.service
gate "update timer enabled"           systemctl is-enabled brew-update.timer
gate "upgrade timer enabled"          systemctl is-enabled brew-upgrade.timer
gate "no /home/linuxbrew in layer"    test ! -e /home/linuxbrew
gate "no /var/home/linuxbrew"         test ! -e /var/home/linuxbrew
echo "::endgroup::"

if [ "${fail}" -eq 0 ]; then
  echo "--- verify-brew: ALL CHECKS PASSED ---"
  exit 0
fi
echo "::error::verify-brew FAILED"
exit 1
