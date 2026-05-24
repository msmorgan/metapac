function __metapac_list_metas
    set config_dir (set -q METAPAC_CONFIG_DIR; and echo $METAPAC_CONFIG_DIR; or echo ~/.config/metapac)
    for f in (path filter -f $config_dir/*.meta 2>/dev/null)
        path change-extension '' (path basename $f)
    end
end

function __metapac_list_presets
    __metapac_presets
end

function __metapac_needs_subcmd
    not __fish_seen_subcommand_from new add adopt remove build drop list status preset
end

function __metapac_using_subcmd
    __fish_seen_subcommand_from $argv
end

complete -c metapac -f
complete -c metapac -n __metapac_needs_subcmd -a new -d "Create a new meta definition"
complete -c metapac -n __metapac_needs_subcmd -a add -d "Add packages to a meta"
complete -c metapac -n __metapac_needs_subcmd -a adopt -d "Migrate installed packages into a meta"
complete -c metapac -n __metapac_needs_subcmd -a remove -d "Remove packages from a meta"
complete -c metapac -n __metapac_needs_subcmd -a build -d "Rebuild and install a metapackage"
complete -c metapac -n __metapac_needs_subcmd -a drop -d "Uninstall a meta entirely"
complete -c metapac -n __metapac_needs_subcmd -a list -d "List metas or packages in a meta"
complete -c metapac -n __metapac_needs_subcmd -a status -d "Show install status"
complete -c metapac -n __metapac_needs_subcmd -a preset -d "Manage archinstall presets"
complete -c metapac -n __metapac_needs_subcmd -s h -l help -d "Show help"
complete -c metapac -n __metapac_needs_subcmd -s v -l version -d "Show version"

complete -c metapac -n '__metapac_using_subcmd add' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd adopt' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd remove' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd build' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd drop' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd list' -a '(__metapac_list_metas)' -d Meta

complete -c metapac -n '__metapac_using_subcmd preset; and not __fish_seen_subcommand_from list show create' -a list -d "List presets"
complete -c metapac -n '__metapac_using_subcmd preset; and not __fish_seen_subcommand_from list show create' -a show -d "Show preset packages"
complete -c metapac -n '__metapac_using_subcmd preset; and not __fish_seen_subcommand_from list show create' -a create -d "Create meta from preset"
complete -c metapac -n '__metapac_using_subcmd preset; and __fish_seen_subcommand_from show create' -a '(__metapac_list_presets)' -d Preset
complete -c metapac -n '__metapac_using_subcmd preset; and __fish_seen_subcommand_from show create' -l variant -d "Plasma variant" -xa "recommended extensive minimal"

complete -c metapac -n '__metapac_using_subcmd drop' -l delete -d "Also delete the .meta file"
complete -c metapac -n '__metapac_using_subcmd remove' -l no-orphans -d "Skip orphan removal prompt"

# All subcommands accept -h/--help
for subcmd in new add adopt remove build drop list status preset
    complete -c metapac -n "__metapac_using_subcmd $subcmd" -s h -l help -d "Show help"
end
