source (status dirname)/setup.fish

echo 'hyprland
dunst
kitty' > $METAPAC_CONFIG_DIR/hyprland.meta

@test "build creates pkg.tar.zst" (metapac build hyprland >/dev/null; path filter -f $METAPAC_CACHE_DIR/metapac-hyprland-*-1-any.pkg.tar.zst | count) -eq 1

# Extract and verify .PKGINFO from the built package
set pkg (path filter -f $METAPAC_CACHE_DIR/metapac-hyprland-*-1-any.pkg.tar.zst)[1]
set pkginfo (tar -xf $pkg .PKGINFO -O 2>/dev/null)

@test "PKGINFO has pkgname" (string match -q 'pkgname = metapac-hyprland' $pkginfo; echo $status) = 0
@test "PKGINFO has arch = any" (string match -q 'arch = any' $pkginfo; echo $status) = 0
@test "PKGINFO has depend hyprland" (string match -q 'depend = hyprland' $pkginfo; echo $status) = 0
@test "PKGINFO has depend dunst" (string match -q 'depend = dunst' $pkginfo; echo $status) = 0
@test "PKGINFO has depend kitty" (string match -q 'depend = kitty' $pkginfo; echo $status) = 0
@test "build calls pacman -U" (string match -q -- '*-U *' "$pacman_calls"; echo $status) = 0
@test "nonexistent meta fails" (metapac build nonexistent 2>/dev/null; echo $status) != 0

cleanup
