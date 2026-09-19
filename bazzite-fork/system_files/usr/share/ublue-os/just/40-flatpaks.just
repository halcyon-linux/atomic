# vim: set ft=make :

# Show the Flatpaks configured to be installed by this image
[group("flatpaks")]
flatpaks-show:
    hyprland-flatpak-manager show

# Manually re-run the Flatpak setup (system + user)
[group("flatpaks")]
flatpaks-apply:
    hyprland-flatpak-manager apply all
