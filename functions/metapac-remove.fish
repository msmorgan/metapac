function metapac-remove --description "Remove packages from a meta"
    argparse -s -N2 'no-orphans' -- $argv
    or return

    set name $argv[1]
    set pkgs $argv[2..]
    set config_dir (__metapac_config_dir)
    set metafile $config_dir/$name.meta

    test -f $metafile
    or begin
        echo "metapac: no meta definition: $name" >&2
        return 1
    end

    set existing (__metapac_read_meta $metafile)

    for pkg in $pkgs
        if not contains -- $pkg $existing
            echo "metapac: $pkg is not in $name" >&2
            return 1
        end
    end

    set tmpfile (mktemp)
    while read -l line
        set trimmed (string trim $line)
        if string match -q -- '#*' $trimmed; or test -z $trimmed
            echo $line >> $tmpfile
        else if not contains -- $trimmed $pkgs
            echo $line >> $tmpfile
        end
    end < $metafile
    command mv $tmpfile $metafile

    if test (count (__metapac_read_meta $metafile)) -gt 0
        metapac-build $name
        or return
    else
        set pkgname metapac-$name
        if pacman -Q $pkgname &>/dev/null
            sudo pacman -R --noconfirm $pkgname
        end
        echo "metapac: $name is now empty"
    end

    if not set -q _flag_no_orphans
        echo "Remove orphaned packages? [y/N]"
        read -l confirm
        if test "$confirm" = y
            sudo pacman -Rns $pkgs
        end
    end

    echo "metapac: removed "(count $pkgs)" package(s) from $name"
end
