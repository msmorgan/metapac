source (status dirname)/setup.fish

touch $METAPAC_CONFIG_DIR/wm.meta

@test "adds packages to meta file" (
    metapac-add wm hyprland dunst >/dev/null
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/wm.meta)
) = "hyprland,dunst"

@test "skips duplicates" (
    metapac-add wm hyprland kitty >/dev/null
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/wm.meta)
) = "hyprland,dunst,kitty"

set -g pacman_calls
@test "calls pacman -U" (
    metapac-add wm wofi >/dev/null
    string match -q -- '*-U *' "$pacman_calls"; echo $status
) = 0

@test "calls pacman -D --asdeps" (
    set matched (string match -- '*-D --asdeps*' $pacman_calls)
    test (count $matched) -gt 0; echo $status
) = 0

@test "marks only added packages as deps" (
    set -g pacman_calls
    touch $METAPAC_CONFIG_DIR/deptest.meta
    echo 'existing' >> $METAPAC_CONFIG_DIR/deptest.meta
    metapac-add deptest existing newpkg >/dev/null
    set asdeps_call (string match -- '*-D --asdeps*' $pacman_calls)
    string match -q -- '*newpkg*' "$asdeps_call"; and not string match -q -- '*existing*' "$asdeps_call"
    echo $status
) = 0

@test "rejects unknown packages" (
    set -g pacman_sync_missing fakepkg
    metapac-add wm fakepkg 2>/dev/null
    echo $status
) != 0

@test "nonexistent meta fails" (metapac-add nonexistent pkg 2>/dev/null; echo $status) != 0
@test "requires at least 2 args" (metapac-add wm 2>/dev/null; echo $status) != 0

cleanup
