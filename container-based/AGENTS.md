# AGENTS.md — halcyon

Guidance for AI coding agents (and humans) working in this repository.
Branch of record: `container`.

Task-level procedures live in **`SKILLS.md`** — read this file first, then
consult `SKILLS.md` when your task matches one of its skills.

---

## 1. What this repo is

`halcyon` builds a **single bootc OCI image**: a lean Hyprland gaming desktop on
`quay.io/fedora/fedora-bootc:44` (`ARG FEDORA_VERSION=44`, mirrored by
`FEDORA_VERSION=44` in `halcyon.env`), with the `catpieleaf/kernel-p03` kernel,
prebuilt `nvidia-open` modules, negativo17 NVIDIA userland, the noctalia greeter
on greetd, and `ujust`/`uupd` for user-facing system tasks.

It is **not** a BlueBuild project and **not** layered on Bazzite. It borrows
Bazzite's _repo structure_ (scratch `ctx` stage, semantic unnumbered build
scripts, per-RUN bind mount, `/ctx/cleanup` after every mutating RUN —
`finalize` is the one exception, it is itself the hygiene sweep — and `bootc
container lint` as the hermetic final gate) and vendors some Bazzite `.just`
recipes and Steam wrappers (`bazzite-steam*`), but the base is plain
`fedora-bootc`.

The GitHub workflow builds with `podman build` via the Justfile. There is no
BlueBuild action anywhere in `.github/` of this branch — `verify-github.sh`
fails the build if one appears. If you see one, you are on `main` (the older,
Bazzite-layered branch that this branch replaced), or a scheduled run is
executing the repository's **default** branch's workflow instead of
`container`'s.

Output: `ghcr.io/aahsnr-work/halcyon:<tag>`, cosign-signed in CI using the
legacy sigstore format (§4.10). `build.yml` publishes only from
`PUBLISH_BRANCH` (`container`).

---

## 2. Repository layout

```
Containerfile              # 18 RUN stages (banners 00–17) + hermetic bootc lint
Justfile                   # check / lint / lint-python / test-python / check-github /
                           #   build / verify-image / generate-build-tags / …
halcyon.env                # dotenv consumed by the Justfile (FEDORA_VERSION, IMAGE_NAME, …)
packages.json              # single source of truth for every dnf/flatpak package (+ _docs notes)
cosign.pub                 # public signing key — COPY'd into ctx, installed by image-info
.containerignore           # keeps docs/notes/verify/.github out of the build context
README.md                  # user-facing readme
TODO.md                    # task checklist (design doc)
notes/                     # ad-hoc helper scripts (gpg-sign.sh); never shipped

build_files/               # the `ctx` stage — NEVER ends up in the image
  packages-lib             # jq accessors every stage sources (packages_for, packages_excludes, …)
  cleanup                  # end-of-RUN hygiene; called after every mutating RUN except finalize
  libdnf5.conf.d/          # dnf5 retry drop-in (installed in Stage 00 — must stay the first RUN)
  base/                    # setup-repos, remove-packages
  kernel/                  # install-kernel, kernel-verify
  packages/                # install-packages, install-terra, install-devtools, packages-verify
  brew/                    # install-brew-bundle, brew-verify
  runtime/                 # install-nix, setup-flatpaks, setup-ujust + *-verify
  apps/                    # install-built-apps + sub-installers, built-apps-verify
  desktop/                 # configure-system, image-info, build-plymouth-assets,
                           #   system-verify, branding-verify
  finish/                  # build-initramfs, finalize, final-verify
  python-packages/         # 11 stdlib-only src-layout Python tools (dump-to-markdown, fconf,
                           #   fe, ff, fkill, fp, fssh, rmi, rmtmp, screenshot, se)

system_files/shared/       # static tree COPY'd to / BEFORE any RUN stage
verify/                    # run-all.sh + image-side suites (brew/chezmoi/ujust) +
                           #   host-side .github audit (verify-github.sh)
.github/                   # build / lint / clean / semantic-pr workflows + dependabot/renovate/helpers
```

**Paths in scripts are `/ctx/<folder>/<script>`** — the ctx stage copies
`build_files/` to `/` and puts `packages.json` and `cosign.pub` at the root, so
`build_files/apps/install-obsidian` is `/ctx/apps/install-obsidian` and the
catalog is read from `/ctx/packages.json`.

---

## 3. Commands

```bash
just check          # just --fmt --check, bash -n over build_files + verify + .just recipe bodies,
                    #   packages.json validity + group-consumer consistency
just lint           # shellcheck --shell=bash -x over every build_files script
just lint-python    # ruff (E9 + F821/F822/F823) over the python helpers
just test-python    # pytest suites for the python helpers that have them (dump-to-markdown, rmi)
just check-github   # host-side .github audit (verify/verify-github.sh)
just build          # podman build with the CI label/ARG scheme
just verify-image   # run verify/verify-{brew,chezmoi,ujust}.sh inside the built image
just package-count  # run the built image, report RPM count + kernel version
```

**Always run `just check` and `just lint` before proposing a change to anything
under `build_files/`.** A missing `fi` or an unquoted expansion in a build
script costs a full ~40-minute CI build.

---

## 4. Build architecture — rules that must not be broken

1. **Stage order is load-bearing (stages 00–17, banners `nn/17`).** The dnf5
   retry drop-in lands in Stage 00 — it exists to survive Copr 504s during the
   very stages that follow. `setup-repos` runs next (it bootstraps `jq`, which
   `packages-lib` needs to read `packages.json`); removals run against the
   near-pristine base; the initramfs is built _last_ (so the plymouth theme and
   NVIDIA dracut hooks are baked in); `finalize` and `final-verify` close the
   build; the hermetic `bootc container lint` is the final gate.

2. **Every mutating `RUN` ends with `/ctx/cleanup`.** The single exception is
   `finalize` (Stage 15) — it IS the end-of-build hygiene sweep (third-party
   repo files, `keepcache=0`, `/tmp` + logs + `/boot` + caches) and nothing is
   left to clean after it. `final-verify` and the bootc lint mutate nothing and
   do not call it either.

3. **`--setopt=install_weak_deps=False` on every `dnf5 install`.** Anything that
   used to arrive as a weak dependency must be listed explicitly (e.g.
   `flatpak-selinux`, `hyprland-guiutils`, the xdg portals, `qt6ct`,
   `nwg-look`).

4. **Third-party repo lifecycle: enable → consume → disable, inside one stage.**
   `finalize` is the belt-and-braces sweep that deletes every third-party repo
   file (Copr, vscode, brave, terra, negativo17, rpmfusion); `final-verify`
   asserts that only Fedora repo files remain. The shipped image carries no
   third-party repo files — updates arrive via image rebuilds (bootc).

5. **NVIDIA comes from negativo17 only** (RPM Fusion's nvidia chain is
   excludepkgs'd in `setup-repos`). Four negativo17 subpackages
   (`nvidia-driver`, `nvidia-driver-cuda`, `nvidia-settings`,
   `nvidia-kmod-common`) are dependency-entangled with a kmod package and are
   **payload-extracted via `rpm2cpio`**, not installed. Do not "fix" this by
   adding them to a `dnf5 install` line — it pulls `dkms-nvidia`, which
   `Conflicts` with `kernel-p03-nvidia-open`.

6. **Kernel and NVIDIA RPMs install with `--setopt=tsflags=noscripts`**;
   `depmod` and `dracut` are run explicitly (`build-initramfs`).

7. **Per-stage verification.** Every install stage runs a `<stage>-verify`
   companion in the same `RUN`, except `install-terra` and `install-devtools`
   (each verifies every listed package with `rpm -q` inside the stage) and
   `build-initramfs` (its output is gated by `final-verify`'s kernel group).
   Cross-cutting checks that only the finished image can answer go in
   `final-verify`.

8. **This is bootc, not rpm-ostree.** Kernel arguments are changed with
   `grubby`; the cmdline is read from `/proc/cmdline`; `bootc status` replaces
   `rpm-ostree status`. (`halcyon-rebase.just` keeps a `command -v rpm-ostree`
   fallback for non-bootc hosts — that is deliberate and is not an excuse to
   write new rpm-ostree code.)

9. **A package a recipe shells out to must be in `packages.json`.** `ugum`
   falls back to fzf when `gum` is absent, so `gum` is _not_ required — but
   `grubby`, `ethtool`, `wget` (the F44 binary is `wget2-wget`), `hostname`,
   `fpaste`, `wl-copy`, `zenity` and `jq` are, and `ujust-verify` gates them
   all with `command -v`.

10. **Image signatures use the legacy sigstore format.** Cosign 3 defaults to a
    referrer-based bundle that `cosign verify` accepts but containers/image
    (podman, skopeo, bootc) cannot see. `build.yml` signs with
    `--new-bundle-format=false --use-signing-config=false
    --registry-referrers-mode=legacy` and then verifies with
    `--new-bundle-format=false` (plus `registries.d/halcyon.yaml` +
    `policy.json` with `signedIdentity: matchRepository`, written by
    `desktop/image-info`). Never remove either step — `verify-github.sh` gates
    the flags.

---

## 5. bootc / image constraints

- `/var` must be effectively empty in the image. Content there without a
  matching `tmpfiles.d` entry triggers the `var-tmpfiles` lint warning, and is
  only applied on _initial provisioning_. Create runtime state with `tmpfiles.d`
  (`zz-halcyon-*.conf`, `noctalia-greeter-state.conf`) or a oneshot unit
  (`var-nix.service`).
- **Never create `/usr/etc`.** It is bootc's client-side view of the default
  `/etc`, `bootc container lint` checks it, and `branding-verify` asserts it
  does not exist. The cosign key therefore lives at
  `/etc/pki/containers/halcyon.pub`, written by `desktop/image-info`.
- `/var/run` must remain a symlink to `/run` — that lint is a hard failure.
- `/boot` must be empty; the kernel lives in `/usr/lib/modules/<kver>/` and the
  initramfs is baked there too (`build-initramfs`).
- No `/usr/local` writes; use `/usr/lib/<app>` plus a `/usr/bin` symlink.
  (Brave installs under `/opt` via its RPM; do not gate `/opt` as empty.)
- The final `bootc container lint` runs with `--network=none` and a tmpfs
  `/run`. Anything needing the network must happen before it. It runs **without**
  `--fatal-warnings`, so `var-tmpfiles`/`sysusers` warnings do not fail the
  build today.

---

## 6. Conventions by file type

### Build scripts (`build_files/**`)

- `#!/usr/bin/env bash` + `set -euo pipefail` (use `set -uo pipefail` only when
  the script deliberately accumulates failures and returns its own `rc`).
- Wrap output in `echo "::group::<script> — <phase>"` / `echo "::endgroup::"`;
  use the `  OK  ` / `  WARN  ` / `  FAIL  ` / `  SKIP  ` / `  INFO  ` prefixes.
- One package per line in `dnf5 install` lists; package lists live in
  `packages.json`, never inline.
- **`# shellcheck source=build_files/packages-lib`** — ShellCheck resolves
  `source=` relative to its _working directory_ (the repo root, where
  `just lint` runs), not the script's directory. Do not rewrite these to
  `../packages-lib`; that fails `just lint`.
- If a script tolerates failure (`|| true`), the corresponding verify gate must
  tolerate it too. The only tolerated install today is the `custom-environment`
  comps group, which is not hard-gated. (brave-origin used to install with
  skip-unavailable semantics via `vendor-apps-optional`; that group is gone and
  brave-origin is a hard `vendor-apps` member gated by `packages-verify`.)
- The `/ctx` bind mount is **read-only**. Stages that must write into their own
  sources copy them out first — `install-built-apps` copies
  `/ctx/python-packages` to `/usr/src/python-packages` precisely because pip's
  `egg_info` step writes into the source tree.

### Static tree (`system_files/shared/**`)

- COPY'd **before** any package install. An RPM installed later that owns the
  same path can replace or shadow your file. For drop-in directories
  (`tmpfiles.d`, `sysusers.d`, `modprobe.d`) prefix `zz-halcyon-<topic>.conf` so
  it cannot collide and sorts later, and gate the final content. For RPM-owned
  config, gate the content right after the package install (see
  `packages-verify` for greetd).
- Executable bits come from git (`git update-index --chmod=+x`), plus a
  `test -x` gate.

### profile.d ordering

`00-path-guard.sh` → `01-nix-resolve-home-env.sh` → `02-custom-environment.sh`
→ `brew.sh` (interactive shells only) → `image-path.sh` → `texlive.sh`
(generated by `install-texlive`). `00-path-guard.sh` uses only shell builtins on
purpose. `brew.sh` fixes up interactive shells; the `HOMEBREW_*` env vars for
_all_ sessions come from `etc/environment.d/10-homebrew.conf` via
systemd-environment-d-generator. The default login shell is **zsh**; confirm
zsh's `/etc/zprofile` reaches anything you rely on.

### ujust recipes (`usr/share/ublue-os/just/*.just`)

- Start with `# vim: set ft=make :`; every recipe gets a doc comment and a
  `[group("…")]`.
- Register a new module file in the `for f in …` loop in
  `runtime/setup-ujust`, which writes `60-custom.just` (imported by
  `/usr/share/ublue-os/justfile`). A module not in that loop ships but is never
  imported.
- Interactive recipes `source /usr/lib/ujust/ujust.sh` and use `Choose`.
- `just --fmt --check` does not parse recipe bodies; `just check` runs
  `bash -n` over every body.

### Python packages

Stdlib only, zero pip dependencies, one shared venv at
`/usr/lib/halcyon-python`. Register a new package in `EXPECTED` in
`apps/install-python-packages`, in `python-packages/README.md`, and in the loop
in `apps/built-apps-verify`. Every tool must answer `-h` or `--version`
non-interactively — but **that smoke test never reaches the code that does the
work**, and neither does a syntax check. A missing `datetime` import once
shipped in `rmi`. `just lint-python` (ruff F821 undefined names) and
`just test-python` exist for exactly that.

---

## 7. Known traps

- **Verify gates must match what `systemctl enable` actually does.** In a
  container it writes `/etc/systemd/system/<target>.wants/…`. `configure-system`
  therefore falls back to explicit `ln -sf` when `systemctl enable` fails, and
  gates use `systemctl is-enabled` for system units and `test -L` for the
  `/etc/systemd/user/*.wants/` symlinks.
- **Prove every new gate can fail.** Invert it once and confirm exit 1.
  `final-verify` once carried a "terra repos all disabled" gate whose glob
  `finalize` had already deleted — it could never fail. Also beware
  `test "${VAR}" = "$(...)"` when both sides can be empty (the NVIDIA version
  gate needs `test -n "${NV_MOD_VER}"` in front of it).
- **Do not gate what you have not checked exists.** No `/opt` gate (Brave), no
  comment-sensitive `grep` over shipped recipes.
- **`install-pyprland`**: upstream ships `systemd-unit/pyprland.service`, so an
  `else` branch (inline unit) never runs. Anything that must apply to both units
  (the `ConditionEnvironment` drop-in) is written **unconditionally**, outside
  that `if`, and `built-apps-verify` gates its content.
- **`ConditionEnvironment=` on a user unit** reads the _systemd user manager's_
  environment; the Hyprland session must export `XDG_CURRENT_DESKTOP` into it
  (`dbus-update-activation-environment --systemd`) or pyprland silently never
  starts.
- **The brew timers gate on a symlink** (`ConditionPathIsSymbolicLink`).
  `brew-verify` asserts the payload keeps `bin/brew` a symlink.
- **The Brewfile is deliberately three formulas** (`bun`, `pixi`, `opencode`).
  Brew dirs are appended to PATH, so a brewed duplicate of an RPM can never run.
- **Package names change between Fedora releases** (`terra-gamescope` and
  `terra-mangohud` retired; lazygit ships as
  `golang-github-jesseduffield-lazygit` in Terra). `dnf5` aborts the _whole
  transaction_ on one bad name — verify before adding, and do not assume a tool
  exists in Fedora because it exists upstream (`gum` has no Fedora package;
  `ugum` ships from `ublue-os-just` and falls back to fzf, so only fzf is a hard
  requirement).
- **Build-tool preconditions are invisible dependencies** (`zstd`,
  `util-linux-core` (setpriv), `gnupg2` (texlive signatures), `jq`, `gcc-c++`);
  `packages-verify` gates them.
- **CI runners are pinned to `ubuntu-24.04`.** `ubuntu-latest` migrates to 26.04
  between 2026-10-19 and 2026-11-19, and `ublue-os/remove-unwanted-software@v9`
  is not compatible with 26.04.
- **Scheduled workflows run only from the default branch**, and `build.yml`
  publishes only from `PUBLISH_BRANCH` (`container`). Locally `origin/HEAD`
  points at `main` until changed; `verify-github.sh` warns about the mismatch.

---

## 8. CI

- `lint.yml`: `just check`, `just lint`, `.github` audit, actionlint
  (`rhysd/actionlint:1.7.12`), ruff, pytest.
- `semantic-pr.yml`: PR-title Conventional Commits check (title only, via
  `amannn/action-semantic-pull-request`).
- `build.yml`: publish gate → COPR metadata wait → both syntax gates →
  `just build` → `verify/` suite → census → tags → (publish branch only) push,
  sign (legacy format), verify. Monitors the three COPRs the build consumes:
  `catpieleaf/kernel-p03`, `lionheartp/Hyprland`, `ublue-os/packages`.
  (The `sneexy/zen-browser` COPR was retired — zen-browser resolves from
  Terra now.)
- `clean.yml`: weekly GHCR pruning (Sundays 00:15 UTC).

If you add a COPR the build consumes, add its `repomd.xml` URL to the `URLS`
array in the "Wait for Copr metadata availability" step, and expect
`verify-github.sh` to require the monitor entry too.

---

## 9. Checklist before proposing a change

- [ ] `just check` and `just lint` pass.
- [ ] `just lint-python` / `just test-python` pass if you touched python helpers.
- [ ] New install stage has a `<stage>-verify` companion in the same RUN
      (exceptions: `install-terra`, `install-devtools` — they `rpm -q` every
      listed package inline; `build-initramfs` — covered by `final-verify`).
- [ ] Every new gate has been inverted once and confirmed to fail.
- [ ] New `dnf5 install` uses `--setopt=install_weak_deps=False`.
- [ ] Any third-party repo enabled is disabled in the same stage.
- [ ] Every binary a new recipe calls is in `packages.json` and gated.
- [ ] Nothing new lands in `/var`, `/usr/etc`, `/usr/local` or `/boot`.
- [ ] New files in `usr/bin` / `usr/libexec` are mode 0755.
- [ ] Workflows: no branch pins, no `ubuntu-latest`, signing flags untouched.
- [ ] Comments that describe _why_ are preserved — they are the design docs.