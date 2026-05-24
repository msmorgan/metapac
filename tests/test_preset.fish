source (status dirname)/setup.fish

@test "preset list shows all 21 presets" (test (count (metapac-preset list)) -eq 21; echo $status) = 0
@test "preset list includes hyprland" (metapac-preset list | string match -q 'hyprland'; echo $status) = 0
@test "preset list includes gnome" (metapac-preset list | string match -q 'gnome'; echo $status) = 0

@test "preset show hyprland lists packages" (
    set pkgs (metapac-preset show hyprland)
    contains -- hyprland $pkgs; echo $status
) = 0

@test "preset show hyprland has dunst" (
    metapac-preset show hyprland | string match -q 'dunst'; echo $status
) = 0

@test "preset create makes meta file" (
    metapac-preset create hyprland >/dev/null
    test -f $METAPAC_CONFIG_DIR/archinstall-hyprland.meta; echo $status
) = 0

@test "preset create meta has correct packages" (
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/archinstall-hyprland.meta)
) = "hyprland,dunst,kitty,uwsm,dolphin,wofi,xdg-desktop-portal-hyprland,qt5-wayland,qt6-wayland,polkit-kde-agent,grim,slurp"

@test "preset show unknown fails" (metapac-preset show fakede 2>/dev/null; echo $status) != 0
@test "preset create refuses duplicate" (metapac-preset create hyprland 2>/dev/null; echo $status) != 0

cleanup
