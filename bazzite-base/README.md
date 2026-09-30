# halcyon

A lean, Hyprland-first gaming fork of [Bazzite](https://bazzite.gg), built with
[BlueBuild](https://blue-build.org). GNOME is fully removed; the desktop is
**Hyprland (`hyprland-git`) + Noctalia (`noctalia-git`)** with **greetd + noctalia-greeter**
login. NVIDIA open drivers, the Bazzite gaming stack, and a curated dev toolchain
are baked in — rebuilt daily, calm by definition.

> **Image:** `ghcr.io/aahsnr-work/halcyon:latest` (tracks `bazzite-gnome-nvidia-open:latest`; `linux/amd64` only)
> **Recipe:** [`recipes/halcyon.yml`](recipes/halcyon.yml) (multi-file: ordered `from-file:` includes under `recipes/modules/`)

---

## Install / rebase

**Fresh ISO:** run the `build-iso` workflow (Actions → build-iso → Run workflow)
after a green image build, then download the `halcyon-iso` artifact. This is a
**bootable, installable ISO in the same spirit as the Fedora Workstation ISO**:
it boots (BIOS + UEFI) into a graphical **Anaconda** installer
(`bluebuild generate-iso` runs
[JasonN3/build-container-installer](https://github.com/JasonN3/build-container-installer)
under the hood — the workflow uses the BlueBuild CLI, which drives JasonN3's
installer image `v1.4.0`) and installs the exact published
`ghcr.io/aahsnr-work/halcyon` bootc image onto the chosen disk via Anaconda's
`ostreecontainer` path — partitioning, user creation and all. It is an
installer, not a package-based live install, so what lands on disk is
byte-identical to the published image. A `halcyon.iso-CHECKSUM` file is
generated alongside. Caveats: the ISO is large (the compressed base image is
embedded, ~6+ GB) and too big for free GitHub Releases hosting → delivered as
a workflow artifact; the GHCR package must be public (or the runner
authenticated) for the pull to succeed; on Secure Boot systems, enroll the
Universal Blue MOK after first boot for the NVIDIA akmods — see Bazzite's
Secure Boot docs. Locally you can also run:
`sudo bluebuild generate-iso --iso-name halcyon.iso image ghcr.io/aahsnr-work/halcyon`

**Rebase from an existing Atomic desktop (Bazzite/Silverblue/Bluefin/Kinoite):**

```bash
# 1. rebase to the unsigned image first
rpm-ostree rebase ostree-unverified-registry:ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
# 2. after reboot, switch to the signed tag
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
```

**Verify a build:**

```bash
cosign verify --key cosign.pub ghcr.io/aahsnr-work/halcyon
```

**Secure Boot:** the base's ublue akmods NVIDIA modules require the Universal
Blue MOK key enrolled when Secure Boot is on — see
[Bazzite's Secure Boot documentation](https://secureblue.dev/install-with-secureboot
and the Bazzite docs) for enrollment steps.

---

## What this image is

Boot → greetd/noctalia-greeter → Hyprland → Noctalia first-run wizard. The base image is
`ghcr.io/ublue-os/bazzite-gnome-nvidia-open:latest`, so everything below is
*relative to Bazzite's GNOME NVIDIA-open image*.

### Removed

- **GNOME core & apps** — gnome-shell, mutter, gdm, gnome-session(+wayland), nautilus,
  ptyxis, gnome-control-center, gnome-settings-daemon, gjs, xdg-desktop-portal-gnome,
  firefox RPM (+langpacks), plus the compose-variable GNOME app set
  (evince/loupe/totem/gnome-calculator/… — removed via rpm-filtered script with
  hard verification, not a brittle declarative list).
- **GNOME extensions** — the RPM ones (`gnome-shell-extension-{gsconnect,user-theme}`,
  yafti, rounded-blur, …) via dnf; the 12 directory-installed ones
  (`blur-my-shell`, `burn-my-windows`, `desktop-cube`, `dash-to-dock`-style set,
  `appindicator`, …) via `rm -rf /usr/share/gnome-shell/extensions` + gschema
  recompile. The BlueBuild `gnome-extensions` module is intentionally NOT used
  (it hard-requires `gnome-shell --version` at build time — see NOTES §deviation 1).
- **GNOME config footprint** — dconf `distro.d` bazzite databases, the 5
  silverblue gschema overrides, gnome-background-properties, default wallpaper
  symlinks, dconf-update.service, GNOME mimeapps handlers, Ptyxis skel,
  gnome-ssh-askpass, GNOME motd tip, firefox GNOME config.
- **Display manager** — SDDM config purged (`/etc/sddm.conf.d`), sddm/gdm services
  masked; replaced by greetd + noctalia-greeter (see Added).
- **Handheld / Deck stack** — inputplumber, steamos-manager-powerstation,
  jupiter-fan-control, jupiter-hw-support-btrfs, galileo-mura, steamdeck-dsp,
  powerbuttond, vpower, sdgyrodsu, hid-replay, steamdeck-backgrounds,
  steamdeck-gnome-presets, and their dangling service symlinks.
- **Android** — Waydroid packages + its full file footprint (launchers, polkit
  policy/rules, waydroid ujust recipe).
- **Bling/fastfetch stack** — fastfetch RPM, `/usr/libexec/bazzite-bling-fastfetch`,
  `bazzite-neofetch.sh` profile hook, `bazzite-cli/bling.{sh,fish}`, and the
  `bazzite-cli` ujust recipe (excised from `80-bazzite.just`).
- **Base Flatpak app set** — removed at first boot via `default-flatpaks@v1`
  remove list (firefox, Extension Manager, Protontricks, Warehouse, Mission
  Center, ProtonPlus, the org.gnome.* app set, Refine). **Except** Flatseal and
  DistroShelf, which are kept/re-added (see Flatpak policy).
- **Base font RPMs** — Bazzite's `twitter-twemoji-fonts`,
  `google-noto-sans-cjk-fonts`, `lato-fonts`, `fira-code-fonts`, `nerd-fonts` are
  removed via a reverse-dependency-filtered script. Replaced by the fonts module
  (below). ⚠ **CJK coverage is lost** — re-add `google-noto-sans-cjk-fonts` in
  `removals`-adjacent dnf step if you need CJK glyphs.

### Kept (the Bazzite gaming core)

- **sched_ext / performance:** `scx-scheds`, `scx-tools` (`scx_loader.service`
  stays disabled by default — see sched_ext note). ⚠ **Base variance:** the
  published `bazzite-gnome-nvidia-open:latest` stable image at delivery time
  (2026-09-17) does **not** ship `steamos-manager`/its `-powerstation` subpackage
  contents beyond what main's audit described, `gamemode`, or
  `gamescope-session-ogui-steam` (the stable channel lags bazzite main, which
  does have them). The removal logic treats them as conditional keepers —
  if a future base re-adds them, they are kept (only the `-powerstation`
  subpackage is removed and the stale `desktop = "gnome.desktop"` patched to
  `hyprland.desktop` when present). See NOTES.md §5 for the full variance table;
  use the TODO app list if you want them re-added explicitly.
- **Gaming:** `steam` (bazzite-patched, `/usr/bin/bazzite-steam`), `terra-gamescope`
  (+libs), `terra-mangohud` (x86_64+i686), `umu-launcher`/`umu-wrapper`, `lutris`,
  `bazaar` (RPM), `bazzite-portal`, `bbrew`, `distroshelf-helper` (kept file).
- **Peripherals:** `usbip`, `xwiimote-ng`, `evtest`, `ydotool`, `input-remapper`
  (service disabled in base — unchanged), opt-in `ujust install-openrazer`.
- **Containers:** distrobox + podman (+ user podman socket), `/etc/distrobox`.
- **DistroShelf** — kept as the **system Flatpak** `com.ranfdev.DistroShelf`
  (v4 decision; no stage build), including the base's skel preconfig and
  `/usr/bin/distroshelf-helper`.
- **NVIDIA userland glue:** `ublue-nvidia-flatpak-runtime-sync`/`-verify`,
  `ublue-nvctk-cdi`, akmods COPR repo re-enabled at the end (base behavior).
- **Base repo files** — every repo file Bazzite ships stays, in its final
  enabled/disabled state. halcyon adds and removes its own repos cleanly
  (see the --repoid trap).
- All other stock ujust recipes (`10-update`, `81-fixes`, `82-apps`, `82-beesd`,
  `82-cockpit`, `82-sunshine`, `83-audio`, `84-virt`, `85-image`, `86-windows`,
  `87-framegen`, `88-webapps`, `89-mesa-git`, `90-picker`, `92-verify`,
  `93-update`, `94-protonplus`, `95-bazzite-nvidia`), minus the waydroid/decky/
  deck-session/de ones that reference removed subsystems.

### Added

- **Desktop stack** (from COPR `lionheartp/Hyprland`, install is *unscoped* —
  plain package names with the COPR enabled for the whole transaction, provenance
  verified after, COPR repo file purged):
  `hyprland-git`, `hyprland-guiutils`, `hyprpwcenter`, `noctalia-git`,
  `noctalia-greeter-git`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`
  (+ the GTK/app set: kitty, thunar, papers, gnome-tweaks, …).
- **Login:** `greetd` + `noctalia-greeter-git` (both from COPR `lionheartp/Hyprland`;
  the greeter runs as the `greetd` user — the Arch-convention `greeter` account does
  not exist on Fedora). Config in `/etc/greetd/config.toml` launches the wrapper
  `/usr/bin/noctalia-greeter-session` (absolute path, per docs.noctalia.dev/greeter);
  session list from `/usr/share/wayland-sessions`; state dir `/var/lib/noctalia-greeter`
  (mode 0750, `greetd:greetd`) created via tmpfiles — the COPR package drops
  upstream's tmpfiles rule because it hardcodes the `greeter` user.
- **Browsers/editors (dnf module, repos cleaned up after):** `code` (Microsoft
  repo), `brave-browser` + `brave-origin` (Brave repo), `zen-browser`
  (**COPR `sneexy/zen-browser`, by user directive** — installed in a COPR-only
  transaction so terra, which also packages it, can't win dnf's arbitration),
  `zed` (from the base's pre-existing disabled `terra` repo via
  enable→install→re-disable), `emacs-pgtk` (Fedora).
- **Baked apps (build-time scripts):** Obsidian (AppImage → `/usr/lib/obsidian`),
  Zotero (`/usr/lib/zotero`, auto-update disabled), Pyprland (pip venv →
  `/usr/lib/pyprland`, user service), TeX Live scheme-medium (+latexmk, biber →
  `/usr/lib/texlive`, from a pinned CTAN mirror for reproducible builds). `gcc`,
  `perl`, `jq`, `python3` are deliberately kept (emacs-pgtk native-comp requires
  gcc at runtime; tlmgr/jq/venv runtime needs — see NOTES.md §4 S).
- **First-boot system Flatpaks:** DistroShelf, Flatseal, OnlyOffice DesktopEditors,
  Bitwarden, TickTick.
- **Nix** (pattern from [fu5ha/winter](https://github.com/fu5ha/winter), Apache-2.0):
  `nix` + `nix-daemon` RPMs, `/var/nix` bind-mounted on `/nix` (`var-nix.service`
  + `nix.mount`), tmpfiles for store dirs, profile hook. Home-Manager is NOT
  baked — run `ujust home-manager-setup` after first login.
- **Homebrew:** curated formula set layered on the base's brew — baked at build
  time, seeded pre-login/offline at boot, online catch-up fallback at login.
  Full pipeline documented in [Homebrew pipeline](#homebrew-pipeline).
- **Dotfiles:** BlueBuild `chezmoi` module →
  `https://github.com/aahsnr-configs/dotfiles`, `file-conflict-policy: replace`.
  The repo is public, so first-login init needs no credentials; the
  `chezmoi-init.service` user unit (enabled `--global` for all users) runs
  `chezmoi init --apply` at login only while `~/.local/share/chezmoi/.git` is
  absent — an offline first login simply retries at the next one. The daily
  `chezmoi-update.timer` runs `chezmoi update --no-tty --force`: **local edits
  to managed files are clobbered** — the repo is the source of truth.
- **ujust recipes:** `ujust doom-setup` (clones your Doom config via SSH and
  installs Doom Emacs — needs your SSH keys) and `ujust home-manager-setup`
  (bootstraps standalone Home Manager) from `doom-setup.just` /
  `home-manager-setup.just`, plus the modular personal recipes — `rebase.just`
  (rebases to the published halcyon image), `texlive.just` (user-mode tlmgr
  into `~/texmf`), `cleanup.just` (Nix GC + Flatpak prune + journal trim), and
  `dots.just` (round-trip edits to the dotfiles working copy at the chezmoi
  source path, `~/.local/share/chezmoi`).
  All are shipped via the `justfiles` module and surfaced through
  `/usr/share/ublue-os/just/60-custom.just`.
- **Helpers:** `encrypt-repo`, `git-setup`, `hyprtheme`, `nuke-nvim` in
  `/usr/libexec/halcyon-image/`, on PATH via `/etc/profile.d/image-path.sh`
  (the fuzzy finders and screenshot moved to Python binaries in `/usr/bin`
  — see `files/python-packages/`).
- **Fonts:** Nerd Fonts `JetBrainsMono` + `NerdFontsSymbolsOnly`; Google
  `JetBrains Mono`, `Noto Emoji`, `Noto Color Emoji`.

---

## Homebrew pipeline

The Bazzite base ships Homebrew itself. Halcyon layers a curated formula set
on top — `files/brew/Brewfile`: atuin, bat, btop, bun, cava, chafa, direnv,
dust, eza, fd, fzf, gnuplot, lazygit, opencode, pandoc, pixi, ripgrep,
starship, tealdeer, uv, yazi, zellij (these are the CLI tools of the image;
the base's `ujust bazzite-cli` flow is gone) — and makes them available
**before first login, offline, on every deployment path**: fresh install *and*
rebase. Three phases: build, boot, login. (BlueBuild's own `type: brew` module
was considered and rejected — it installs and maintains brew itself but cannot
manage formulas.)

### What the base provides (left untouched)

- `/usr/share/homebrew.tar.zst` — brew itself (~147 MB, from ublue-os/brew).
- `brew-setup.service` (system, enabled by the base's preset): at boot it
  extracts the tarball to `/home/linuxbrew/.linuxbrew` (`cp -R -n`,
  `chown -R 1000:1000`, marker file `/etc/.linuxbrew`) and
  **skips entirely if the prefix already exists** — the property the seeding
  design builds on.
- `brew-update.timer` / `brew-upgrade.timer` (+ services as uid 1000): keep
  brew and installed formulas current. Not modified by halcyon.
- PATH: the base's `/etc/profile.d/brew.sh` covers interactive shells (brew is
  appended *after* system paths so coreutils/dbus stay native);
  `/etc/environment.d/10-homebrew.conf` (shipped by halcyon) adds brew to
  systemd-user/Wayland/GUI sessions, which never source profile.d.
- Homebrew refuses to run as root; only uid 1000 manages the prefix.

### Why the payload rides in /usr

On bootc/ostree systems `/var` behaves like Docker's `VOLUME /var`: seeded
from the image **only on initial provisioning**, then owned by the machine —
an upgrade or rebase never re-applies image `/var` content, while `/usr` is
swapped wholesale on every deployment. Baking formulas into
`/var/home/linuxbrew` in the image would therefore work exactly once and
silently break on the first rebase. The design instead bakes a payload into
`/usr` (delivered on every deploy) and seeds it into `/var` at boot. A second
constraint: Homebrew bottles are relocated to the prefix they are *poured
into*, so the build-time `brew bundle` must run at the final path
`/home/linuxbrew/.linuxbrew` — staging in a scratch directory and moving the
tree would hardcode broken paths into every formula.

### Phase 1 — build time (`brew.yml`)

1. A `files` module stages `files/brew/Brewfile` to
   `/usr/share/ublue-os/homebrew/Brewfile` early (this module runs before the
   generic files tree copy).
2. `install-brew-bundle.sh` then:
   - creates `/var/home` if missing (the build container's `/home → var/home`
     symlink is dangling — nothing backs it yet) and stages the base tarball
     exactly as `brew-setup.service` does at boot;
   - runs `brew bundle install` as throwaway uid 9000 via `setpriv`, at the
     final path, with 3 retry attempts (Homebrew 5.2+/6+ CLI — the `install`
     subcommand with `HOMEBREW_BUNDLE_FILE`, no lock file written — and a
     legacy-invocation fallback guards against CLI churn in either
     direction);
   - verifies **every** Brewfile formula poured completely (each pour writes
     an `INSTALL_RECEIPT.json` "tab" into its keg);
   - chowns the prefix to 1000:1000 and repacks it to
     `/usr/share/halcyon/brew-bundle.tar.zst` (~1.3 GB compressed — the whole
     prefix including brew itself);
   - removes all staging, including the `/var/home` it created — the image
     layer must carry zero `/var` state.
3. `brew-verify.sh` gates the build: base payload present, Brewfile staged,
   payload present with **every** formula provably inside it (single tar
   listing), and no `/home/linuxbrew` or `/var/home/linuxbrew` leakage into
   the layer.

### Phase 2 — boot time (`halcyon-brew-bundle.service`, system)

One-shot at `multi-user.target`, ordered `After=brew-setup.service`, with
**no network dependency**, gated on the payload existing.
`brew-bundle-extract` diffs the Brewfile against the live Cellar — a formula
counts as present only when its pour completed (every pour writes an
`INSTALL_RECEIPT.json` "tab"; a bare directory is an incomplete pour from a
killed run or power loss) — removes any incomplete pours, and merges the rest
via `cp -R -n` (no-clobber — formulas the user installed or upgraded
themselves are never downgraded), then chowns to 1000:1000.
Because the payload carries the whole prefix, this also self-heals brew
itself if `brew-setup.service` ever fails. On a rebase, the new image ships a
new payload, so newly added formulas appear at the next boot. Everything
happens pre-login and offline; when nothing is missing the unit exits in under
a second.

### Phase 3 — login time (`brew-bundle.service`, user — fallback only)

Runs once per user (sentinel `~/.config/halcyon/.brew-bundle-done`, written
only on success). `brew-bundle-install` fast-paths through direct pour-receipt
checks — no brew invocation, no network — and exits immediately when boot
seeding did its job. Only when formulas are genuinely missing or incomplete
does it wait for the brew binary and run `brew bundle install` online, retried
3× with linear back-off (brew itself reinstalls incomplete formulas
correctly, since their tabs are absent from its database).

### Verification split (module-order aware)

`brew-verify.sh` runs inside `brew.yml` and checks only what exists at that
point in the module sequence. The wiring checks — libexec helpers, both units,
payload at the final path — live in `files-verify.sh`, which runs after the
modules that copy those assets. Both fail the build loudly.

    build:  Brewfile ──► brew bundle install (uid 9000, final path)
                        ──► /usr/share/halcyon/brew-bundle.tar.zst
    boot:   payload ──► diff vs Cellar ──► no-clobber merge ──► /var/home/linuxbrew
    login:  Cellar check ──► (usually) exit 0 ──► (rarely) online brew bundle install

### Adding packages later

Adding a formula is a one-line edit to `files/brew/Brewfile` — no script
changes, ever. Every stage is data-driven and adapts automatically: the
parsers accept quoted or unquoted entries and core or tapped formulas
(`brew "user/tap/name"` is verified as `Cellar/name/`), the build bakes and
receipt-checks it, the boot seeder merges it into rebased machines, the login
fast-path recognizes it, and the base's `brew-upgrade.timer` keeps it current.
Two rules to keep in mind:

- **Formulas only.** A `cask` entry fails the build immediately — casks are a
  macOS concept and do not install on this image. A tapped formula needs its
  `tap "…"` line alongside it so `brew bundle` can resolve it.
- **Removal is asymmetric.** Dropping a line keeps the formula off fresh
  installs and rebased machines (it is simply never seeded), but the boot
  seeder is deliberately additive — it will not uninstall the formula from a
  machine that already has it. Remove those by hand
  (`brew uninstall <formula>`).

## Flatpak policy

`default-flatpaks@v1` (v2 has no `remove:` support). Install/remove lists apply
**at first boot, idempotently** (flatpak state lives in `/var`, outside OSTree
commits — a build-time flatpak module does not exist). `bazzite-flatpak-manager`
stays enabled; it installs nothing, it only enforces remotes/blocklist/EOL
cleanup. The `fedora`/`fedora-testing` flatpak remotes exist-but-disabled — that
is the base's deliberate design (unit `flatpak-add-fedora-repos.service` adds
flathub + the fedora remotes disabled); they are left as-is.

## sched_ext status

`sched_ext` is in the base kernel with `scx-scheds`/`scx_tools` kept and
`scx_loader.service` disabled by default (as shipped). Use `scxctl` or enable
`scx_loader.service` to try schedulers. ⚠ `BORE` is a CachyOS kernel patch and is
NOT on Fedora kernels — the nearest sched_ext equivalent is `scx_bpfland`.

## Known caveats

- **OSTree `/usr/local` gotcha:** anything baked into the image must live
  under `/usr` (halcyon bakes apps into `/usr/lib/*` for this reason).
  `/usr/local` is a symlink to `/var/usrlocal` — it does not update across
  rebases, so content placed there at build time silently vanishes or goes
  stale on the next rebase.
- **XDG autostart:** Hyprland does not run `/etc/xdg/autostart` natively. Let
  Noctalia handle XDG autostart or add `exec-once` lines in your Hyprland config.
  (The base's `/etc/xdg/autostart/steam.desktop` autostart entry is absent in
  the current stable base — launch Steam from Noctalia/your own autostart.)
- **Base-channel variance:** the published stable base lags bazzite main — it
  currently ships no `gamemode`, no `gamescope-session-plus` sessions, and no
  `steamos-manager`. The recipes keep them if a future base re-adds them
  (removal logic is conditional); see NOTES.md §5 for the full variance table
  and how to re-add them explicitly via the TODO app list if you want them now.
- **No terminal is baked** — GNOME Terminal/Console/Ptyxis are gone by design and
  none is invented for you. Your chezmoi dots + Brewfile own this; add one via
  the TODO extension point in `apps.yml` if you want a GUI terminal in the image.
- **Obsidian version:** Obsidian's GitHub `releases/latest` is periodically
  mobile-only (no AppImage). `install-obsidian.sh` scans the last 15 releases
  for the newest one shipping an AppImage and verifies the download against
  the asset's sha256 `digest` from the GitHub API (pinned fallback URL if the
  API is unreachable — that fallback is TLS-verified only).
- **TODO(user) extension points:** personal shell setup (chezmoi repo), branding
  assets (`files/system/usr/share/plymouth/themes/halcyon/`,
  `files/system/usr/share/backgrounds/halcyon/`, motd), extra apps
  (`recipes/modules/apps.yml` bottom section), optional Hyprland companion apps
  (`recipes/modules/desktop.yml` comment).

## The `--repoid` trap — read before editing

BlueBuild's `dnf` module executes every `repo:`-scoped install entry as
`dnf5 --repoid <repo> install <pkg>` — and dnf5's `--repoid` confines the
**entire transaction, dependency resolution included**, to that single
repository. Fedora/updates become invisible to the solver and installs fail with
broken i686 multilib candidates. **Never use `repo:`-scoped entries in this
repo.** Install plain package names with the needed repos enabled for the whole
transaction (unique names make provenance unambiguous), then verify provenance
with `rpm -q --qf '%{name} (vendor: %{VENDOR})' <pkgs>` — COPR builds stamp
`Fedora Copr - user <name>` as their vendor (dnf5's from-repo history is
unavailable on rpm-ostree-based images). The recipes
enforce `install-weak-deps: false` everywhere and post-install provenance guards.

## Build & CI

- `build.yml` (daily cron 08:00 UTC, push, PR) → `blue-build/github-action@v1.12`
  → signs with cosign (`SIGNING_SECRET`) and publishes to GHCR.
- `build-iso.yml` (manual) → ISO artifact from the published image.
- dependabot keeps the actions current (daily).
- Local test build: `bluebuild build recipes/halcyon.yml` (podman).

## Repo tooling

- `files/python-packages/` — eleven stdlib-only Python packages installed into
  one shared venv (`/usr/lib/halcyon-python`) at build time, each console
  script symlinked separately into `/usr/bin`: `dump-to-markdown` plus ten
  helpers that replace the former bash versions in
  `/usr/libexec/halcyon-image` (`fconf`, `fe`, `ff`, `fkill`, `fp`, `fssh`,
  `rmi`, `rmtmp`, `screenshot`, `se`). Installed by
  `install-python-packages.sh`, verified by `build-scripts-verify.sh`.
  Dev use: `uv tool install ./files/python-packages/<name>`.

## Credits & licenses

- [Universal Blue](https://universal-blue.org) & [Bazzite](https://bazzite.gg)
  (Apache-2.0) — base image and the gaming stack.
- [BlueBuild](https://blue-build.org) — build system, modules, CI action.
- [fu5ha/winter](https://github.com/fu5ha/winter) (Apache-2.0) — the nix
  bind-mount pattern (`var-nix.service`, `nix.mount`, tmpfiles, profile hook).
- [lionheartp/Hyprland COPR](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/)
  — `hyprland-git`, `noctalia-git` & friends.
- [noctalia](https://github.com/noctalia-dev/noctalia) & [noctalia-greeter](https://github.com/noctalia-dev/noctalia-greeter) — the desktop and the greeter.
- [DistroShelf](https://github.com/ranfdev/DistroShelf) — Flatpak app.
- [JasonN3/build-container-installer](https://github.com/JasonN3/build-container-installer)
  — underlies `bluebuild generate-iso`.
- [greetd](https://git.sr.ht/~kennylevinsen/greetd).
