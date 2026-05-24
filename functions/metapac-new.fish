function metapac-new --description "Create a new meta definition"
    argparse -s -N1 -X1 -- $argv
    or return

    set name $argv[1]

    if not string match -rq '^[a-z0-9@._+-]+$' $name
        echo "metapac: invalid name '$name' (use lowercase letters, digits, @._+-)" >&2
        return 1
    end

    set config_dir (__metapac_config_dir)
    set metafile $config_dir/$name.meta

    if test -f $metafile
        echo "metapac: $name already exists" >&2
        return 1
    end

    touch $metafile
    echo "metapac: created $metafile"
end
