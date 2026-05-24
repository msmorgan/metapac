pkgname=metapac
pkgver=0.1.0
pkgrel=1
pkgdesc='Personal metapackage manager for Arch Linux'
arch=('any')
url='https://github.com/msmorgan/metapac'
license=('MIT')
depends=('fish' 'pacman' 'zstd')
source=()

package() {
    cd "$startdir"

    install -Dm644 functions/metapac.fish "$pkgdir/usr/share/fish/vendor_functions.d/metapac.fish"
    install -Dm644 functions/__metapac_presets.fish "$pkgdir/usr/share/fish/vendor_functions.d/__metapac_presets.fish"
    install -Dm644 functions/__metapac_read_meta.fish "$pkgdir/usr/share/fish/vendor_functions.d/__metapac_read_meta.fish"
    install -Dm644 functions/__metapac_config_dir.fish "$pkgdir/usr/share/fish/vendor_functions.d/__metapac_config_dir.fish"
    install -Dm644 functions/__metapac_cache_dir.fish "$pkgdir/usr/share/fish/vendor_functions.d/__metapac_cache_dir.fish"
    install -Dm644 completions/metapac.fish "$pkgdir/usr/share/fish/vendor_completions.d/metapac.fish"
    install -Dm755 bin/metapac "$pkgdir/usr/bin/metapac"
}
