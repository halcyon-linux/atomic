# bazzite-fork

A single custom **Fedora Atomic / bootc** image: a desktop-free Universal Blue
base with the **NVIDIA (open) driver**, the **Hyprland** Wayland compositor and
the **ly** display manager baked in, plus every application, font, Flatpak,
dotfile and Homebrew package needed at first login -- ready to boot straight
into a working Hyprland session.

The published image name matches this repository (`bazzite-fork`), which
keeps the GHCR package automatically linked to the repo. It is built with
the same plain-bash + `Containerfile` build structure as
[ublue-os/bazzite](https://github.com/ublue-os/bazzite), but on top of the
desktop-free `ghcr.io/ublue-os/base-main` image instead of a desktop image
that has to be taken apart again.

---

## Highlights

- **Immutable by design** -- everything is baked into the image at build time;
  the running system is a signed, atomic, transactional `bootc` image that is
  updated by rebasing, never by mutating `/usr`.
- **NVIDIA (open) driver baked in** -- pulled from the matching
  `ghcr.io/ublue-os/akmods-nvidia-open` image and verified against the exact
  kernel in the base image (see [Kernel automation](#kernel-automation)).
- **Zero-configuration first login** -- dotfiles, Homebrew packages, user
  services and Flatpaks are set up automatically for every new user.
- **Self-maintaining** -- a daily CI cron rebuilds and republishes the image,
  and Renovate keeps the GitHub Actions dependencies current.

---

## What is baked in

### Base

| | |
|---|---|
| Base image | `ghcr.io/ublue-os/base-main:44` -- the same Fedora Atomic/bootc foundation as `silverblue-main`/`kinoite-main`, with **no desktop environment** |
| Fedora version | 44 |
| Architecture | x86_64 |
| Initramfs | Rebuilt at build time with dracut (`--no-hostonly`, `ostree` + `fido2` modules added) |

### Display manager and desktop

| | |
|---|---|
| Display manager | [`ly`](https://github.com/fairyglade/ly) on tty2 (from the official Fedora repository; `getty@tty2` is masked, and `ly` gets the `xdm_exec_t` SELinux context) |
| Compositor | `hyprland-git` from the [`lionheartp/Hyprland`](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/) COPR (priority 98 so it wins over Fedora) |
| Desktop extras | `noctalia-git`, `nwg-look`, `qt6ct`, `xdg-desktop-portal-hyprland`, `cliphist` |

### Packages from the Fedora repositories

Installed with weak dependencies disabled. Notable entries: `chezmoi`,
`direnv`, `zsh`, `kitty`, `emacs-pgtk`, `neovim`, `mpv`, `imv`, `grim`,
`slurp`, `swappy`, `zathura`, `bleachbit`, `fail2ban`, `ddcutil`,
`brightnessctl`, `distrobox`, `gnome-keyring`, `cargo`, `go`, `nodejs`,
`pipx`, `tree-sitter-cli`, `transmission-gtk`, `lynis` and more.

<details>
<summary>Full list</summary>

```
accountsservice bleachbit bluez-tools brightnessctl cargo chezmoi cmake
cronie curl ddcutil direnv distrobox emacs-pgtk fail2ban file-roller
fontconfig fonts-filesystem gcc-c++ git gnome-keyring gnome-tweaks go grim
gsettings-desktop-schemas gtk4-layer-shell gzip ImageMagick imv inotify-tools
jq kitty kitty-shell-integration kitty-terminfo libinput-utils logrotate ly
lynis man-db mpv neovim ninja-build nodejs npm papers papirus-icon-theme pipx
pkgconf-pkg-config policycoreutils-python-utils pymol qt5ct slurp sqlite
swappy transmission-gtk tree-sitter-cli udiskie xdg-desktop-portal
xdg-user-dirs xdg-user-dirs-gtk xhost xorg-x11-server-Xorg
xorg-x11-server-Xwayland xorg-x11-xauth zathura zathura-pdf-poppler
zathura-plugins-all zsh
```

</details>

### Applications

| Application | Source | Notes |
|---|---|---|
| zed | Terra repository | The only package taken from Terra; the repo is enabled just for this install |
| Visual Studio Code | Microsoft RPM repo | Repo file ships with the image and is left disabled |
| Brave (+ Brave Origin) | Brave RPM repository | Repo file removed after install |
| Obsidian | AppImage | Latest release extracted into `/usr/lib/obsidian`, linked into `/usr/bin` with desktop entry + icon |
| Zotero | Official tarball | Installed to `/usr/lib/zotero` with `DisableAppUpdate` policy |
| Pyprland | GitHub release | Isolated Python venv in `/usr/lib/pyprland`, plus a `pyprland` systemd **user** service (no `exec-once` needed in the Hyprland config) |
| TeX Live | -- | `install-texlive.sh` exists but is **disabled** (commented out in the `Containerfile`) |

### Fonts

- **Nerd Fonts**: `JetBrainsMono`, `NerdFontsSymbolsOnly`
- **Google Fonts**: `JetBrains Mono`, `Noto Emoji`, `Noto Color Emoji`

Downloaded from the official sources at build time and cached with
`fc-cache`.

### Homebrew

The prebuilt Homebrew bundle from the `ghcr.io/ublue-os/brew` image is baked
into `/usr/share`, and a manifest of CLI tools is installed **per user** on
first login (and kept up to date by timers):

<details>
<summary>Homebrew package list</summary>

```
atuin bat btop bun cava chafa direnv dust eza fd fzf git gh git-lfs gnuplot
lazygit pandoc pixi ripgrep starship tealdeer uv yazi zellij
```

</details>

### Dotfiles (chezmoi)

[`chezmoi`](https://www.chezmoi.io/) applies the
[`aahsnr-configs/dots`](https://github.com/aahsnr-configs/dots) repository into
`/etc/skel` **at build time**, so every new user starts with the dotfiles
already in place. Two user services keep them fresh after that:

- `chezmoi-init.service` -- re-applies the dotfiles on first login
- `chezmoi-update.timer` -- keeps them updated

### Flatpaks

A bash port of BlueBuild's `default-flatpaks@v2` module manages both scopes:

- **Removal**: stock GNOME core Flatpaks (Calculator, Calendar, Loupe,
  Snapshot, TextEditor, ...) are uninstalled at build time if present; the manifest in
  `/etc/hyprland-image/system-flatpaks-remove` makes the runtime service retry
  removals if a base image update ever reintroduces one.
- **Install**: the Flathub remote is configured for the system **and** user
  scope; the Flatpaks to install live in
  `build_files/install/setup-default-flatpaks.sh` (currently empty) and are
  compiled into `/etc/hyprland-image/default-flatpaks.json`. Every configured
  ID is validated against the Flathub API at build time, so a typo fails the
  build instead of silently failing at every boot.
- **Runtime**: `system-flatpak-setup.timer` (every boot + daily) and
  `user-flatpak-setup.timer` keep both scopes in sync.
- **CLI**: `hyprland-flatpak-manager` (`show` / `apply` / `enable` /
  `disable`) inspects and controls the whole setup.

### Cleanliness

- All external repositories (COPR, Terra, Microsoft, Brave) are **disabled or
  removed** once their packages are baked in -- the shipped image only uses
  the official Fedora repositories.
- Every build stage ends with a `cleanup` pass, and a final `finalize` pass
  sweeps `/var`, relocates build-time users into `/usr/lib/{passwd,group}`
  (so `/etc` can reset safely across deployments) and rebuilds the initramfs.
- The build finishes with `bootc container lint` to catch bootc image issues.

---

## Baked-in services

| Scope | Unit | Purpose |
|---|---|---|
| system | `ly@tty2.service` | Display manager on tty2 (`getty@tty2` masked) |
| system | `accounts-daemon.service` | User account management |
| system | `podman.socket` | Podman API socket |
| system | `brew-setup.service` | Extracts the Homebrew bundle on first boot |
| system | `brew-update.timer` / `brew-upgrade.timer` | Keeps Homebrew current |
| system | `system-flatpak-setup.service` + `.timer` | Configures Flathub and installs/removes system Flatpaks |
| system | `nvidia-powerd.service` | NVIDIA dynamic power management |
| user | `chezmoi-init.service` + `chezmoi-update.timer` | Dotfiles setup and updates |
| user | `pyprland.service` | Pyprland daemon (Hyprland session) |
| user | `brew-packages-setup.service` | Installs the Homebrew manifest for the user |
| user | `user-flatpak-setup.timer` | Keeps user Flatpaks in sync |

All user services are enabled **globally**, so they run for every user on
their first login.

---

## ujust recipes

| Recipe | Purpose |
|---|---|
| `ujust update` | topgrade-style maintenance sweep: firmware (fwupd), Flatpaks, manuals, hyprpm, Cargo, Doom Emacs, VS Code extensions, tldr, pixi, uv, bun, yazi, Homebrew, distrobox, podman auto-update, zsh plugins |
| `ujust rebase [tag]` | Rebase to the latest image build (`bootc upgrade`), or `bootc switch` to a specific tag |
| `ujust doom-setup` | Clone and install Doom Emacs after first login (aborts if `~/.config/doom` already exists) |
| `ujust flatpaks-show` | Print the Flatpaks configured by this image |
| `ujust flatpaks-apply` | Manually re-run the Flatpak setup (system + user) |
| `ujust update-image` | Alias for `ujust rebase` |
| `ujust upgrade` | Alias for `ujust update` |

> System (rpm/bootc) updates happen by rebasing to a new image build, not by
> `dnf upgrade` -- `ujust update` covers everything else.

---

## Building locally

Requirements: `podman` (or Docker with BuildKit), `just` (optional, for the
developer recipes) and a network connection to pull the base images.

```bash
# with podman directly
podman build --network host .

# or via just
just build
just lint    # shellcheck all bash scripts
just stages  # show the Containerfile stages
```

### Build arguments

All arguments have sensible defaults and can be overridden with
`--build-arg`:

| Argument | Default | Purpose |
|---|---|---|
| `BASE_IMAGE_NAME` | `base` | Universal Blue main-family image (`base`, `silverblue`, ...) |
| `FEDORA_VERSION` | `44` | Fedora release used for the base and akmods images |
| `ARCH` | `x86_64` | Target architecture |
| `KERNEL_FLAVOR` | `main` | ublue akmods kernel flavour (rolling tag `main-44-x86_64`) |
| `NVIDIA_FLAVOR` | `nvidia-open` | NVIDIA driver flavour (`nvidia-open`, `nvidia`) |
| `IMAGE_NAME` | `bazzite-fork` | Image name baked into `image-info.json` / `os-release` (kept equal to the repository name so GHCR auto-links the package) |
| `IMAGE_VENDOR` | `ublue-os` | Registry namespace (set to the repo owner in CI) |
| `SHA_HEAD_SHORT` / `VERSION_TAG` / `VERSION_PRETTY` | *(empty)* | Version metadata written into the image |

There is **no kernel version to pin anywhere** -- the akmods image is pulled
via a rolling tag.

### Kernel automation

Universal Blue keeps the rolling tag `${KERNEL_FLAVOR}-${FEDORA_VERSION}-${ARCH}`
pointed at the newest kernel build for the flavour. Because the base image and
the akmods image update independently, they can drift apart. The build
guards against this:

1. `build.sh verify-kernel` compares the base image's kernel with the kernel
   the `kmod-nvidia` RPM was built for and **fails loudly on a mismatch**.
2. The daily CI cron retries until the two align again, so the image
   self-heals with zero manual work.

---

## CI

`.github/workflows/build.yml` rebuilds the image on:

- push to `main` (Markdown/docs changes ignored)
- pull requests and merge groups
- a **daily cron** at 06:10 UTC (shortly after the ublue base images build)
- manual `workflow_dispatch`

On `main` it pushes to GHCR under the repository owner with the tags

- `ghcr.io/<owner>/bazzite-fork:44`
- `ghcr.io/<owner>/bazzite-fork:44-YYYYMMDD`
- `ghcr.io/<owner>/bazzite-fork:44-<short-sha>`

and **signs** the first two with cosign using the private key from the
`SIGNING_SECRET` repository secret (signing is skipped if the secret is not
set). The matching public key is committed as [`cosign.pub`](cosign.pub).

[Renovate](.github/renovate.json5) keeps the GitHub Actions versions up to
date (the image itself tracks rolling tags, so there is nothing to pin).

---

## Deploying / rebasing

> Replace `<owner>` with the GitHub account the image is published under.

**From an existing Fedora Atomic / ublue system** (bootc):

```bash
sudo bootc switch ostree-image-signed:docker://ghcr.io/<owner>/bazzite-fork:44
systemctl reboot
```

**From a system still using rpm-ostree:**

```bash
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/<owner>/bazzite-fork:44
systemctl reboot
```

Or just run `ujust rebase` (see [ujust recipes](#ujust-recipes)) on a system
already running this image.

### What happens on first login

1. `ly` presents a greeter on tty2.
2. `brew-setup.service` has already extracted Homebrew on first boot;
   `brew-packages-setup.service` installs the user's CLI tool manifest.
3. `chezmoi-init.service` applies the dotfiles for the user (they are already
   pre-seeded in `/etc/skel`, so new users get them immediately).
4. `system-flatpak-setup` / `user-flatpak-setup` configure Flathub and install
   the configured Flatpaks (with desktop notifications).
5. Hyprland starts; `pyprland.service` runs the Pyprland daemon.

---

## Repository layout

```
.
├── Containerfile                        # The whole build, stage by stage
├── Justfile                             # Local dev recipes (build / lint / stages)
├── cosign.pub                           # Public key for verifying the image
├── build_files/
│   ├── build.sh                         # Main build driver (repos, packages, kernel guard, services)
│   ├── install/                         # Per-application install/setup scripts
│   ├── cleanup                          # Per-stage cleanup pass
│   ├── finalize                         # Final cleanup + account relocation
│   ├── image-info                       # Writes image-info.json and os-release
│   ├── build-initramfs                  # dracut initramfs rebuild
│   ├── global-remove                    # Unwanted base packages removal
│   └── ghcurl                           # curl helper with GitHub API auth
├── system_files/
│   ├── etc/                             # profile.d (brew), yum repos (vscode)
│   ├── usr/bin/                         # hyprland-flatpak-manager CLI
│   ├── usr/libexec/hyprland-image/      # Runtime Flatpak + Homebrew setup helpers
│   ├── usr/lib/systemd/                 # system & user units + timers
│   ├── usr/lib/dracut/ modprobe.d/      # NVIDIA initramfs/kernel config
│   └── usr/share/ublue-os/just/         # ujust recipes (update, rebase, doom, flatpaks)
└── .github/                             # build workflow + Renovate config
```

---

## License

Apache-2.0 -- see [LICENSE](LICENSE). This project is a fork of the build
structure of [ublue-os/bazzite](https://github.com/ublue-os/bazzite).
