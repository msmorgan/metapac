source (status dirname)/setup.fish

touch $METAPAC_CONFIG_DIR/tools.meta
set -g pacman_query_db git neovim ripgrep

set -g pacman_calls
@test "adopts installed packages" (
    metapac-adopt tools git neovim >/dev/null
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/tools.meta)
) = "git,neovim"

@test "calls pacman -D --asdeps" (
    set matched (string match -- '*-D --asdeps*' $pacman_calls)
    test (count $matched) -gt 0; echo $status
) = 0

@test "marks only added packages as deps" (
    set -g pacman_calls
    metapac-adopt tools git ripgrep >/dev/null
    set asdeps_call (string match -- '*-D --asdeps*' $pacman_calls)
    string match -q -- '*ripgrep*' "$asdeps_call"; and not string match -q -- '*git*' "$asdeps_call"
    echo $status
) = 0

@test "rejects not-installed packages" (
    metapac-adopt tools notinstalled 2>/dev/null
    echo $status
) != 0

@test "requires at least 2 args" (metapac-adopt tools 2>/dev/null; echo $status) != 0

cleanup
