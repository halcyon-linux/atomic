# halcyon

[![Build halcyon image](https://github.com/aahsnr-work/halcyon/actions/workflows/build.yml/badge.svg?branch=container)](https://github.com/aahsnr-work/halcyon/actions/workflows/build.yml)

A lean, Hyprland-first gaming desktop built as a **bootc Containerfile** in the
[ublue-os/bazzite](https://github.com/ublue-os/bazzite) project structure —
built on `quay.io/fedora/fedora-bootc` with the **p03 kernel**
([CatPieLeaf/linux-p03](https://github.com/CatPieLeaf/linux-p03)) and its
prebuilt **NVIDIA-open modules**, the NVIDIA userland from
[negativo17](https://negativo17.org) (no akmods/DKMS anywhere), the
**Hyprland + Noctalia** desktop with **greetd + noctalia-greeter** login, the
Bazzite gaming stack as native RPMs, and ujust/uupd machinery from
`ublue-os-just` — rebuilt daily, calm by definition.

> **Image:** `ghcr.io/aahsnr-work/halcyon:latest` (`linux/amd64`)
> **Verification:** `cosign verify --key cosign.pub ghcr.io/aahsnr-work/halcyon`

---

## Install / rebase

**Rebase from an existing Atomic desktop (Bazzite/Silverblue/Bluefin/Kinoite):**

```bash
# 1. rebase to the unsigned image first
rpm-ostree rebase ostree-unverified-registry:ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
# 2. after reboot, switch to the signed tag
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
```

On a bootc system: `sudo bootc switch ghcr.io/aahsnr-work/halcyon:latest`.
Or from the running system: `ujust rebase-to-custom`.

**Signatures.** Images are signed with Cosign in the _legacy_ `.sig`
attachment format, because that is the only format containers/image (podman,
skopeo, bootc) can discover. Cosign 3 defaults to a newer referrer format that
`cosign verify` accepts but `bootc` cannot see; the workflow forces the legacy
format and verifies it after signing. The image ships the public key at
`/etc/pki/containers/halcyon.pub` and a `sigstoreSigned` policy for
`ghcr.io/aahsnr-work/halcyon`.

---

## What this image is

Boot → greetd/noctalia-greeter → Hyprland → Noctalia first-run wizard.

- **Kernel + GPU:** `kernel-p03` + `kernel-p03-nvidia-open` from COPR
  `catpieleaf/kernel-p03` (ABI-matched, zero akmods/DKMS); NVIDIA userland
  from negativo17 on the exact same 615.71.09 driver line — RPM Fusion repos
  **exclude NVIDIA packages** so the two conflicting driver chains can never
  mix (the ublue-os/akmods partition). SELinux stays **enforcing** (`p03`
  keeps `CONFIG_SECURITY_SELINUX=y`; `nvidia-driver-selinux` policy installed).
- **Desktop:** `hyprland-git`, `noctalia-git`, `noctalia-greeter-git`,
  `xdg-desktop-portal-{hyprland,gtk}` from COPR `lionheartp/Hyprland`;
  greetd login (tty2 escape hatch); kitty, thunar, papers, gnome-keyring.
- **Gaming:** `steam` (with the bazzite-steam wrappers and desktop-entry
  wiring), `gamescope`, `mangohud` (+i686), `gamemode`, `lutris`,
  `scx-scheds`/`scx-tools`, `umu-launcher`, `bazaar`, `bazzite-portal`,
  `input-remapper`, `usbip`, 32-bit NVIDIA + mesa libraries.
- **Apps:** VS Code, Brave, zen-browser (from Terra; per-use vendor/COPR repo
  files are removed again at finalize), zed, emacs-pgtk, neovim; Obsidian,
  Zotero, Pyprland, TeX Live and a Python helper family baked at build time.
- **Tooling:** the former brew formulas as RPMs (bat, eza, fzf, lazygit,
  ripgrep, starship, yazi, zellij, …) **plus a small baked Homebrew payload**
  — only `bun`, `pixi` and `opencode`, the formulas Fedora and Terra do not
  ship — brewed at build time into `/usr/share/halcyon/brew-bundle.tar.zst`
  and seeded pre-login, offline, by `halcyon-brew-bundle.service`. chezmoi
  (Fedora RPM) is wired to
  [aahsnr-configs/dotfiles](https://github.com/aahsnr-configs/dotfiles)
  (first-login init + update timer, blue-build module semantics), nix via the
  [fu5ha/winter](https://github.com/fu5ha/winter) bind-mount pattern, and
  ujust/uupd (`ublue-os-just` + `uupd`) with curated Bazzite recipes.
- **Flatpak:** package + **flathub user repo only** (no system flathub, no
  Fedora flatpaks); four transition apps install per-user at first login —
  everything else is native RPM.

---

## Repo structure

`build_files/` has one folder per build phase; the **Containerfile is the
single source of ordering truth** — the folders carry no numbering.

```
├── Containerfile              # 18 RUN stages (banners 00–17) + hermetic bootc lint
├── Justfile                   # check / lint / lint-python / test-python / build / verify-image
├── halcyon.env                # dotenv consumed by the Justfile
├── packages.json              # SINGLE SOURCE OF TRUTH for every dnf/flatpak package
├── cosign.pub                 # public signing key (shipped to /etc/pki/containers)
├── build_files/               # the `ctx` stage — never ends up in the image
│   ├── packages-lib           #   jq accessors the stages source (fail-fast)
│   ├── cleanup                #   end-of-RUN temp/log//boot wipe
│   ├── libdnf5.conf.d/        #   dnf5 retry drop-in (installed in Stage 00)
│   ├── base/                  #   setup-repos, remove-packages
│   ├── kernel/                #   install-kernel + kernel-verify (p03 + nvidia-open)
│   ├── packages/              #   install-packages / -terra / -devtools + packages-verify
│   ├── brew/                  #   install-brew-bundle + brew-verify
│   ├── runtime/               #   install-nix, setup-flatpaks, setup-ujust + verifies
│   ├── apps/                  #   obsidian/zotero/pyprland/texlive/python + verify
│   ├── desktop/               #   configure-system, image-info, plymouth + verifies
│   ├── finish/                #   build-initramfs, finalize, final-verify
│   └── python-packages/       #   11 stdlib-only src-layout Python tools
├── system_files/shared/       # root overlay COPYed into the image
└── verify/                    # image-side suites CI runs against the built image
```

Every third-party repo is enabled only inside the stage that consumes it and
disabled immediately after; `finalize` sweeps any leftovers so the shipped
image carries Fedora repos only.

---

## Adding or removing packages (packages.json)

**`packages.json` (repo root) is the single source of truth** for every
package in the image — dnf and flatpak alike, in the
[ublue-os/main](https://github.com/ublue-os/main) style. The build stages
never hardcode package lists: each stage sources `build_files/packages-lib`
and reads its group with jq, and the build **fails fast** if the JSON is
malformed.

Groups are keyed by **the repo a package resolves from**, not by what it does.

| Group                                  | Resolved from                                                 | Consumed by       |
| -------------------------------------- | ------------------------------------------------------------- | ----------------- |
| `programming`                          | Fedora                                                        | install-packages (FIRST) |
| `core`                                 | Fedora                                                        | install-packages  |
| `hardware`                             | Fedora                                                        | install-packages  |
| `editors`                              | Fedora                                                        | install-packages  |
| `desktop`                              | COPR `lionheartp/Hyprland`                                    | install-packages  |
| `gaming`                               | Fedora + RPM Fusion                                           | install-packages  |
| `ublueos-packages`                     | COPR `ublue-os/packages`                                      | install-packages  |
| `vendor-apps`                          | per-use vendor repos (VS Code, Brave)                         | install-packages  |
| `cli-tools` / `devtools` / `misc`      | Fedora                                                        | install-devtools  |
| `nix`                                  | Fedora                                                        | install-nix       |
| `flatpak`                              | Fedora                                                        | setup-flatpaks    |
| `ujust-fedora`                         | Fedora                                                        | setup-ujust       |
| `terra`                                | **Terra only** (`--disablerepo='*'`)                          | install-terra     |
| `all.exclude.all`                      | removals — resolved through `rpm -qa`, absent names tolerated | remove-packages   |
| `flatpak.install` / `flatpak.remove`   | Flathub (user repo, at first login)                           | setup-flatpaks    |

**To add a package:** put its name in the group matching the repo it resolves
from, then rebuild (`just build localhost/halcyon latest`). Only if a brand-new
repo is needed do you also add a group here and a matching enable→install→
disable window in the consuming stage. **To remove one:** delete it from its
group (and, if the base might ship it, add it to `all.exclude.all`).

Rules the stages enforce while consuming the catalog:

- weak deps are **off** on every install — list any former weak dep explicitly;
- `terra` groups resolve **exclusively** from Terra (`--disablerepo='*'`) —
  a missing package fails the build rather than silently falling back;
- third-party repos are enabled only inside the stage that consumes them,
  disabled immediately after, and deleted by `finalize`;
- the comps group `@custom-environment` and the Terra repo-bootstrap packages
  (`terra-release*`) stay in their scripts — they are not catalog entries;
- a few entries exist purely as **build-tool preconditions** (`zstd`,
  `util-linux-core`, `gnupg2`, `jq`, `gcc-c++`) — `packages-verify` gates them
  so they cannot be pruned as "unused".

---

## Build & CI

- `lint.yml` (PR, push, manual): `just check` + `just lint`, the `.github`
  audit (`verify/verify-github.sh`), actionlint, ruff (undefined names) and the
  Python helper test suites.
- `semantic-pr.yml`: validates PR titles against Conventional Commits.
- `build.yml` (daily cron 08:00 UTC, push, PR, manual): polls the consumed
  COPRs, frees runner disk, runs both syntax gates, builds with
  `podman build --pull`, runs the **image-side verify suite**
  (`verify/verify-{brew,chezmoi,ujust}.sh`), writes a package-count report, and
  — only on the `container` branch and never on PRs — pushes to GHCR, signs
  with Cosign (legacy format) and verifies the signature.
- **Scheduled runs only fire from the repository's default branch.** For the
  daily rebuild to run _this_ workflow, `container` must be the default branch
  (Settings → Branches).
- Workflows are pinned to `ubuntu-24.04`. `ubuntu-latest` migrates to 26.04
  between 2026-10-19 and 2026-11-19; test `ubuntu-26.04` deliberately first.
- Local test build: `just build localhost/halcyon latest`, then
  `just verify-image localhost/halcyon latest`.
- OCI labels (`org.opencontainers.image.*`) come from
  `--build-arg IMAGE_VERSION=<fedora>.<date>` and `SOURCE_SHA=<git sha>`.
  `bootc container lint` runs network-isolated as the final gate.

---

## Credits & licenses

Apache-2.0 — see `LICENSE`.

- [Universal Blue](https://universal-blue.org) & [Bazzite](https://bazzite.gg)
  (Apache-2.0) — the project structure this repo follows and the gaming stack.
- [CatPieLeaf/linux-p03](https://github.com/CatPieLeaf/linux-p03) — the p03
  kernel and its prebuilt NVIDIA-open modules.
- [negativo17](https://negativo17.org) — NVIDIA userland.
- [fu5ha/winter](https://github.com/fu5ha/winter) (Apache-2.0) — the nix
  bind-mount pattern.
- [lionheartp/Hyprland COPR](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/)
  — Hyprland, Noctalia and friends.
- [noctalia](https://github.com/noctalia-dev/noctalia) — the desktop and greeter.
- [blue-build/modules](https://github.com/blue-build/modules) — the
  default-flatpaks behavior our first-login flatpak setup mirrors.
- [greetd](https://git.sr.ht/~kennylevinsen/greetd).
