function metapac-status --description "Show install status of all metas"
    argparse -s -X0 -- $argv
    or return

    set config_dir (__metapac_config_dir)
    set metas (path filter -f $config_dir/*.meta)

    if test (count $metas) -eq 0
        echo "metapac: no metas defined"
        return 0
    end

    for f in $metas
        set name (path change-extension '' (path basename $f))
        set pkgname metapac-$name
        set pkg_count (count (__metapac_read_meta $f))

        if pacman -Q $pkgname &>/dev/null
            set ver (pacman -Q $pkgname | string split ' ')[2]
            echo "$name  $pkg_count pkg(s)  installed ($ver)"
        else
            echo "$name  $pkg_count pkg(s)  not installed"
        end
    end
end
