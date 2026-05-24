source (status dirname)/setup.fish

@test "creates meta file" (metapac new testmeta >/dev/null; test -f $METAPAC_CONFIG_DIR/testmeta.meta; echo $status) = 0
@test "meta file is empty" (count (string match -rv '^\s*$' < $METAPAC_CONFIG_DIR/testmeta.meta)) -eq 0
@test "refuses duplicate" (metapac new testmeta 2>/dev/null; echo $status) != 0
@test "requires name" (metapac new 2>/dev/null; echo $status) != 0
@test "rejects names with slashes" (metapac new '../evil' 2>/dev/null; echo $status) != 0
@test "rejects names with spaces" (metapac new 'my packages' 2>/dev/null; echo $status) != 0
@test "rejects uppercase names" (metapac new MyMeta 2>/dev/null; echo $status) != 0
@test "allows valid names" (metapac new my-meta_1.0 >/dev/null; echo $status) = 0

cleanup
