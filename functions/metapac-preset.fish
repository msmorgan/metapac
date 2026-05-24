function metapac-preset --description "Manage archinstall desktop presets"
    argparse -s -N1 'variant=' -- $argv
    or return

    set subcmd $argv[1]
    set args $argv[2..]

    switch $subcmd
        case list
            __metapac_presets
        case show
            test (count $args) -eq 1
            or begin
                echo "metapac: usage: metapac preset show <name>" >&2
                return 1
            end
            __metapac_presets $args[1] $_flag_variant
        case create
            test (count $args) -eq 1
            or begin
                echo "metapac: usage: metapac preset create <name>" >&2
                return 1
            end
            set name $args[1]
            set config_dir (__metapac_config_dir)
            set metafile $config_dir/archinstall-$name.meta

            if test -f $metafile
                echo "metapac: archinstall-$name already exists" >&2
                return 1
            end

            set pkgs (__metapac_presets $name $_flag_variant)
            or return

            printf '# archinstall %s preset\n' $name > $metafile
            for pkg in $pkgs
                echo $pkg >> $metafile
            end
            echo "metapac: created $metafile"
        case '*'
            echo "metapac: unknown preset command: $subcmd (use list, show, or create)" >&2
            return 1
    end
end
