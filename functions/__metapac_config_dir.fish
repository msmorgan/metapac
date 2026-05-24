function __metapac_config_dir
    set dir (set -q METAPAC_CONFIG_DIR; and echo $METAPAC_CONFIG_DIR; or echo ~/.config/metapac)
    mkdir -p $dir
    echo $dir
end
