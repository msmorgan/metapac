set -g testdir (mktemp -d)
set -gx METAPAC_CONFIG_DIR $testdir/config
set -gx METAPAC_CACHE_DIR $testdir/cache
mkdir -p $METAPAC_CONFIG_DIR $METAPAC_CACHE_DIR

set -g pacman_calls
set -g pacman_query_db
set -g pacman_sync_missing

set -p fish_function_path (status dirname)/../functions

function pacman
    set -a pacman_calls "$argv"
    switch $argv[1]
        case -Q --query
            for arg in $argv[2..]
                if string match -q -- '-*' $arg
                    continue
                end
                if contains -- $arg $pacman_query_db
                    echo "$arg 1.0-1"
                else
                    echo "error: package '$arg' was not found" >&2
                    return 1
                end
            end
        case -Si --sync
            for arg in $argv[2..]
                if string match -q -- '-*' $arg
                    continue
                end
                if contains -- $arg $pacman_sync_missing
                    echo "error: package '$arg' was not found" >&2
                    return 1
                end
                echo "Name            : $arg"
                echo "Version         : 1.0-1"
            end
        case -U --upgrade
            return 0
        case -D --database
            return 0
        case -Rns
            return 0
        case '*'
            return 0
    end
end

function sudo
    $argv
end

function cleanup
    rm -rf $testdir
end
