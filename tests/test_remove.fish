source (status dirname)/setup.fish

echo 'hyprland
dunst
kitty' > $METAPAC_CONFIG_DIR/wm.meta

@test "removes package from meta file" (
    metapac remove --no-orphans wm dunst >/dev/null
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/wm.meta)
) = "hyprland,kitty"

@test "removes multiple packages" (
    echo 'a
b
c
d' > $METAPAC_CONFIG_DIR/multi.meta
    metapac remove --no-orphans multi b d >/dev/null
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/multi.meta)
) = "a,c"

# Test that emptying a meta uninstalls the metapackage
set -g pacman_query_db metapac-empty
echo 'onlypkg' > $METAPAC_CONFIG_DIR/empty.meta

set -g pacman_calls
@test "uninstalls metapackage when meta becomes empty" (
    metapac remove --no-orphans empty onlypkg >/dev/null
    set matched (string match -- '*-R --noconfirm metapac-empty' $pacman_calls)
    test (count $matched) -gt 0; echo $status
) = 0

@test "fails for package not in meta" (metapac remove --no-orphans wm notinmeta 2>/dev/null; echo $status) != 0
@test "requires at least 2 args" (metapac remove 2>/dev/null; echo $status) != 0

cleanup
