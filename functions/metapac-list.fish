function metapac-list --description "List metas or packages in a meta"
    argparse -s -X1 -- $argv
    or return

    set config_dir (__metapac_config_dir)

    if set -q argv[1]
        set name $argv[1]
        set metafile $config_dir/$name.meta
        test -f $metafile
        or begin
            echo "metapac: no meta definition: $name" >&2
            return 1
        end
        __metapac_read_meta $metafile
    else
        for f in (path filter -f $config_dir/*.meta)
            path change-extension '' (path basename $f)
        end
    end
end
