# SKILLS.md — halcyon

Task-level playbooks for agents (and humans) working in this repository.

`AGENTS.md` answers **"what is this repo and what must I never break?"** and is
read at the start of every session. This file answers **"how do I do X here?"**
and is meant to be consulted when a task matches one of the skills below.
Nothing here repeats `AGENTS.md`; read that first.

Each skill is written so it can be lifted verbatim into
`.claude/skills/<name>/SKILL.md` later — see [§ Splitting this
file](#splitting-this-file-into-agent-skills) at the end.

| Skill | Use when |
| --- | --- |
| [`verify-package-availability`](#skill-verify-package-availability) | Before adding *any* package name to *any* install list |
| [`add-build-stage`](#skill-add-build-stage) | Adding a new `RUN` stage to the Containerfile |
| [`add-rpm-package`](#skill-add-rpm-package) | Adding a package from Fedora, Terra, a COPR, or a vendor repo |
| [`add-verify-gate`](#skill-add-verify-gate) | Writing or fixing a `<stage>-verify` check |
| [`ship-systemd-unit`](#skill-ship-systemd-unit) | Shipping, enabling, masking or drop-in-patching a unit |
| [`add-ujust-recipe`](#skill-add-ujust-recipe) | Adding or vendoring a `ujust` recipe |
| [`add-python-tool`](#skill-add-python-tool) | Adding a CLI helper under `build_files/python-packages/` |
| [`add-upstream-binary-app`](#skill-add-upstream-binary-app) | Installing software that has no RPM (AppImage, tarball, GitHub release) |
| [`add-static-file`](#skill-add-static-file) | Adding a file under `system_files/shared/` |
| [`remove-package-or-file`](#skill-remove-package-or-file) | Pruning something out of the image |
| [`diagnose-failed-build`](#skill-diagnose-failed-build) | A local or CI build went red |
| [`bump-fedora-release`](#skill-bump-fedora-release) | Moving F44 → F45 |
| [`bump-kernel-or-nvidia`](#skill-bump-kernel-or-nvidia) | Changing the p03 kernel or the NVIDIA driver line |
| [`ci-signing-and-runners`](#skill-ci-signing-and-runners) | Touching workflows, bumping Cosign, or changing runners |

---

## skill: verify-package-availability

**Use when:** before adding any package name to `install-packages`,
`install-devtools`, `install-terra`, or any other install list — and whenever a
build fails with `no match for argument`.

**Do not use for:** packages already installed in a previous build (check the
`final-verify` package census output instead).

### Why this exists

Package names in this repo have moved twice already: Terra retired
`terra-gamescope` and `terra-mangohud` (Fedora 44 ships `gamescope` +
`mangohud` directly now), and `lazygit` ships as
`golang-github-jesseduffield-lazygit` in Terra. `dnf5` aborts the **whole
transaction** if a single argument does not resolve, so one wrong name kills an
entire stage and burns a ~40-minute CI build. Never guess a name from
upstream's README — upstream's project name and Fedora's package name
frequently differ (`dust` vs `du-dust`, `fd` vs `fd-find`, `ripgrep` provides
`rg`, and on F44 the `wget` binary comes from `wget2-wget`).

### Steps

1. Query against a throwaway container of the **same base image**, not your
   workstation:

   ```bash
   podman run --rm quay.io/fedora/fedora-bootc:44 bash -lc '
     dnf5 -y install dnf5-plugins >/dev/null 2>&1
     dnf5 repoquery --qf "%{name}-%{version}-%{release}.%{arch}  [%{reponame}]\n" \
       dust du-dust atuin tealdeer uv cava chafa 2>&1 | sort -u'
   ```

2. For a **Terra** package, query Terra exclusively — a package that resolves
   from Fedora is *not* proof it exists in Terra, and `install-terra` disables
   every other repo:

   ```bash
   podman run --rm quay.io/fedora/fedora-bootc:44 bash -lc '
     dnf5 -y install dnf5-plugins >/dev/null 2>&1
     dnf5 repoquery --disablerepo="*" --enablerepo="terra*" \
       --repofrompath "terra,https://repos.fyralabs.com/terra44" --nogpgcheck \
       --qf "%{name} [%{reponame}]\n" <pkg>'
   ```

3. For a **COPR** package, enable the COPR in the throwaway container first:

   ```bash
   podman run --rm quay.io/fedora/fedora-bootc:44 bash -lc '
     dnf5 -y install dnf5-plugins >/dev/null 2>&1
     dnf5 -y copr enable <owner>/<project>
     dnf5 repoquery --qf "%{name}-%{version} [%{reponame}]\n" <pkg>'
   ```

4. If the name is wrong, find the real one by what it *provides* or what file
   it ships:

   ```bash
   dnf5 repoquery --whatprovides /usr/bin/<binary>
   dnf5 repoquery --file /usr/bin/<binary>
   ```

5. Record the verified name **and the repo it came from** in the group's
   `_docs` entry in `packages.json`. Never write the note as an inline
   `//` or `#` comment — jq parses the file as plain JSON and rejects both
   (an inline comment block once shipped and broke every stage from Stage 02
   on; `just check` now catches it).

### Rules

- A package must be sourced from exactly one repo, and that repo must be the
  one the stage has enabled. Terra packages never fall back to Fedora — that is
  enforced by `--disablerepo='*' --enablerepo='terra*'` and it is deliberate.
- If a package is genuinely optional, it gets `|| true` at install (the only
  tolerated install today is the `custom-environment` comps group) **and**
  must not be a hard gate in any `*-verify` script. A hard gate on a tolerated
  install is a red build waiting to happen. (`vendor-apps-optional` used to be
  the second tolerated install; that group was removed and brave-origin is now
  a hard `vendor-apps` member gated by `packages-verify`.)
- `install-terra` and `install-devtools` have no `-verify` companion — each
  `rpm -q`s every listed package inside the stage and fails on the first miss.
  A new package in those groups is verified by that inline loop plus
  `final-verify`'s keeper/devtools gates, not by a new script.

---

## skill: add-build-stage

**Use when:** the work does not fit any existing `build_files/` script — a new
subsystem, a new class of software, a new configuration phase.

**Do not use for:** adding a package to an existing stage (see
[`add-rpm-package`](#skill-add-rpm-package)) or adding a file to the static tree
(see [`add-static-file`](#skill-add-static-file)).

### Steps

1. **Name the script** `build_files/<folder>/<verb>-<subject>`, extensionless,
   matching the existing vocabulary (`install-*`, `setup-*`, `configure-*`,
   `build-*`, `remove-*`). Pick the folder by build phase — `base/ kernel/
   packages/ brew/ runtime/ apps/ desktop/ finish/`. Commit it executable:

   ```bash
   git add build_files/runtime/install-foo
   git update-index --chmod=+x build_files/runtime/install-foo
   ```

2. **Skeleton** (copy `runtime/install-nix`). The shellcheck directive is
   resolved relative to ShellCheck's WORKING DIRECTORY (the repo root, where
   `just lint` runs), so it names `build_files/packages-lib`:

   ```bash
   #!/usr/bin/env bash
   # halcyon build step — install-foo (one line on WHY this stage exists)
   set -euo pipefail
   # shellcheck source=build_files/packages-lib
   source /ctx/packages-lib
   packages_validate
   echo "::group::install-foo — <phase>"
   readarray -t FOO_PKGS < <(packages_for foo)
   dnf5 -y --setopt=install_weak_deps=False install \
     "${FOO_PKGS[@]}"
   echo "::endgroup::"
   ```

3. **Insert the `RUN` block** in `Containerfile`. Stages are numbered 00–17 and
   every banner is a literal `████ STAGE nn/17 · <script> · <summary> ████`
   (the `nn/17` suffix is a per-stage counter, not the number of a future
   stage — a 19th stage would keep `nn/17` banners). Mirror the surrounding
   mount style: `type=cache,id=dnf-cache,target=/var/cache/libdnf5` when the
   stage touches `dnf5` (the brew, configure-system and image-info stages
   deliberately have no cache mount), plus the read-only ctx bind:

   ```dockerfile
   # ---- Stage N: foo ----------------------------------------------------------
   RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
       --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
       echo "████ STAGE NN/17 · install-foo · <summary> ████" \
       && /ctx/runtime/install-foo && /ctx/runtime/install-foo-verify && /ctx/cleanup
   ```

   Drop the `type=cache` mount if the stage never touches `dnf5`.

4. **Add the `<stage>-verify` companion in the same `RUN`** unless the stage is
   an install stage that self-verifies (install-terra, install-devtools) or its
   output is inherently cross-cutting (build-initramfs → `final-verify`).

5. **Renumber the stage comments** below your insertion point. They are
   referenced in commit messages and CI logs; leaving them stale is worse than
   not numbering at all. Banners are `nn/17` regardless.

6. Run `just check && just lint`. Both walk `build_files` recursively, so a
   script in any phase folder is picked up automatically with no Justfile edit.

### Placement rules (in order of precedence)

- **Anything that must end up in the initramfs** (dracut hooks, plymouth
  assets, kernel module config) goes **before** `build-initramfs` (Stage 14),
  which is deliberately last so the theme and NVIDIA hooks are baked in.
- **Anything that enables a third-party repo** goes before `finalize`, which
  sweeps repo files, and must disable its own repo anyway.
- **Anything that needs tooling from `install-packages`** (ImageMagick, jq,
  python3, gcc) goes after it. `build-plymouth-assets` fails hard without
  `magick` for exactly this reason.
- **Every mutating stage ends with `/ctx/cleanup`** — the single exception is
  `finalize`, which is itself the hygiene sweep. `final-verify` and the bootc
  lint mutate nothing and do not call it either.
- **Nothing** goes after the `bootc container lint` block; it runs
  `--network=none` on a tmpfs `/run` and is the hermetic final gate.

### Rules

- `/ctx` is mounted **read-only**. If your stage needs to write into its own
  sources, copy them out first — `install-built-apps` copies
  `/ctx/python-packages` to `/usr/src/python-packages` precisely because pip's
  `egg_info` step writes into the source tree.
- The `ctx` stage is `FROM scratch` and never becomes part of the image. Do not
  try to persist anything there.
- Use `set -euo pipefail`. Use `set -uo pipefail` **only** when the script
  deliberately accumulates failures and returns its own `rc`.

---

## skill: add-rpm-package

**Use when:** adding an RPM to the image.

### Steps

1. Run [`verify-package-availability`](#skill-verify-package-availability).
   Do not skip this.

2. Pick the destination by **source repo**, not by what the package does:

   | Source                           | Where                                    | How                                           |
   | -------------------------------- | ---------------------------------------- | --------------------------------------------- |
   | Fedora (toolchains)              | `packages.json` `programming`            | installed FIRST by `install-packages` (Stage 04) |
   | Fedora (core/hardware)           | `packages.json` `core` / `hardware`      | alphabetical in the group                     |
   | Fedora (editors/runtimes)        | `packages.json` `editors`                | alphabetical                                  |
   | Fedora (CLI user tools)          | `packages.json` `cli-tools`              | alphabetical, `install-devtools` (Stage 06)   |
   | Fedora (CLI dev tooling)         | `packages.json` `devtools` / `misc`      | alphabetical, `install-devtools` (Stage 06)   |
   | Fedora (ujust recipe dependency) | `packages.json` `ujust-fedora`           | and add a `command -v` gate to `ujust-verify` |
   | Terra                            | `packages.json` `terra`                  | resolves exclusively from Terra               |
   | COPR lionheartp/Hyprland         | `packages.json` `desktop`                | consumed by `install-packages` (Stage 04)     |
   | COPR ublue-os/packages           | `packages.json` `ublueos-packages`       | consumed by `install-packages` (Stage 04)     |
   | Vendor repo (MS, Brave)          | `packages.json` `vendor-apps`            | ONLY if it truly resolves from that repo      |

   Note: `ublue-os/packages` is consumed by exactly **one** stage
   (`install-packages` for `ublueos-packages`, which does its own
   `copr enable`/`copr disable`). `setup-ujust` installs `ujust-fedora` only;
   the ublue-os-just/uupd machinery arrives earlier via `ublueos-packages`.

3. Always `--setopt=install_weak_deps=False`. If the package relied on a weak
   dependency, list that dependency explicitly too — this is why
   `flatpak-selinux`, `hyprland-guiutils`, `xdg-desktop-portal-{hyprland,gtk}`,
   `qt6ct` and `nwg-look` are spelled out.

4. One package per line, alphabetical within its block, with the block's
   purpose in a comment above it.

5. For a COPR, the lifecycle is one stage wide:

   ```bash
   dnf5 -y copr enable <owner>/<project>
   dnf5 -y --setopt=install_weak_deps=False install \
     pkg-a \
     pkg-b
   dnf5 -y copr disable <owner>/<project>
   ```

6. **If the COPR is new to the build**, add its repodata URL to the `URLS`
   array in the "Wait for Copr metadata availability" step of
   `.github/workflows/build.yml`:

   ```
   https://download.copr.fedorainfracloud.org/results/<owner>/<project>/fedora-44-x86_64/repodata/repomd.xml
   ```

   Copr's CDN 504s intermittently; a COPR that is consumed but not polled turns
   into a random red build. `verify-github.sh` also requires the COPR to be in
   the monitor list.

7. **Check for a contradiction with the removals stage.** `remove-packages`
   runs *first* against `packages.json`'s `all.exclude.all`; if your package is
   on that list and you are (re)installing it anyway, `remove-packages`
   resolves the list through `rpm -qa` first so a missing name is tolerated —
   but say in a comment why the pair exists. (`fastfetch` is currently in both
   `core` and `all.exclude.all`; the exclusion only bites when the base
   ships it.) The old `guarded-removals` helper that used to warn about this is
   gone — do not resurrect it.

8. Add or extend the gate in the stage's `*-verify` (or the inline `rpm -q`
   loop for terra/devtools). For a package that matters to the finished image's
   identity (kernel, NVIDIA, gaming keepers), gate it in `final-verify` instead.

### Verify

```bash
just check && just lint
podman build --pull -t localhost/halcyon:latest .
podman run --rm --entrypoint /bin/bash localhost/halcyon:latest -c 'rpm -q <pkg>'
```

---

## skill: add-verify-gate

**Use when:** writing a new `<stage>-verify`, or fixing a gate that passes when
it should fail (or fails when it should pass).

### The idiom

Every verify script uses the same three lines, then a list of gates:

```bash
#!/usr/bin/env bash
# halcyon verify — <level> (runs immediately after <stage>).
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }

echo "::group::<stage>-verify — <area>"
gate "foo installed"            rpm -q foo
gate "foo binary present"       test -x /usr/bin/foo
gate "foo unit shipped"         test -f /usr/lib/systemd/system/foo.service
gate "foo enabled"              systemctl is-enabled foo.service
gate "no leftover repo file"    sh -c '! test -f /etc/yum.repos.d/foo.repo'
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::<stage>-verify failed"; exit 1; }
echo "--- <stage>-verify: all checks passed ---"
```

### Steps

1. Write the gate as a **command**, not a shell string, unless you need shell
   syntax — `gate "desc" rpm -q foo` beats `gate "desc" sh -c 'rpm -q foo'`.
2. Negative assertions need `sh -c '! …'`. Note that `set -e` does not fire
   inside `gate` because the command runs in an `if`.
3. **Prove the gate can fail.** Temporarily invert it (`rpm -q definitely-not-a-package`)
   and confirm the script exits 1. A gate that can never fail is worse than no
   gate — it's a false assurance that survives refactors.
4. Decide the level: stage-scoped facts go in `<stage>-verify`; cross-cutting
   facts that only the finished image can answer (kernel/NVIDIA end state, repo
   sweep, keeper set, package census) go in `final-verify`. Terra and devtools
   packages are verified by the inline `rpm -q` loops in their own stages plus
   `final-verify` keeper gates — do not add a companion script for them.

### Gate forms that are wrong in this environment

- **`test -e /usr/lib/systemd/system/<target>.wants/<unit>`** — `systemctl
  enable` in a build container writes to `/etc/systemd/system/…` (and
  user-level enablement is done with explicit symlinks into
  `/etc/systemd/user/*.wants/`). Use `systemctl is-enabled <unit>` for system
  units, `test -L` for the user-unit symlinks.
- **A gate whose glob a later stage deletes.** `final-verify` once had
  `! grep -l "^enabled=1" /etc/yum.repos.d/terra*.repo | grep -q .` — but
  `finalize` deletes those files, so it passed unconditionally.
- **`test "${VAR}" = "$(...)"` where VAR may be empty.** `test "" = ""` PASSES.
  The NVIDIA version gate needs `test -n "${NV_MOD_VER}"` in front of it.
- **Gating "directory X is empty" without checking who writes there.** Brave's
  RPM installs into `/opt`.
- **A `grep` over shipped recipe files.** Comments and fallback branches match.
  Gate behaviour, not prose.
- **Gating a package installed with `|| true`.** Either it is required (drop the
  `|| true`) or optional (drop the gate).
- **`grep -rq pattern /some/dir/`** returns non-zero for "directory missing" and
  "pattern absent" alike. Add a `test -d` gate alongside it.

---

## skill: ship-systemd-unit

**Use when:** adding a system unit, a user unit, a drop-in, a mask, or a
tmpfiles rule.

### Decision table

| Goal | Where the file goes | How it is activated |
| --- | --- | --- |
| System unit | `system_files/shared/usr/lib/systemd/system/<u>` | `systemctl enable <u>` in `desktop/configure-system` |
| User unit, every user | `system_files/shared/usr/lib/systemd/user/<u>` | explicit symlink into `/etc/systemd/user/default.target.wants/` in `desktop/configure-system` |
| User timer, every user | same | symlink into `/etc/systemd/user/timers.target.wants/` |
| Disable an inherited unit | — | `ln -sf /dev/null /etc/systemd/system/<u>` |
| Patch a unit you do not own | `…/<u>.d/10-halcyon-<topic>.conf` | drop-in, created **unconditionally** |
| Runtime state under `/var` | `system_files/shared/usr/lib/tmpfiles.d/<n>.conf` | `systemd-tmpfiles` at boot |

Some user units are **generated by build stages** rather than shipped in the
static tree — `pyprland.service` from `install-pyprland`,
`halcyon-flatpak-setup.service` from `setup-flatpaks`. Wire them through the
same symlinks and say where the file comes from at the wiring site.

### Steps

1. Write the unit into the static tree (or note the stage that generates it).
   Units are plain files — no executable bit.
2. Wire activation in `build_files/desktop/configure-system`. The existing
   patterns (note the `systemctl enable … || ln -sf` fallbacks — in a build
   container `systemctl enable` sometimes cannot write its own symlinks):

   ```bash
   # system units
   systemctl enable greetd.service getty@tty2.service 2>/dev/null || true
   systemctl enable var-nix.service nix.mount 2>/dev/null || true

   # user units, --global equivalent: explicit symlinks
   mkdir -p /etc/systemd/user/default.target.wants /etc/systemd/user/timers.target.wants
   ln -sf /usr/lib/systemd/user/foo.service \
          /etc/systemd/user/default.target.wants/foo.service

   # masks
   ln -sf /dev/null /etc/systemd/system/bar.service
   ```

3. Gate it in `system-verify` — `test -L` for the user symlinks,
   `systemctl is-enabled` for system units.

### Rules and traps

- **Never ship files into `/var` from a unit or a `COPY`.** `/var` content in
  the image is applied only at *initial provisioning*; upgrades never see it,
  and `bootc container lint` raises `var-tmpfiles`. Create the state with a
  `tmpfiles.d` rule (`zz-halcyon-*.conf`, `noctalia-greeter-state.conf`) or a
  oneshot unit (`var-nix.service`).
- **A drop-in that must apply to both the upstream-unit path and a fallback
  path is written unconditionally, outside the `if`.** `install-pyprland`
  installs upstream's `systemd-unit/pyprland.service`, so its `else` branch
  (inline unit) never runs — the `ConditionEnvironment=` drop-in therefore
  lives *after* the `if` and is always written, and `built-apps-verify` gates
  its content (`grep XDG_CURRENT_DESKTOP=Hyprland …/pyprland.service.d/`).
  This was a shipping bug once (the drop-in sat inside the dead `else`); the
  comment in `install-pyprland` explains the history — preserve it.
- **`ConditionEnvironment=` on a user unit reads the systemd *user manager's*
  environment**, not the shell's. It only works if the session exports the
  variable into the manager (`dbus-update-activation-environment --systemd`, or
  `systemctl --user import-environment`). The Hyprland/noctalia session startup
  does this; without it the condition silently never matches and pyprland never
  starts.
- **First-login-only user units** use the `ConditionPathExists=!%h/…` +
  `ExecStartPost` stamp-file pattern (`chezmoi-init.service`,
  `halcyon-flatpak-setup.service`). Reuse it rather than inventing a new one.
- **Enablement in a container is not enablement at runtime for presets.** If a
  package's `%post` would normally enable the unit and you installed with
  `tsflags=noscripts`, you must enable it yourself.

---

## skill: add-ujust-recipe

**Use when:** adding a user-facing `ujust` task, or vendoring one from Bazzite.

### Steps

1. Put the recipe in an existing module under
   `system_files/shared/usr/share/ublue-os/just/`, or create
   `halcyon-<topic>.just` starting with:

   ```make
   # vim: set ft=make :

   # One-line description shown by `ujust --list`
   [group("system")]
   my-recipe ACTION="":
       #!/usr/bin/env bash
       set -euo pipefail
   ```

2. **Register a new module file** by adding its filename to the `for f in …`
   loop in `build_files/runtime/setup-ujust` (Stage 11), which writes
   `/usr/share/ublue-os/just/60-custom.just` (imported by
   `/usr/share/ublue-os/justfile`). A module that is not in that loop is
   shipped but never imported.

3. **Syntax-check the body.** `just --fmt --check` does *not* parse recipe
   bodies — but the `check` recipe's "recipe bodies" group already extracts
   every body from each module and runs `bash -n` on it (the exact loop below),
   and `just check` runs in CI. If a body carries a missing `fi`, `just check`
   finds it before the ~40-minute build does:

   ```bash
   f=system_files/shared/usr/share/ublue-os/just/80-halcyon.just
   for r in $(just -f "$f" --summary 2>/dev/null); do
     body=$(just -f "$f" --show "$r" 2>/dev/null) || continue
     printf '%s\n' "$body" | awk 'f{print} /^#!/{f=1}' | bash -n \
       || echo "SYNTAX ERROR in recipe: $r"
   done
   ```

4. **De-Bazzite anything vendored.** Before committing, grep the recipe for all
   of these and resolve each one:

   | Pattern | Status in this repo | What to do |
   | --- | --- | --- |
   | `rpm-ostree` | not on bootc | use `grubby --update-kernel=ALL --args=/--remove-args=`, read `/proc/cmdline`, `bootc status` — but `halcyon-rebase.just` deliberately keeps a `command -v rpm-ostree` fallback so the rebase recipe works on non-bootc hosts; keep that pattern, do not copy it to new recipes |
   | `/usr/libexec/bazzite-boot-remount` | **vendored** at `system_files/shared/usr/libexec/bazzite-boot-remount` | `source /usr/libexec/bazzite-boot-remount` like `80-halcyon.just` does; keep the vendored copy in sync with upstream |
   | `ugum` | shipped by `ublue-os-just`; falls back to fzf when `gum` is absent (only fzf is gated) | `80-halcyon.just` uses `Choose` from `/usr/lib/ujust/ujust.sh`; `81-halcyon-fixes.just` still calls `ugum choose` directly — either is fine, be consistent within a module |
   | `fpaste`, `wl-copy`, `zenity` | installed (cli-tools / gaming) and gated by `ujust-verify` with `command -v` | you can rely on them, but keep the gate |
   | `kdialog`, `gum` | not installed | use `Choose`, or install the package first |
   | `/usr/share/ublue-os/image-info.json` | generated by `desktop/image-info` (Stage 13) | you can rely on it; `bazzite-steam`, `bazzite-steam-firstrun` and `83-halcyon-audio` already read it |

5. Interactive recipes `source /usr/lib/ujust/ujust.sh` and use `Choose`,
   `${bold}`, `${green}`, `${normal}`. Expose a `status` action that prints a
   machine-readable token (`enable`/`disable`) — the existing recipes all do,
   and Bazzite's portal UI depends on that convention.

6. Add a gate to `ujust-verify` for every binary the recipe shells out to
   (`command -v`). There is deliberately **no** repo-wide "no rpm-ostree in
   recipes" gate — `halcyon-rebase.just` keeps a supported `rpm-ostree`
   fallback, so such a gate could never pass. If you remove that fallback, add
   the gate.

---

## skill: add-python-tool

**Use when:** adding a CLI helper to `build_files/python-packages/`.

### Steps

1. Create a src-layout package; copy `fe/` as the template:

   ```
   build_files/python-packages/<name>/
     pyproject.toml
     src/<module>/__init__.py      # must define main() -> int
   ```

2. `pyproject.toml` — copy verbatim and change four fields:

   ```toml
   [build-system]
   requires = ["setuptools>=77"]
   build-backend = "setuptools.build_meta"

   [project]
   name = "<name>"
   version = "1.0.0"
   description = "<one line>"
   requires-python = ">=3.10"
   license = "Apache-2.0"

   [project.scripts]
   <name> = "<module>:main"

   [tool.setuptools.packages.find]
   where = ["src"]
   ```

3. **Stdlib only.** All eleven packages share one venv at
   `/usr/lib/halcyon-python` with no dependency resolution safety net; a pip
   dependency would have to be vendored or the venv redesigned. Runtime *tool*
   dependencies (`fd`, `fzf`, `bat`, `rg`, `grim`, `swappy`, `slurp`) come
   from the RPM layer (`cli-tools` / `core`) and are checked at
   startup:

   ```python
   missing = [t for t in REQUIRED_TOOLS if shutil.which(t) is None]
   if missing:
       die(f"missing required dependencies: {', '.join(missing)}")
   ```

4. Follow the house conventions visible across the existing tools:
   - subclass `ArgumentParser` to exit **1** on usage errors (argparse's default
     is 2; the shell scripts these replaced used 1);
   - `exit_status(rc)` → `128 - rc if rc < 0 else rc` for subprocess results;
   - `sys.exit(130)` on `KeyboardInterrupt` in `__main__`;
   - colors only when `sys.stdout.isatty()`.

5. **Register in three places** — missing any one fails the build:
   - the `EXPECTED` array in `build_files/apps/install-python-packages`;
   - the table in `build_files/python-packages/README.md`;
   - the `for b in …` loop in `build_files/apps/built-apps-verify`.

6. **The build-time smoke test is `-h` or `--version`, and it is not enough.**
   It never reaches the code that does the work, and `py_compile` only checks
   syntax — a missing import is invisible to both (it shipped in `rmi`).
   `just lint-python` runs ruff for undefined names (F821/F822/F823) and syntax
   errors (E9). Add a `tests/` directory for anything with side effects, and
   list the package in the `for pkg in …` loop of the `test-python` recipe.

### Tests

`dump-to-markdown` and `rmi` have suites. To add one, mirror theirs:

```toml
[project.optional-dependencies]
dev = ["pytest"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

```bash
cd build_files/python-packages
python3 -m venv .venv && .venv/bin/pip install -e './<name>[dev]'
.venv/bin/pytest <name>
```

Note that `just check`/`just lint` exclude `python-packages/` by design
(`find … ! -path "*python-packages*"`). Run `pytest` via `just test-python`,
not by relying on `just check`.

---

## skill: add-upstream-binary-app

**Use when:** the software has no RPM anywhere — an AppImage, a vendor tarball,
or a GitHub release archive (Obsidian, Zotero, Pyprland, TeX Live are the
precedents).

### Steps

1. New script `build_files/apps/install-<app>`, invoked from
   `build_files/apps/install-built-apps` (Stage 10) as `/ctx/apps/install-<app>`
   — the scripts are executable and called directly, no `bash` prefix. Pick an
   order in `install-built-apps` that matches dependencies.

2. **Resolve the version at build time, with a pinned fallback.** Use the
   GitHub API with opportunistic auth so CI is not rate-limited:

   ```bash
   GH_AUTH="${GH_TOKEN:-${GITHUB_TOKEN:-${BB_PASSWORD:-}}}"
   AUTH_ARGS=(); [ -n "${GH_AUTH}" ] && AUTH_ARGS=(-H "Authorization: Bearer ${GH_AUTH}")
   ```

   Match the upstream's asset layout:
   - Obsidian: `releases?per_page=15` + `jq` filtering. Prefer this over
     `releases/latest` for asset-bearing releases — `releases/latest` is
     periodically a platform-specific release with no asset you can use (this
     is documented in `install-obsidian` and is not hypothetical).
   - Pyprland: `releases/latest` with a pinned fallback tag (`3.4.4`) when the
     API is unreachable or rate-limited, because the release carries no assets
     to filter on.

3. **Verify integrity — or say why you cannot.** GitHub's asset JSON carries a
   `digest` field for Obsidian's AppImage; `install-brew-bundle` pairs release
   assets with their published `.sha256` files. Use whichever upstream
   publishes:

   ```bash
   expected="${APPIMAGE_DIGEST#sha256:}"
   actual="$(sha256sum app.AppImage | cut -d' ' -f1)"
   [ "${expected}" = "${actual}" ] || { echo "  FAIL  sha256 mismatch" >&2; exit 1; }
   ```

   If upstream publishes no checksum at all, say so in a comment naming the
   accepted risk and the upstream position — the `install-pyprland` and
   `install-zotero` headers are the model. Do not silently skip verification.

4. **Install to `/usr/lib/<app>` and symlink into `/usr/bin`.** Never `/opt`,
   never `/usr/local` — both are `/var`-backed symlinks on bootc and will not
   survive as you expect.

5. **Desktop entry and icon**: *discover* them rather than probing one fixed
   path (upstream layouts change between releases), generate a complete entry if
   upstream ships none, then `sed` `Exec=` and `Icon=` to your canonical paths,
   run `desktop-file-validate` (non-fatal), and refresh
   `update-desktop-database` and `gtk-update-icon-cache`.

6. **Disable the app's self-updater.** The image is immutable; an in-app updater
   writing to `/usr` will fail confusingly. See Zotero's
   `distribution/policies.json` with `DisableAppUpdate` (gated by
   `built-apps-verify`).

7. `trap 'rm -rf "${TMP}"' EXIT` on a `mktemp -d`, `::group::` per phase, and a
   gate in `built-apps-verify` for the binary, the desktop entry and the
   updater policy.

### Rule

Anything installed this way is invisible to `rpm -qa`, so it does not appear in
the `final-verify` package census. Its only regression protection is the
`built-apps-verify` gate. Write the gate first.

---

## skill: add-static-file

**Use when:** adding anything under `system_files/shared/`.

### The collision hazard

`system_files/shared/` is `COPY`'d to `/` **before any RPM is installed**. Any
RPM installed in a later stage that owns the same path silently overwrites your
file, and no gate will notice unless you write one. This is a live risk: the
`nix` package's `tmpfiles.d` layout changed upstream, and `install-nix` runs at
Stage 08 — long after the `COPY`.

### Steps

1. **Check whether an RPM owns the path**, in a throwaway container:

   ```bash
   podman run --rm quay.io/fedora/fedora-bootc:44 bash -lc '
     dnf5 repoquery --file /usr/lib/tmpfiles.d/nix.conf 2>/dev/null'
   ```

   Also check the built image after your change:

   ```bash
   podman run --rm --entrypoint /bin/bash localhost/halcyon:latest \
     -c 'rpm -qf /usr/lib/tmpfiles.d/nix.conf'
   ```

2. **If any package may own it, rename yours so it cannot collide and sorts
   later**: `zz-halcyon-<topic>.conf` for drop-in directories
   (`tmpfiles.d`, `sysusers.d`, `modprobe.d`, `sysctl.d`, `udev/rules.d`).
   For a unit you do not own, prefer a `.d/10-halcyon-*.conf` drop-in over
   replacing the unit file.

3. **Gate the final content**, not merely the file's existence:

   ```bash
   gate "halcyon nix tmpfiles survives"  grep -q 'nixbld' /usr/lib/tmpfiles.d/zz-halcyon-nix.conf
   ```

4. **Executable bits come from git.** Anything under `usr/bin/` or
   `usr/libexec/halcyon-image/`:

   ```bash
   git update-index --chmod=+x system_files/shared/usr/libexec/halcyon-image/<script>
   ```

   and add a `test -x` gate. Helper scripts there are on `$PATH` for all login
   shells via `etc/profile.d/image-path.sh`.

5. **`profile.d` ordering** is `00-path-guard.sh` → `01-nix-resolve-home-env.sh`
   → `02-custom-environment.sh` → `brew.sh` → `image-path.sh` → `texlive.sh`
   (generated by `install-texlive`). A new script must pick a prefix that puts
   it after anything it depends on. `00-path-guard.sh` uses only shell builtins
   on purpose — never add an external command to it, or a broken `PATH` becomes
   unrecoverable. `brew.sh` only affects interactive shells (`$- == *i*`); the
   `HOMEBREW_*` env for all sessions comes from
   `etc/environment.d/10-homebrew.conf`. The default login shell is **zsh**, so
   confirm zsh's `/etc/zprofile` actually sources what you rely on.

6. **Never add anything under `var/`.** See
   [`ship-systemd-unit`](#skill-ship-systemd-unit).

---

## skill: remove-package-or-file

**Use when:** pruning something out of the image.

### Why removals run first

`remove-packages` is Stage 02, against the pristine base. `dnf` computes the
removal set from the full `Requires` graph, and on the untouched base the blast
radius is smallest; any cascade that takes out core tooling fails the very next
`dnf5` call, loudly and immediately. Do not move removals later to "clean up"
after installs.

### Steps

1. Add the package to the **`all.exclude.all` array in `packages.json`** —
   `remove-packages` reads that list via `packages_excludes()` and resolves it
   through `rpm -qa` first, so listing something absent is harmless (`dnf5`
   would otherwise abort the whole transaction on one missing argument).
2. If removing it could break something else, use the **reverse-dependency
   gate** pattern rather than removing blind (this lives in `remove-packages`
   for `sddm`/`cage`):

   ```bash
   reqs="$(dnf5 repoquery --installed --whatrequires "$p" 2>/dev/null | grep -Ev "^${p}(-[0-9])?" || true)"
   [ -n "${reqs}" ] && echo "  GATE  keeping ${p} — required by: ${reqs}"
   ```

3. If the package **must not survive**, add it to the hard-fail loop in
   `remove-packages` ("hard-fail verification", along with `gnome-shell gdm
   mutter nautilus firefox waydroid inputplumber`), not just the exclude list.
4. **Check nothing reinstalls it later.** Grep the whole `build_files/` tree
   and `packages.json` for the name before committing. A package in both
   `all.exclude.all` and an include group (`fastfetch` today) is a tolerated
   remove-then-reinstall pair — say why in a comment.
5. For file-level removal of something no RPM owns, write the removal inline in
   the stage that creates the condition — there is no longer a general-purpose
   file-footprint script to extend.

### The inherited removal machinery is gone

`guarded-removals`, `file-footprint`, `gnome-extensions` and `fonts-cleanup`
were written when halcyon was layered on Bazzite. On a bare `fedora-bootc` base
every one of their targets is absent, so they were ~400 lines of no-op whose
comments described an ordering that no longer held. They have been deleted.

The parts with real value now live in `base/remove-packages`: the
**reverse-dependency gate** (used for `sddm`/`cage`) and the
**must-not-survive hard-fail loop**. Extend those rather than resurrecting the
old scripts.

---

## skill: diagnose-failed-build

**Use when:** a local `podman build` or a CI run went red.

### Steps

1. **Locate the failure by group marker.** Every script wraps its phases in
   `::group::<script> — <phase>`; find the last one before the error and you
   have the script and the phase. Verify failures print
   `::error::<stage>-verify failed` and a `FAIL` line naming the gate.

2. **Classify it before touching anything:**

   | Signature | Cause | Action |
   | --- | --- | --- |
   | `504` / repodata timeouts | Copr CDN | re-run; ensure the COPR is in the CI `URLS` wait loop; the `libdnf5.conf.d` retry drop-in only helps if it is actually installed into `/etc/dnf/libdnf5.conf.d/` (Stage 00) |
   | `no match for argument` | package renamed/moved repo | [`verify-package-availability`](#skill-verify-package-availability) |
   | `Conflicts` naming `dkms-nvidia` | an NVIDIA subpackage was added to a `dnf5 install` | it must be `rpm2cpio`-extracted instead — see `install-kernel`'s header |
   | `FAIL` in `*-verify` but the stage logged OK | usually the **gate** is wrong, not the stage | [`add-verify-gate`](#skill-add-verify-gate) |
   | `Lint warning: var-tmpfiles` | content written to `/var` | add a `tmpfiles.d` rule or stop writing there |
   | `Lint … var-run` / `kernel` / `etc-usretc` / `baseimage-root` | **fatal** bootc lints | must be fixed; these fail the build |
   | `unexpected end of file` | shell syntax error | `just check`; for `.just` recipes see [`add-ujust-recipe`](#skill-add-ujust-recipe) |
   | `A signature was required, but no signature exists` on `bootc switch` / `bootc upgrade` | signature stored in the Cosign 3 referrer format, which containers/image cannot see | `build.yml` must sign with `--new-bundle-format=false --use-signing-config=false --registry-referrers-mode=legacy`; rebuild to re-sign |
   | `Signature for identity … is not accepted` | `policy.json` lacks `signedIdentity: matchRepository` (cosign signs by digest, bootc pulls by tag) | `desktop/image-info` |

   Note that the Containerfile runs `bootc container lint` **without**
   `--fatal-warnings`, so `var-tmpfiles` and `sysusers` warnings do not fail the
   build today. If you ever add `--fatal-warnings`, expect both to fire.

3. **Reproduce locally from the last good layer.** `podman build` defaults to
   `--layers=true`, so every successful step leaves an intermediate image; copy
   the id printed just before the failing `STEP`, then re-mount the context by
   hand (the bind mount is not part of the image — and note the ctx root also
   carries `packages.json` and `cosign.pub`):

   ```bash
   podman run --rm -it \
     -v "$PWD/build_files:/ctx:ro,Z" \
     -v "$PWD/packages.json:/ctx/packages.json:ro,Z" \
     -v "$PWD/cosign.pub:/ctx/cosign.pub:ro,Z" \
     <intermediate-id> /bin/bash
   # then, inside:
   /ctx/install-foo ; echo "rc=$?"
   ```

4. **Build only the context stage** when the problem is the `ctx` contents:

   ```bash
   podman build --target ctx -t localhost/halcyon-ctx .
   podman run --rm localhost/halcyon-ctx ls -la /
   ```

5. **Capture and grep** long runs:

   ```bash
   just build 2>&1 | tee /tmp/halcyon-build.log
   grep -nE '  (FAIL|WARN)  |::error::|Lint (warning|error)' /tmp/halcyon-build.log
   ```

### Rules

- **Never fix a red build by loosening a gate** (`|| true`, deleting the gate,
  `--skip` on the lint). Fix the stage, or fix the gate if the gate is what is
  wrong — and say which in the commit message.
- A failure inside `install-*` that is tolerated with `|| true` but hard-gated
  in `*-verify` will surface one stage later and look unrelated. When a verify
  fails for something that "installed fine", check for an `|| true` upstream.
- Preserve the `# NOTE:` / `# VERIFY:` comments you find while debugging — in
  this repo they *are* the design documentation.

---

## skill: bump-fedora-release

**Use when:** moving the base from F44 to a new Fedora release.

### Order matters: gate on the third-party repos first

1. **Confirm every consumed third-party source has builds for the new
   release** *before* changing anything. If any one is missing, stop — the
   bump is blocked, not merely risky:

   ```bash
   for u in catpieleaf/kernel-p03 lionheartp/Hyprland ublue-os/packages; do
     code=$(curl -sL -o /dev/null -w '%{http_code}' \
       "https://download.copr.fedorainfracloud.org/results/${u}/fedora-45-x86_64/repodata/repomd.xml")
     echo "${code}  ${u}"
   done
   curl -sL -o /dev/null -w '%{http_code}  terra45\n' https://repos.fyralabs.com/terra45/
   ```

2. **Confirm negativo17 still carries an NVIDIA userland matching the COPR
   kernel's module version** — see
   [`bump-kernel-or-nvidia`](#skill-bump-kernel-or-nvidia). This is the single
   most common reason a Fedora bump fails late.

### Then change, in this order

3. `Containerfile`: `ARG FEDORA_VERSION=45`.
4. `.github/workflows/build.yml`: every `fedora-44-x86_64` in the `URLS` array.
5. `Justfile`: nothing to change — `fedora_version` comes from `halcyon.env`
   and flows into both `generate-build-tags` and the `IMAGE_VERSION` build
   arg. Change `FEDORA_VERSION` in `halcyon.env`.
6. `install-terra` picks up `terra${FEDORA_MAJOR}` from `rpm -E %fedora` inside
   the build and needs no edit (same for the RPM Fusion and negativo17 repo
   URLs in `setup-repos`).
7. Re-run [`verify-package-availability`](#skill-verify-package-availability)
   over every list: `install-packages`, `install-devtools`, `install-terra`.
   Expect two or three renames per release (gamescope/mangohud moved from Terra
   to Fedora on F44; lazygit ships under its Go name in Terra).
8. Expect `remove-packages` to drift — packages get split, renamed, or dropped
   upstream. The `rpm -q` guard makes stale names harmless, but newly-split
   subpackages will survive removal unless you add them.
9. Full local build + `just package-count`, and compare the census against the
   previous release's `/usr/share/halcyon/package-count`.

---

## skill: bump-kernel-or-nvidia

**Use when:** changing `kernel-p03`, `kernel-p03-nvidia-open`, or the negativo17
userland. **This is the highest-risk change in the repo.** Read
`build_files/kernel/install-kernel`'s header comment in full first.

### The invariant

The NVIDIA **userland** version must equal the version reported by the
**kernel module** built by the COPR. The COPR kmod package's `%{VERSION}` is the
*kernel* version, not the driver version — the driver version lives only in the
module metadata:

```bash
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
NV_KO="$(find "/usr/lib/modules/${KVER}" -name 'nvidia.ko*' | head -1)"
modinfo -F version "${NV_KO}"                       # driver version, authoritative
rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64  # must match exactly
```

`final-verify` gates exactly this. If they diverge, the image boots to a black
screen with no module loaded.

### Steps

1. Find the driver version the new COPR modules were built for, then confirm
   negativo17 still ships that line. RPM Fusion is **not** an alternative — its
   userland is on a different version and `xorg-x11-drv-nvidia` hard-requires
   `nvidia-kmod`/`akmod-nvidia`.
2. **Re-verify the entangled-subpackage list.** Four negativo17 subpackages
   cannot be installed alongside the COPR's prebuilt modules because they pull
   `nvidia-kmod` → `dkms-nvidia`, which `Conflicts` with
   `kernel-p03-nvidia-open`. That list is version-specific; re-derive it, do not
   trust the comment:

   ```bash
   dnf5 repoquery --requires nvidia-driver nvidia-driver-cuda nvidia-settings nvidia-kmod-common
   dnf5 repoquery --whatprovides nvidia-kmod
   ```

3. **Re-check the `rpm2cpio` payloads for file collisions** before trusting the
   `cp -a` into `/usr`. The current extraction is verified not to collide with
   RPM-owned files (notably Fedora's `nvidia-gpu-firmware` does not ship the GSP
   blobs for this driver line); a new driver version can change that:

   ```bash
   dnf5 repoquery -l nvidia-kmod-common | sort > /tmp/nkc.list
   # compare against rpm -qf for each path in the built image
   ```

4. Keep `--setopt=tsflags=noscripts` and the explicit `depmod`/`dracut`;
   scriptlets fail in a container.
5. Confirm the new kernel still carries `CONFIG_SECURITY_SELINUX=y` — the
   `final-verify` gate checks it, because halcyon runs enforcing.
6. `build-initramfs` must run after every change here; it is Stage 14 for this
   reason (last, so the plymouth theme and NVIDIA dracut hooks are baked in).
7. Re-run the whole `final-verify` NVIDIA group and boot-test in a VM before
   pushing a tag. A regression here is not recoverable from the desktop.

### Fallback

If the COPR's prebuilt modules and negativo17 ever drift irreconcilably, the
documented escape hatch is the `rakuos-base` approach: DKMS-build `dkms-nvidia`
against the p03 kernel instead of using prebuilt modules. That is a Stage-K2
change, not a patch.

---

## skill: ci-signing-and-runners

**Use when:** touching `.github/workflows/`, bumping Cosign, or changing runners.

1. **Signing format.** Cosign 3 writes signatures as OCI 1.1 referrers by
   default; containers/image (podman, skopeo, bootc) only reads the legacy
   `sha256-<digest>.sig` tag. `cosign verify` accepts BOTH, so it cannot detect
   the regression. Keep `--new-bundle-format=false --use-signing-config=false
   --registry-referrers-mode=legacy` on `cosign sign`, keep the
   `--new-bundle-format=false` verify step, and keep `cosign-release` pinned
   (Cosign 4 is expected to remove these flags). `verify-github.sh` fails the
   audit if either step is dropped.
2. **Runners.** Pin `ubuntu-24.04`. `ubuntu-latest` migrates to 26.04 between
   2026-10-19 and 2026-11-19. To move: switch one workflow to `ubuntu-26.04`, and
   bump `ublue-os/remove-unwanted-software` past v9 (there is no v10 tag; use the
   commit `ublue-os/image-template` pins).
3. **Publishing.** Only `PUBLISH_BRANCH` (`container`) pushes. Scheduled and
   dispatch runs execute from the repository default branch — if that is not
   `container` (it is `main` locally until changed), the daily rebuild never
   runs this workflow.
4. **Actions.** Pin to a `vN` tag or a full SHA, never a branch. Renovate
   rewrites tags to SHAs; `verify-github.sh` accepts both.
5. Run `just check-github` after any workflow edit.

---

## Splitting this file into Agent Skills

This file is a single registry so it is easy to review and diff. The portable
format used by Claude Code, Codex, Copilot and Cursor is one **directory per
skill** containing a `SKILL.md` with YAML frontmatter, loaded on demand rather
than at session start. If the context cost of this file becomes noticeable
(it is well past the ~500-line guidance for a single skill body), split it:

```
.claude/skills/
  add-build-stage/SKILL.md
  add-rpm-package/SKILL.md
  …
```

Each section above converts mechanically — the `## skill: <name>` heading
becomes the directory name, and the "Use when" / "Do not use for" lines become
the `description`, which is the only text an agent sees before deciding to load
the body:

```markdown
---
name: add-rpm-package
description: >
  Add an RPM to the halcyon image from Fedora, Terra, a COPR or a vendor repo.
  Use when adding a package name to install-packages, install-devtools or
  install-terra. Do not use for non-RPM software (see add-upstream-binary-app).
---
```

Keep this `SKILLS.md` as the index afterwards, with each row linking to its
skill directory.

---

## Where this file lives

- **`/SKILLS.md`** — repository root, beside `AGENTS.md` and `README.md`.
- The pointer from `AGENTS.md` §1 is in place: *"Task-level procedures live in
  `SKILLS.md`."* `.containerignore` already excludes `AGENTS.md`, `SKILLS.md`,
  `MIGRATION.md` (retired — referenced by build comments but not present at the
  root), `TODO.md`, `README.md`, `notes/` and `verify/` from the build context.
- Do **not** place this under `build_files/` (it would be copied into the `ctx`
  stage) or `system_files/shared/` (it would ship inside the image at `/`).