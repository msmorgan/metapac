function __metapac_read_meta --argument-names metafile
    test -f $metafile
    or begin
        echo "metapac: file not found: $metafile" >&2
        return 1
    end

    string match -rv '^\s*#|^\s*$' < $metafile | string trim
end
