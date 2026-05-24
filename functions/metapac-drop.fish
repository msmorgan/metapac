function metapac-drop --description "Uninstall a metapackage entirely"
    argparse -s -N1 -X1 'delete' -- $argv
    or return

    set name $argv[1]
    set config_dir (__metapac_config_dir)
    set metafile $config_dir/$name.meta
    set pkgname metapac-$name

    if not pacman -Q $pkgname &>/dev/null
        echo "metapac: $pkgname is not installed" >&2
        return 1
    end

    sudo pacman -Rns $pkgname
    or begin
        echo "metapac: failed to remove $pkgname" >&2
        return 1
    end

    if set -q _flag_delete
        rm -f $metafile
        echo "metapac: removed $pkgname and deleted $name.meta"
    else
        echo "metapac: removed $pkgname (meta file kept: $metafile)"
    end
end
