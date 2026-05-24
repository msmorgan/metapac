function metapac-adopt --description "Migrate installed packages into a meta"
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

    set not_installed
    for pkg in $pkgs
        if not pacman -Q $pkg &>/dev/null
            set -a not_installed $pkg
        end
    end

    if test (count $not_installed) -gt 0
        echo "metapac: not installed: $not_installed" >&2
        return 1
    end

    set existing (__metapac_read_meta $metafile)
    set added

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

    echo "metapac: adopted "(count $added)" package(s) into $name"
end
