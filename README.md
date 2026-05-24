# metapac

Personal metapackage manager for Arch Linux. Group packages by purpose, install and remove them as a unit.

## Install

Copy (or symlink) into your fish function/completion paths:

    cp functions/*.fish ~/.config/fish/functions/
    cp completions/metapac.fish ~/.config/fish/completions/

Or with [Fisher](https://github.com/jorgebucaran/fisher):

    fisher install <this-repo-url>

## Usage

    # Create a new metapackage
    metapac new dev-tools
    metapac add dev-tools git neovim ripgrep fd bat

    # Or start from an archinstall preset
    metapac preset create hyprland
    metapac build archinstall-hyprland

    # Adopt already-installed packages
    metapac adopt dev-tools git neovim

    # See what you have
    metapac list
    metapac status

    # Done with hyprland? Remove everything cleanly
    metapac drop archinstall-hyprland

## How it works

Meta definitions are plain text files at `~/.config/metapac/<name>.meta` — one package name per line. `metapac build` constructs a dependency-only pacman package (`metapac-<name>`) and installs it with `pacman -U`. Adopted packages get marked as dependencies (`pacman -D --asdeps`), so removing the meta with `pacman -Rns` cascades to everything not needed by another package.

## Testing

    paru -S fish-fishtape
    fishtape tests/test_*.fish
