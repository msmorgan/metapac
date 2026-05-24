function __metapac_cache_dir
    set dir (set -q METAPAC_CACHE_DIR; and echo $METAPAC_CACHE_DIR; or echo ~/.cache/metapac)
    mkdir -p $dir
    echo $dir
end
