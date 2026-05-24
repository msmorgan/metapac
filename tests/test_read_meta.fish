source (status dirname)/setup.fish

echo '# comment
hyprland
dunst

# another comment
kitty
' > $METAPAC_CONFIG_DIR/test.meta

echo '' > $METAPAC_CONFIG_DIR/empty.meta

echo '  spaced
	tabbed
trailing   ' > $METAPAC_CONFIG_DIR/whitespace.meta

@test "reads package names" (string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/test.meta)) = "hyprland,dunst,kitty"
@test "skips comments" (count (__metapac_read_meta $METAPAC_CONFIG_DIR/test.meta)) -eq 3
@test "empty meta returns nothing" (count (__metapac_read_meta $METAPAC_CONFIG_DIR/empty.meta)) -eq 0
@test "trims whitespace" (string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/whitespace.meta)) = "spaced,tabbed,trailing"
@test "nonexistent file fails" (begin; __metapac_read_meta /nonexistent 2>/dev/null; end; echo $status) = 1

cleanup
