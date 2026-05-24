source (status dirname)/setup.fish

@test "config dir exists" -d $METAPAC_CONFIG_DIR
@test "cache dir exists" -d $METAPAC_CACHE_DIR
@test "mock pacman works" (pacman -Si fish >/dev/null; echo $status) = 0

cleanup
