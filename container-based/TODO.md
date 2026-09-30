# TODO & Implementation Status

`Important`: All the TODO items below must be done during building the image so that no extra steps are needed for these todo items when I login after rebasing fedora silverblue to my custom image. In other words when I rebase my fedora silverblue installation to my custom image, everything should be ready upon login. Everything should be baked into the custom image.

---

- [x] **In build.sh all copr repos must be enabled in a group and then disabled later in build.sh as a group.**

- [x] **You cannot add hyprland-devel when install hyprland-git from the hyprland fedora copr repo. And you must install cliphist, qt6ct from the hyprland copr repo as well.**

- [x] **modularize all the files that could benefit form it. Make use ujust files where necessary. And follow best practices for this kind of project.**

- [x] **For packages installed using dnf, you must include --setopt=install_weak_deps=False**

- [x] **Integrate steps to setup vscode, brave, brave-origin and zen browser from their respective repos.**

- [x] **Determine how the bluefin project distros handle the installation of vscode since they come with vscode by default.**

- [x] **Setup terra repository, install zed and disable it afterwards. Do not install anything else from it.**

- [-] **Integrate determinate nix and home-manager setup.**

- [x] **Obsidian should be installed directly from obsidian website using appimage and then baked into the custom image.**

- [x] **node and npm should only be managed by dnf and fedora repo.**

- [-] **Dotfiles setup should be done before determinate-nix and home-manager setup. The dotfiles will point to a home-manager folder in `~/.config/`.**

- [x] Write a bash script baked into the image that sets up and installs pyprland from github releases from https://github.com/hyprland-community/pyprland . Installation of pyprland must be done the same way as the other packages installed using script. In other words, the installation must be done when the custom image is being built. Also make sure that systemd user service can be setup as shown in https://hyprland-community.github.io/pyprland/Getting-started.html instead of exec-once in hyprland configs. The installation done during image building must be able to update pyprland whenever a newer release is available.

- [x] ujust fix-git-index is no longer needed

- [x] I need a separate ujust recipe to rebase my system to my new custom image whenever it becomes availabe. add

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

- [x] I want to be able to setup my doom emacs configuration after I have logged into my custom image after rebasing into it. The main commands that would normally be used with doom emacs is as follows:

```sh
git clone git@github.com:aahsnr-configs/doom.git ~/.config/doom
echo "(doom! :config literate)" > ~/.config/doom/init.el
git clone --depth 1 https://github.com/doomemacs/core ~/.config/emacs
~/.config/emacs/bin/doom install
~/.config/emacs/bin/doom sync --gc
```

Search the web, think for longer and determine the best approach to achieve this.

- [x] **Determine if the current method of manually installing texlive distribution in build_files/build.sh is correct. You can ignore the fact that the texlive-full scheme makes the image extremely large.**

  - [x] **Instead of using texlive-full I decided to use texlive-medium to reduce the size of the final image. However, there will be texlive packages that I would have otherwise installed using tlmgr from time to time. The texlive bash script needs the ability to install individual texlive packages as well.**

- [x] **Make sure correct order is used for everything.

- [ ] `Important`: Where does bazzite get its tpm-unlock ujust recipe?

- [ ] `Important`: Useful packages from ublue-os/packages copr: ublue-os-just, ublue-os-luks, ublue-os-selinux-workarounds `

- [ ] `Important`: Verify if ublue-recipes or just package provide the common just recipes?
