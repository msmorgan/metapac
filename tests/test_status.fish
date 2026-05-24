source (status dirname)/setup.fish

echo 'hyprland' > $METAPAC_CONFIG_DIR/wm.meta
echo 'git' > $METAPAC_CONFIG_DIR/dev.meta
set -g pacman_query_db metapac-wm

@test "shows installed metas" (metapac status | string match -q '*wm*installed*'; echo $status) = 0
@test "shows not-installed metas" (metapac status | string match -q '*dev*not installed*'; echo $status) = 0
@test "lists all metas" (test (count (metapac status)) -ge 2; echo $status) = 0

cleanup
