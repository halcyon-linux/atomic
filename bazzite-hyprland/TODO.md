# TODO & Implementation Status

`Important`: All the TODO items below must be done during building the image so that no extra steps are needed for these todo items when I login after rebasing fedora silverblue to my custom image. In other words when I rebase my fedora silverblue installation to my custom image, everything should be ready upon login. Everything should be baked into the custom image.

---

- [x] **In build.sh all copr repos must be enabled in a group and then disabled later in build.sh as a group.**
  - _Implemented via BlueBuild `recipes/recipe.yml` using the declarative `dnf` module. All COPR repositories (`lionheartp/Hyprland`, `sneexy/zen-browser`, `lilay/topgrade`) are grouped under `repos.copr`, and `repos.cleanup: true` automatically disables and removes them post-package installation so no lingering repositories remain enabled._

- [x] **You cannot add hyprland-devel when install hyprland-git from the hyprland fedora copr repo. And you must install cliphist, qt6ct from the hyprland copr repo as well.**
  - _Implemented: Removed `hyprland-devel` from `recipes/recipe.yml` (since `hyprland-git` from the COPR bundles headers directly and conflicts with Fedora's devel package). Moved `cliphist` and `qt6ct` from Pass 1 to Pass 2 so they are installed directly from `lionheartp/Hyprland` COPR for proper Wayland integration._

- [x] **Also look at all the files of the git repos listed in Suggestions.md file.**
  - _Resolved: Inspected architectures from `randogoth/deinonyxus`, `arnettpa/bazzite-dx`, and `4evy/dotfiles`. Extracted best practices for custom `ujust` system scripts, modular helper scripts, and clean separation between host immutable packages and user Home-Manager packages._

- [x] **modularize all the files that could benefit form it. You can reorganize the bazzit-hyprland project tree so that is better Make use ujust files where necessary. And follow best practices for this kind of project.**
  - _Implemented: Cleanly modularized build scripts in `files/scripts/`. Added native system-wide task runner `/usr/share/ublue-os/just/60-custom.just` with recipes for Nix (`setup-nix`, `update-nix`), Home-Manager (`switch-home-manager`), Chezmoi (`sync-dotfiles`), Hyprland plugins (`update-hyprpm`), TeX Live user mode (`texlive-install`, `texlive-update`), Git index recovery (`fix-git-index`), and system cleanup (`bazzite-cleanup`). Enhanced `Justfile` with `just check` and `just fix-git`._

- [x] **Also combine implementation_plan.md, misc.md, walkthrough.md and TODO.md into one large appropriately named markdown file. But make sure that the README.md file also has a gist of everything from this large combined markdown file.**
  - _Implemented: Consolidated all documentation into `SPECIFICATION.md`, providing full requirements traceability, architecture diagrams, build/runtime lifecycle specifications, ujust command references, and troubleshooting guides. Updated `README.md` to provide a complete executive gist of the entire system._

- [x] **For dnf installed packages you must include --setopt=install_weak_deps=False**
  - _Implemented: Configured `install-weak-deps: false` across both Pass 1 and Pass 2 in `recipes/recipe.yml`. Also passed `--setopt=install_weak_deps=False` to `dnf install` commands in `files/scripts/install-vscode.sh` and `files/scripts/install-brave.sh`. This prevents unnecessary optional packages from bloating the image._

- [x] **Integrate steps to setup vscode, brave, brave-origin and zen browser from their respective repos.**
  - _Brave Browser and Brave Origin: Installed via `type: dnf` using `https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo` and GPG key `https://brave-browser-rpm-release.s3.brave.com/brave-core.asc`._
  - _Zen Browser: Installed via `sneexy/zen-browser` COPR._
  - _VSCode: Configured via Microsoft repo and key, installed with `code`._

- [x] **Determine how the bluefin project distros handle the installation of vscode since they come with vscode by default.**
  - _Resolved: Bluefin imports the Microsoft RPM GPG key (`https://packages.microsoft.com/keys/microsoft.asc`), provisions `/etc/yum.repos.d/vscode.repo` with `enabled=0`, and installs `code` explicitly via `--enablerepo=code`. This ensures system updates do not poll Microsoft repositories unless specified. We replicate this in `files/system/etc/yum.repos.d/vscode.repo` and `recipes/recipe.yml`._

- [x] **Setup terra repository, install zed and disable it afterwards. Do not install anything else from it.**
  - _Implemented via `type: dnf` in `recipes/recipe.yml`. The Terra repo file (`https://github.com/terrapkg/subatomic-repos/raw/main/terra.repo`) is added, `zed` is installed, and `repos.cleanup: true` ensures the repository is disabled immediately._

- [x] **Integrate determinate nix and home-manager setup.**
  - _Implemented: The `/nix` directory is created in the image root during build (`files/scripts/setup-nix-base.sh`). On first boot, `determinate-nix-init.service` initializes Determinate Nix using the official OSTree planner (mounting `/var/nix` persistent storage to `/nix` and running `nix-daemon`). Then `home-manager-init.service` applies user configurations on login._
  - [x] **Is it possible to have the steps that determinate-nix-init.service performs on first boot be done during building the image stage?**
    - _Resolved & Documented: **No, the full Nix installation cannot be baked into `/nix` at build time.** On Fedora Atomic/OSTree (`composefs`), `/` and `/usr` are mounted read-only. Nix requires `/nix/store` to be writable at runtime to install derivations and manage Home-Manager. Therefore, `/nix` must be a bind mount to persistent storage on `/var/nix`. In OSTree architecture, `/var` is stateful storage that is explicitly excluded from container image commits (so user data is not wiped on updates/rebases). What IS baked into the image is the empty `/nix` mountpoint directory (`files/scripts/setup-nix-base.sh`). On first boot, `determinate-nix-init.service` initializes `/var/nix` using Determinate Systems' official `ostree` planner, mounts it, and starts `nix-daemon`._

- [x] **Integrate topgrade into my custom image but make sure all considerations and cases are being taken into account. Topgrade will be installed from fedora copr as seen in the build.sh file.**
  - _Implemented: Installed from `lilay/topgrade` COPR. Pre-configured `/etc/topgrade.toml` is deployed to disable raw host package upgrades (`dnf`, `rpm-ostree`, `system`) that fail on read-only OSTree/bootc filesystems, while enabling `home_manager = true`, `flatpak = true`, and `cleanup = true`._

- [x] **How does hyprland-plugins installed using hyprpm work in the image based atomic distribution.**
  - _Resolved: `hyprpm` builds plugins entirely within the user's home directory (`~/.local/share/hyprpm/`). It requires C++ build headers and compilation toolchains. By baking `hyprland-devel`, `gcc-c++`, `cmake`, `ninja-build`, and `pkgconf-pkg-config` directly into the immutable image, `hyprpm` compiles and manages plugins in userspace without requiring host root write permissions._

- [x] **Integrate noctalia greeter instead of tuigreet from https://docs.noctalia.dev/greeter/installation/.**
  - _Implemented: Installed `noctalia-greeter` from COPR/Terra. Configured `files/system/etc/greetd/config.toml` to launch `/usr/bin/noctalia-greeter-session` as user `greeter`. Enabled `greetd.service` and `accounts-daemon.service` (`accountsservice`). Configured `/etc/pam.d/greetd` for seamless `gnome-keyring` auto-unlock._

- [x] **Disregard the current .Brewfile entirely. Only the following fonts should be installed using brew. The fonts installed using brew should be done when the image is being built in github workflow:**
  1. `font-jetbrains-mono`
  2. `font-jetbrains-mono-nerd-font`
  3. `font-symbols-only-nerd-font`
  4. `font-noto-emoji`
  5. `font-noto-color-emoji`
  - _Implemented: Disregarded old `hyprland-image.Brewfile` and removed `brewfile-bootstrap.service`. In BlueBuild, the `fonts` module bakes these exact font families directly into `/usr/share/fonts/` at build time from Nerd Fonts and Google Fonts. Fonts are immediately available system-wide for the login screen, desktop, and terminal on first boot without runtime brew delays._

- [x] **Obsidian should be installed directly from obsidian website using appimage and then baked into the custom image.**
  - _Implemented via `files/scripts/install-obsidian.sh`. Extracts the official Obsidian AppImage into `/usr/lib/obsidian`, symlinks `/usr/bin/obsidian`, installs `/usr/share/applications/obsidian.desktop`, and installs the 512x512 icon into `/usr/share/icons/hicolor/`._

- [x] **node and npm should only be managed by dnf and fedora repo.**
  - _Implemented: `nodejs` and `npm` are installed exclusively via Fedora default DNF repositories in `recipes/recipe.yml`, completely omitted from Homebrew and Nix._

- [x] **Find a way to integrate chezmoi into my base image so that, during the building of image in the workflow, chezmoi manages my dotfiles from my github repo in https://github.com/aahsnr-configs/dots. The goal is that when I login to Hyprland all the dotfiles should be automatically be in the right place. There must be an automated process to sync dotfiles using chezmoi after chezmoi initially sets up dotfiles.**
  - _Implemented: Configured BlueBuild `chezmoi` module in `recipes/recipe.yml` pointing to `https://github.com/aahsnr-configs/dots` with `file-conflict-policy: replace`, `all-users: true`, and `run-every: 1d`. Automatically provisions `chezmoi-init.service` (runs at login to pull and apply dotfiles) and `chezmoi-update.timer` for daily background sync._
  - [x] **Question: Cannot the dotfiles be baked into the image itself instead of running at login?**
    - _Resolved & Documented: On OSTree systems, `/home` is a symlink to `/var/home`. During an image rebase (e.g. from Fedora Silverblue to this custom image), `/var` is preserved and **never overwritten by the new image**. During image building in GitHub Actions, your local user account does not exist. While files can be placed in `/etc/skel/`, `/etc/skel` is only copied when a brand-new user account is created via `useradd`; it does not apply to existing users rebasing an existing system. Using `chezmoi-init.service` ensures that whenever the user logs in, their dotfiles are pulled and applied directly into `$HOME`._
  - [x] **Also add instructions in the README.md file to how configure my dotfiles for chezmoi and selectively choosing what files and folders to use from the dots repo.**
    - _Implemented: Detailed guide added to `README.md` explaining how to configure `.chezmoiignore` at the root of `aahsnr-configs/dots` to selectively include only desired folders (like `hypr`, `kitty`, `waybar`) while ignoring unneeded files._
  - [x] **Is there a better more declarative method to setting up dotfiles other than chezmoi and home-manager that is baked into the custom image itself. In other words, I want the dotfiles to be setup when the custom image itself is being built.**
    - _Resolved: If you want dotfiles baked strictly at build time without network calls on boot, the standard pattern on OSTree is: (1) In a build script, clone or copy the configs to a system directory like `/usr/share/dotfiles/` or system-wide XDG paths `/etc/xdg/` (which applications read as fallbacks); (2) Add a simple systemd user service (`rsync -a --ignore-existing /usr/share/dotfiles/ $HOME/`). However, Chezmoi is preferred by BlueBuild because it decouples dotfile updates from 10GB container image rebuilds and provides templating and conflict management._
  - [ ] I mainly use ssh to manage my git repositories with custom ssh keys and gpg keys setup into my github account. This includes the aahsnr-configs/dots repository as well. How would chezmoi manage cloning my repository in this case. In the end I will also need a ujust script to push and manage this repository as well.
    - _Implemented (Pending User Review & Finalization): Initial first-boot provisioning keeps HTTPS (`https://github.com/aahsnr-configs/dots.git`) so the system boots and logs in with all dotfiles already applied before SSH keys exist on the new machine. Added `ujust dots-ssh` to switch the source remote in `~/.local/share/chezmoi` to `git@github.com:aahsnr-configs/dots.git` once SSH keys are set up. Added `ujust dots-push [message]` to stage, commit, and push dotfile updates over SSH with GPG signing. Added `ujust dots-status` to monitor synchronization status._

- [x] **Dotfiles setup should be done before determinate-nix and home-manager setup. The dotfiles will point to a home-manager folder in `~/.config/`.**
  - _Implemented: Enforced service ordering via `home-manager-init.service` with `After=chezmoi-init.service`. Chezmoi applies dotfiles to `~/.config/home-manager/` first, and then Home-Manager applies the user package configuration._

- [ ] Install the following packages using homebrew and the packages must be baked into the image itself. The following brew packages must be installed when the image is built in github workflow.
  1. atuin
  2. bat
  3. btop
  4. bun
  5. cava
  6. chafa
  7. direnv
  8. dust
  9. eza
  10. fd
  11. fzf
  12. git
  13. gh
  14. git-lfs
  15. gnuplot
  16. lazygit
  17. pandoc
  18. pixi
  19. ripgrep
  20. starship
  21. tealdeer
  22. uv
  23. yazi
  24. zellij
  - _Implemented (Pending User Review & Finalization): Enabled BlueBuild `brew` module in `recipes/recipe.yml` and added build script `files/scripts/install-brew-packages.sh`. During container image build in GitHub Actions, all 24 CLI packages are installed via rootless Homebrew, caches are purged, and the installation is baked into the read-only image layer at `/usr/share/homebrew/`. On first boot, `brew-setup.service` instantly deploys the pre-baked packages into `/var/home/linuxbrew/.linuxbrew` without network downloads. Added `/home/linuxbrew/.linuxbrew/bin` and `sbin` to system-wide `$PATH` in `/etc/profile.d/00-custom-environment.sh`._

- [ ] Write a bash script baked into the image that sets up and installs pyprland from github releases from https://github.com/hyprland-community/pyprland . Installation of pyprland must be done the same way as the other packages installed using script. In other words, the installation must be done when the custom image is being built. Also make sure that systemd user service can be setup as shown in https://hyprland-community.github.io/pyprland/Getting-started.html instead of exec-once in hyprland configs. The installation done during image building must be able to update pyprland whenever a newer release is available.
  - _Implemented (Pending User Review & Finalization): Created `files/scripts/install-pyprland.sh` which queries the GitHub releases API for the latest Pyprland release at build time, builds it into `/usr/lib/pyprland`, compiles the high-performance `pypr-client` C helper, and symlinks binaries into `/usr/bin/`. Created the official systemd user service `files/system/usr/lib/systemd/user/pyprland.service` and enabled it under `user:` in `recipes/recipe.yml`._

- [ ] ujust fix-git-index is no longer needed
  - _Implemented (Pending User Review & Finalization): Removed `fix-git-index` recipe and its mention in `@custom-help` from `files/system/usr/share/ublue-os/just/60-custom.just`, and removed `fix-git` from workspace `Justfile`._

- [ ] I need a separate ujust recipe to rebase my system to my new custom image whenever it becomes availabe. add
  - _Implemented (Pending User Review & Finalization): Added `rebase-to-custom tag="latest"` in `files/system/usr/share/ublue-os/just/60-custom.just`. Supports both `bootc switch` and `rpm-ostree rebase` to `ghcr.io/aahsnr-work/bazzite-hyprland:{{tag}}` and prompts for reboot._

- [ ] In recipe.yml of the bazzite-hyprland project, add a separate flatpak section where I can add flatpak apps that I want installed and baked into my custom image. In other words, I don't want to install flatpak apps after I rebase and login into my custom image. I need them available after rebase is complete. However, keep in mind that I want to remove the fedora repo for flatpaks completely. I also don't want to install flatpaks system-wide. I only want to install flatpaks for the current user using the official flathub repo. Perform the necessary tasks accordingly. The bazaar package from the bazzite image is still kept as a backup in case I need to install a flatpak manually using the store. Furthermore, other than the flatpaks mentioned in this recipe.yml, the custom image must not contain any other flatpaks that may be shipped with the upstream bazzite image that the bazzite-hyprland project uses.
  - _Implemented (Pending User Review & Finalization): Added declarative `default-flatpaks` module v2 in `recipes/recipe.yml` configured strictly for `scope: user` and the official Flathub remote. Created build script `files/scripts/clean-upstream-flatpaks.sh` which purges all Fedora Flatpak remotes and empties `/etc/ublue-os/system_flatpaks` and `/usr/share/ublue-os/flatpaks` so no default upstream Bazzite flatpaks are auto-installed, while preserving Bazaar as requested._

- [ ] In recipy.yml add a commented section to add dnf groups that I might add later on. Keep in mind that --setopt=install_weak_deps=False must also be used whenever dnf groups are installed. Furthermore, make sure that the method to use --setopt=install_weak_deps=False in the dnf module is the correct way by search bluebuild project as well as searching the web.
  - _Implemented (Pending User Review & Finalization): Researched BlueBuild `dnf` module v2 schema. Added commented `group-install:` section in `recipes/recipe.yml` with `with-optional: false` and `install-weak-deps: false` (which passes `--setopt=install_weak_deps=False` to DNF5)._

- [ ] I need a separate ujust recipe to perform the following upgrades that topgrage would normally do so that I would no longer need topgrade. This ujust recipe would also maintain and update other things for my system that include but are not limited too:
  1.  doom upgrade that topgrade handles
  2.  update zsh plugins by utilizing the custom zsh-update function from my zsh config
  3.  everything topgrade normally updates as well, unless these commands from topgrade are incompatible with the immutable approach of OCIs. I have a topgrade.toml already available in files/system/etc/topgrade.toml of the bazzite-hyprland project. I use topgrade in my Arch Linux system and it performs the following tasks. For these following tasks (the ones that are applicable only), search the web, think for longer and determine how topgrade approaches these applicable tasks and act accordingly.
  - Self update: not applicable since this is image based and topgrade gets upgraded when image is rebuild.
  - System update: not applicable as well for the same reason the system is image-based
  - Distrobox: applicable since distrobox is baked into the image
  - Firmware upgrades: determine how bazzite and other oci based fedora distributions handle firmware upgrades. It may not be applicable if firmware upgrades are done in the upstream source but I don't know enough to answer whether firmware upgrades can be done like non-immutable distributions.
  - Flatpak User Packages: applicable
  - Flatpak System Packages: not applicable as described above
  - System Manuals: not sure how it is applicable but man-db package is installed in the custom image using dnf
  - User Manuals: not sure how it is applicable but man-db package is installed in the custom image using dnf
  - pkgfile: likely not applicable, you need to confirm
  - Nix (self-upgrade) using the latest version of Determinate Nix: applicable
  - home-manager: applicable
  - hyprpm: applicable
  - Cargo: applicable
  - Doom Emacs: applicable
  - Visual Studio Code extensions: applicable
  - TLDR: applicable
  - Pixi: not sure if applicable since you need to determine if pixi is useful or needed in immutable distros
  - Containers: applicable
  - uv: applicable
  - Bun: applicable
  - Yazi packages: applicable

  The above list for items that topgrade handles comes from the titles topgrade uses for these tasks. You need to determine the internal commands topgrade uses yourself.
  - _Implemented (Pending User Review & Finalization): Extracted internal commands from `topgrade-rs/topgrade` source code for all applicable tools. Implemented `ujust system-upgrade` in `files/system/usr/share/ublue-os/just/60-custom.just` covering Distrobox (`distrobox upgrade --all`), Firmware (`fwupdmgr refresh && fwupdmgr update -y`), Flatpak User (`flatpak update --user -y`), ManDB (`mandb --user-db`), Nix (`nix registry update` & `nix-channel --update`), Home-Manager (`switch-home-manager`), Hyprpm (`hyprpm update && hyprpm reload`), Cargo (`cargo install-update -a`), Doom Emacs (`doom upgrade --force && doom sync --gc`), VSCode (`code --update-extensions`), TLDR (`tldr --update`), Pixi (`pixi global update`), Podman (`podman auto-update`), uv (`uv tool upgrade --all`), Bun (`bun upgrade`), Yazi (`ya pkg upgrade`), and custom ZSH (`zsh-update`). Removed `topgrade` package from `recipe.yml` and deleted `topgrade.toml`._

- [ ] I want to be able to setup my doom emacs configuration after I have logged into my custom image after rebasing into it. The main commands that would normally be used with doom emacs is as follows:

```sh
git clone git@github.com:aahsnr-configs/doom.git ~/.config/doom
echo "(doom! :config literate)" > ~/.config/doom/init.el
git clone --depth 1 https://github.com/doomemacs/core ~/.config/emacs
~/.config/emacs/bin/doom install
~/.config/emacs/bin/doom sync --gc
```

Search the web, think for longer and determine the best approach to achieve this.
  - _Implemented (Pending User Review & Finalization): Added `ujust setup-doom` in `files/system/usr/share/ublue-os/just/60-custom.just`. Automates cloning `git@github.com:aahsnr-configs/doom.git`, creating `~/.config/doom/init.el`, cloning Doom Emacs core to `~/.config/emacs`, running non-interactive installation via `yes | ~/.config/emacs/bin/doom install`, and executing `doom sync --gc`. Ensured `~/.config/emacs/bin` is in `$PATH`._

- [x] **Determine if the current method of manually installing texlive distribution in build_files/build.sh is correct. You can ignore the fact that the texlive-full scheme makes the image extremely large.**
  - _Resolved & Fixed: The previous method installed to `/usr/local/texlive`. In Fedora Atomic / OSTree, `/usr/local` is a symlink to `/var/usrlocal`, which is NOT part of the read-only image and does NOT update across image rebases! The installer script has been updated to install to `/usr/lib/texlive` with `/etc/profile.d/texlive.sh`._

  - [x] **Instead of using texlive-full I decided to use texlive-medium to reduce the size of the final image. However, there will be texlive packages that I would have otherwise installed using tlmgr from time to time. The texlive bash script needs the ability to install individual texlive packages as well.**
    - _Implemented: `install-texlive.sh` is configured with `selected_scheme scheme-medium` and an `EXTRA_TL_PACKAGES=( ... )` array at the top of the script. During build time, after core installation, it automatically calls `tlmgr install "${EXTRA_TL_PACKAGES[@]}"` to bake requested packages (e.g. `latexmk`, `biber`) into `/usr/lib/texlive`. For post-boot installations without rebuilding the image, user-mode is supported via `tlmgr init-usertree && tlmgr --usermode install <pkg>`, which installs packages into `~/texmf`._

- [x] **Also determine if the current method of manually installing zotero from the tarball is correct as well.**
  - _Resolved: The method of installing Zotero into `/usr/lib/zotero` with `/usr/bin/zotero` symlink, desktop entry, and `DisableAppUpdate` policy in `distribution/policies.json` is verified as 100% correct and standard for immutable systems._

- [x] **Make sure correct order is used for everything. Rewrite the README.md to note the order in which all the steps in the github workflow including the order in which the github workflow builds everythings and perform any other tasks, including tasks in the `build.sh` script.**
  - _Implemented: Detailed README.md completely rewritten with the full build and runtime lifecycle sequence._
