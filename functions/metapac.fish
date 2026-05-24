function metapac --description "Personal metapackage manager for Arch Linux"
    argparse -s h/help v/version -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac <command> [args...]"
        echo
        echo "Commands:"
        echo "  new <name>              Create a new meta definition"
        echo "  add <name> <pkg...>     Add packages to a meta"
        echo "  adopt <name> <pkg...>   Migrate installed packages into a meta"
        echo "  remove <name> <pkg...>  Remove packages from a meta"
        echo "  build <name>            Rebuild and install a metapackage"
        echo "  drop <name>             Uninstall a meta entirely"
        echo "  list [name]             List metas or packages in a meta"
        echo "  status                  Show install status of all metas"
        echo "  preset <subcmd>         Manage archinstall presets"
        return 0
    end

    if set -q _flag_version
        echo "metapac 0.1.0"
        return 0
    end

    if not set -q argv[1]
        echo "metapac: missing command (run 'metapac --help' for usage)" >&2
        return 1
    end

    set subcmd $argv[1]
    set args $argv[2..]

    switch $subcmd
        case new
            __metapac_new $args
        case add
            __metapac_add $args
        case adopt
            __metapac_adopt $args
        case remove
            __metapac_remove $args
        case build
            __metapac_build $args
        case drop
            __metapac_drop $args
        case list
            __metapac_list $args
        case status
            __metapac_status $args
        case preset
            __metapac_preset $args
        case '*'
            echo "metapac: unknown command: $subcmd" >&2
            echo "Run \'metapac --help\' for usage." >&2
            return 1
    end
end

function __metapac_build --description "Build and install a metapackage"
    argparse -s h/help -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac build <name>"
        echo "Build and install a metapackage from its .meta definition"
        return 0
    end

    if test (count $argv) -lt 1
        echo "metapac build: not enough arguments" >&2
        return 1
    end
    if test (count $argv) -gt 1
        echo "metapac build: too many arguments" >&2
        return 1
    end

    set name $argv[1]
    set config_dir (__metapac_config_dir)
    set cache_dir (__metapac_cache_dir)
    set metafile $config_dir/$name.meta

    test -f $metafile
    or begin
        echo "metapac: no meta definition: $name" >&2
        return 1
    end

    set pkgs (__metapac_read_meta $metafile)

    if test (count $pkgs) -eq 0
        echo "metapac: $name.meta has no packages" >&2
        return 1
    end

    set pkgver (date +%Y%m%d.%H%M%S)
    set pkgname metapac-$name
    set builddate (date +%s)

    set builddir (mktemp -d)

    # .PKGINFO
    echo "pkgname = $pkgname
pkgbase = $pkgname
xdata = pkgtype=pkg
pkgver = $pkgver-1
pkgdesc = metapac: $name
builddate = $builddate
packager = metapac
size = 0
arch = any" > $builddir/.PKGINFO

    for pkg in $pkgs
        echo "depend = $pkg" >> $builddir/.PKGINFO
    end

    # .BUILDINFO
    echo "format = 2
pkgname = $pkgname
pkgbase = $pkgname
pkgver = $pkgver-1
pkgarch = any
packager = metapac
builddate = $builddate
buildtool = metapac
buildtoolver = 0.1.0" > $builddir/.BUILDINFO

    set outfile $cache_dir/$pkgname-$pkgver-1-any.pkg.tar.zst

    tar -cf - -C $builddir .PKGINFO .BUILDINFO | zstd -qf -o $outfile
    or begin
        rm -rf $builddir
        echo "metapac: failed to build package" >&2
        return 1
    end

    rm -rf $builddir

    sudo pacman -U --noconfirm $outfile
    or begin
        echo "metapac: pacman -U failed" >&2
        return 1
    end

    echo "metapac: built and installed $pkgname $pkgver"
end

function __metapac_new --description "Create a new meta definition"
    argparse -s h/help -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac new <name>"
        echo "Create a new empty meta definition"
        return 0
    end

    if test (count $argv) -lt 1
        echo "metapac new: not enough arguments" >&2
        return 1
    end
    if test (count $argv) -gt 1
        echo "metapac new: too many arguments" >&2
        return 1
    end

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

function __metapac_add --description "Add packages to a meta"
    argparse -s h/help -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac add <name> <pkg...>"
        echo "Add packages to a meta and mark them as dependencies"
        return 0
    end

    if test (count $argv) -lt 2
        echo "metapac add: not enough arguments" >&2
        return 1
    end

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

    if not __metapac_build $name
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

function __metapac_adopt --description "Migrate installed packages into a meta"
    argparse -s h/help -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac adopt <name> <pkg...>"
        echo "Migrate already-installed packages into a meta (marks as dependencies)"
        return 0
    end

    if test (count $argv) -lt 2
        echo "metapac adopt: not enough arguments" >&2
        return 1
    end

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

    if not __metapac_build $name
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

function __metapac_remove --description "Remove packages from a meta"
    argparse -s h/help 'no-orphans' -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac remove [--no-orphans] <name> <pkg...>"
        echo "Remove packages from a meta (prompts to uninstall orphans)"
        return 0
    end

    if test (count $argv) -lt 2
        echo "metapac remove: not enough arguments" >&2
        return 1
    end

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
        __metapac_build $name
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

function __metapac_drop --description "Uninstall a metapackage entirely"
    argparse -s h/help 'delete' -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac drop [--delete] <name>"
        echo "Uninstall a metapackage and its unneeded dependencies"
        return 0
    end

    if test (count $argv) -lt 1
        echo "metapac drop: not enough arguments" >&2
        return 1
    end
    if test (count $argv) -gt 1
        echo "metapac drop: too many arguments" >&2
        return 1
    end

    set name $argv[1]
    set config_dir (__metapac_config_dir)
    set metafile $config_dir/$name.meta
    set pkgname metapac-$name

    if not pacman -Q $pkgname &>/dev/null
        echo "metapac: $pkgname is not installed" >&2
        return 1
    end

    sudo pacman -Rns $pkgname
    or begin
        echo "metapac: failed to remove $pkgname" >&2
        return 1
    end

    if set -q _flag_delete
        rm -f $metafile
        echo "metapac: removed $pkgname and deleted $name.meta"
    else
        echo "metapac: removed $pkgname (meta file kept: $metafile)"
    end
end

function __metapac_list --description "List metas or packages in a meta"
    argparse -s h/help -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac list [name]"
        echo "List all metas, or packages in a specific meta"
        return 0
    end

    if test (count $argv) -gt 1
        echo "metapac list: too many arguments" >&2
        return 1
    end

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

function __metapac_status --description "Show install status of all metas"
    argparse -s h/help -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac status"
        echo "Show install status of all metas"
        return 0
    end

    if test (count $argv) -gt 0
        echo "metapac status: too many arguments" >&2
        return 1
    end

    set config_dir (__metapac_config_dir)
    set metas (path filter -f $config_dir/*.meta)

    if test (count $metas) -eq 0
        echo "metapac: no metas defined"
        return 0
    end

    for f in $metas
        set name (path change-extension '' (path basename $f))
        set pkgname metapac-$name
        set pkg_count (count (__metapac_read_meta $f))

        if pacman -Q $pkgname &>/dev/null
            set ver (pacman -Q $pkgname | string split ' ')[2]
            echo "$name  $pkg_count pkg(s)  installed ($ver)"
        else
            echo "$name  $pkg_count pkg(s)  not installed"
        end
    end
end

function __metapac_preset --description "Manage archinstall desktop presets"
    argparse -s h/help 'variant=' -- $argv
    or return

    if set -q _flag_help
        echo "Usage: metapac preset {list|show|create} [name]"
        echo "Manage archinstall desktop presets"
        return 0
    end

    if test (count $argv) -lt 1
        echo "metapac preset: not enough arguments" >&2
        return 1
    end

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
