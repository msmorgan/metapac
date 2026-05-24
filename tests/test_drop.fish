source (status dirname)/setup.fish

echo 'hyprland
dunst' > $METAPAC_CONFIG_DIR/wm.meta
set -g pacman_query_db metapac-wm

@test "calls pacman -Rns" (
    metapac-drop --delete wm >/dev/null
    set matched (string match -- '*-Rns metapac-wm' $pacman_calls)
    test (count $matched) -gt 0; echo $status
) = 0

@test "deletes meta file with --delete" (test ! -f $METAPAC_CONFIG_DIR/wm.meta; echo $status) = 0

echo 'pkg' > $METAPAC_CONFIG_DIR/keep.meta
set -g pacman_query_db metapac-keep

@test "keeps meta file without --delete" (
    metapac-drop keep >/dev/null
    test -f $METAPAC_CONFIG_DIR/keep.meta; echo $status
) = 0

@test "fails for nonexistent meta" (metapac-drop nonexistent 2>/dev/null; echo $status) != 0

cleanup
