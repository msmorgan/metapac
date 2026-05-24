source (status dirname)/setup.fish

set -g pacman_query_db hyprland dunst kitty

@echo "--- full workflow: preset create -> adopt -> add -> remove -> drop ---"

@test "create preset" (metapac preset create hyprland >/dev/null; echo $status) = 0
@test "meta file created" -f $METAPAC_CONFIG_DIR/archinstall-hyprland.meta

@test "adopt installed packages" (
    metapac adopt archinstall-hyprland hyprland dunst kitty >/dev/null
    echo $status
) = 0

@test "add new package" (
    metapac add archinstall-hyprland wofi >/dev/null
    echo $status
) = 0

@test "list shows packages" (test (count (metapac list archinstall-hyprland)) -ge 4; echo $status) = 0

@test "remove package from meta" (
    metapac remove --no-orphans archinstall-hyprland wofi >/dev/null
    echo $status
) = 0

@test "wofi no longer in meta" (
    not contains -- wofi (metapac list archinstall-hyprland)
    echo $status
) = 0

set -g pacman_query_db metapac-archinstall-hyprland

@test "drop meta" (metapac drop --delete archinstall-hyprland >/dev/null; echo $status) = 0
@test "meta file deleted" (test ! -f $METAPAC_CONFIG_DIR/archinstall-hyprland.meta; echo $status) = 0

cleanup
