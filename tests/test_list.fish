source (status dirname)/setup.fish

echo 'hyprland
dunst' > $METAPAC_CONFIG_DIR/wm.meta
echo 'git
neovim' > $METAPAC_CONFIG_DIR/dev.meta

@test "lists all metas" (
    set result (metapac-list)
    test (count $result) -eq 2; echo $status
) = 0

@test "lists contain dev" (metapac-list | string match -q 'dev'; echo $status) = 0
@test "lists contain wm" (metapac-list | string match -q 'wm'; echo $status) = 0

@test "lists packages in a specific meta" (
    string join , (metapac-list wm)
) = "hyprland,dunst"

@test "nonexistent meta fails" (metapac-list nonexistent 2>/dev/null; echo $status) != 0

cleanup
