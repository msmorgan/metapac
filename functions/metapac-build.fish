function metapac-build --description "Build and install a metapackage"
    argparse -s -N1 -X1 -- $argv
    or return

    set name $argv[1]
    set config_dir (__metapac_config_dir)
    set cache_dir (__metapac_cache_dir)
    set metafile $config_dir/$name.meta

    test -f $metafile
    or begin
        echo "metapac: no meta definition: $name" >&2
        return 1
    end

    set pkgs (__metapac_read_meta $metafile)

    if test (count $pkgs) -eq 0
        echo "metapac: $name.meta has no packages" >&2
        return 1
    end

    set pkgver (date +%Y%m%d.%H%M%S)
    set pkgname metapac-$name
    set builddate (date +%s)

    set builddir (mktemp -d)

    # .PKGINFO
    echo "pkgname = $pkgname
pkgbase = $pkgname
xdata = pkgtype=pkg
pkgver = $pkgver-1
pkgdesc = metapac: $name
builddate = $builddate
packager = metapac
size = 0
arch = any" > $builddir/.PKGINFO

    for pkg in $pkgs
        echo "depend = $pkg" >> $builddir/.PKGINFO
    end

    # .BUILDINFO
    echo "format = 2
pkgname = $pkgname
pkgbase = $pkgname
pkgver = $pkgver-1
pkgarch = any
packager = metapac
builddate = $builddate
buildtool = metapac
buildtoolver = 0.1.0" > $builddir/.BUILDINFO

    set outfile $cache_dir/$pkgname-$pkgver-1-any.pkg.tar.zst

    tar -cf - -C $builddir .PKGINFO .BUILDINFO | zstd -qf -o $outfile
    or begin
        rm -rf $builddir
        echo "metapac: failed to build package" >&2
        return 1
    end

    rm -rf $builddir

    sudo pacman -U --noconfirm $outfile
    or begin
        echo "metapac: pacman -U failed" >&2
        return 1
    end

    echo "metapac: built and installed $pkgname $pkgver"
end
