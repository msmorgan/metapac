function metapac-add --description "Add packages to a meta"
    argparse -s -N2 -- $argv
    or return

    set name $argv[1]
    set pkgs $argv[2..]
    set config_dir (__metapac_config_dir)
    set metafile $config_dir/$name.meta

    test -f $metafile
    or begin
        echo "metapac: no meta definition: $name (run metapac new $name first)" >&2
        return 1
    end

    for pkg in $pkgs
        if not pacman -Si $pkg &>/dev/null; and not pacman -Q $pkg &>/dev/null
            echo "metapac: package not found: $pkg" >&2
            return 1
        end
    end

    set existing (__metapac_read_meta $metafile)
    set added

    # Save backup so we can roll back if build fails
    set backup (mktemp)
    command cp $metafile $backup

    for pkg in $pkgs
        if not contains -- $pkg $existing
            echo $pkg >> $metafile
            set -a added $pkg
        end
    end

    if test (count $added) -eq 0
        rm -f $backup
        echo "metapac: all packages already in $name"
        return 0
    end

    if not metapac-build $name
        command mv $backup $metafile
        return 1
    end
    rm -f $backup

    sudo pacman -D --asdeps $added
    or begin
        echo "metapac: failed to mark packages as deps" >&2
        return 1
    end

    echo "metapac: added "(count $added)" package(s) to $name"
end
