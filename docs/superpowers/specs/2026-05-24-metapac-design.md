# metapac Design Spec

Personal metapackage manager for Arch Linux, implemented as fish shell scripts.

## Problem

Arch Linux has no built-in way to group explicitly installed packages by purpose and manage them as a unit. When trying a new desktop environment like Hyprland, you install 10+ packages individually. If you decide to remove it later, you have to remember every package you added. Metapackages solve this — they're empty packages whose only content is a dependency list — but creating them manually requires PKGBUILD boilerplate, makepkg, and version management.

## Solution

`metapac` is a fish shell CLI that manages personal metapackages. It:
- Stores package lists as plain text files (`~/.config/metapac/<name>.meta`)
- Builds dependency-only `.pkg.tar.zst` packages directly (no makepkg)
- Installs them via `pacman -U`
- Migrates already-installed packages into metas by changing their install reason to "dependency" (`pacman -D --asdeps`)
- Ships with archinstall's 21 desktop presets as built-in templates

## CLI Commands

```
metapac new <name>                  Create a new empty meta definition
metapac add <name> <pkg...>         Add packages to a meta (installs + marks --asdeps)
metapac remove <name> <pkg...>      Remove packages from a meta (rebuilds, offers orphan removal)
metapac adopt <name> <pkg...>       Migrate already-installed packages into a meta
metapac build <name>                Rebuild and reinstall the metapackage
metapac drop <name>                 Uninstall the meta entirely (pacman -Rns metapac-<name>)
metapac list                        List all defined metas
metapac list <name>                 List packages in a specific meta
metapac status                      Show install/stale status of all metas
metapac preset list                 Show available archinstall presets
metapac preset show <name>          Show packages in a preset
metapac preset create <name>        Generate a .meta file from a preset
```

## File Format

`~/.config/metapac/<name>.meta` — plain text, one package per line:

```
# Hyprland desktop environment
hyprland
dunst
kitty
uwsm
dolphin
wofi
xdg-desktop-portal-hyprland
qt5-wayland
qt6-wayland
polkit-kde-agent
grim
slurp
```

- Lines starting with `#` are comments
- Empty lines ignored
- No version constraints (pacman resolves from configured repos)
- File name (minus `.meta`) determines package name: `metapac-<name>`

## Storage Paths

| What | Where |
|---|---|
| Meta definitions | `~/.config/metapac/<name>.meta` |
| Built packages | `~/.cache/metapac/metapac-<name>-<version>-1-any.pkg.tar.zst` |
| Presets (bundled) | Embedded in the tool's fish functions |

## Package Construction

Building `metapac-hyprland`:

1. Read `hyprland.meta`, filter comments and blanks
2. Generate `.PKGINFO`:
   ```
   pkgname = metapac-hyprland
   pkgbase = metapac-hyprland
   pkgver = 20260524.001
   pkgrel = 1
   pkgdesc = metapac: hyprland
   arch = any
   depend = hyprland
   depend = dunst
   depend = kitty
   ...
   ```
3. Generate minimal `.BUILDINFO`
4. Pack with `tar` + `zstd` into `.pkg.tar.zst`
5. Install with `sudo pacman -U`
6. Cache the built package in `~/.cache/metapac/`

### Versioning

Version format: `YYYYMMDD.HHMMSS` (e.g., `20260524.143022`). Derived from the current timestamp at build time. Always unique, no counter state needed. Pacman treats each rebuild as an upgrade.

## Migration & Dependency Management

### `metapac adopt <name> <pkg...>`

The key differentiating feature. Migrates already-installed packages into a metapackage:

1. Validate each package is currently installed (`pacman -Q`)
2. Append to `<name>.meta`
3. Rebuild and install the metapackage
4. Run `sudo pacman -D --asdeps <pkg...>` to change install reason
5. Packages are now owned by the meta — removing the meta orphans them

### `metapac add <name> <pkg...>`

Add packages to a meta. Handles both already-installed and not-yet-installed packages:

1. Validate packages exist in repos (`pacman -Si`) or are already installed (`pacman -Q`)
2. Append to `<name>.meta` (skip duplicates)
3. Rebuild metapackage (version auto-bumps)
4. `sudo pacman -U` installs new version, pulling in any not-yet-installed deps
5. All listed packages marked `--asdeps`

### `metapac remove <name> <pkg...>`

Remove packages from a meta (not from system):

1. Remove from `<name>.meta`
2. Rebuild metapackage
3. Prompt: remove now-orphaned packages? (`pacman -Rns`)

### `metapac drop <name>`

Remove an entire metapackage and its unneeded dependencies:

1. `sudo pacman -Rns metapac-<name>`
2. Optionally delete the `.meta` file (prompt)

## Error Handling

- **Package not in repos:** `metapac add` validates with `pacman -Si` before adding. Fails with clear message.
- **Package already in another meta:** Warn but allow. Pacman handles shared deps — removing one meta doesn't orphan packages still needed by another.
- **Meta file exists, package not installed:** `metapac status` flags as "defined but not installed". `metapac build` reinstalls.
- **Package not installed (for adopt):** Fail with message listing which packages aren't installed.

## Privilege Model

Only three operations need root, invoked via `sudo`:
- `pacman -U` (install built package)
- `pacman -D --asdeps` (change install reason)
- `pacman -Rns` (remove package)

Everything else runs as the current user.

## Bundled Presets

Generated from archinstall v4.3 desktop profiles. Available via `metapac preset`:

| Preset | Type | Packages |
|---|---|---|
| awesome | WindowMgr | awesome, alacritty, xorg-xrandr, xterm, feh, slock, terminus-font, gnu-free-fonts, ttf-liberation, xsel |
| bspwm | WindowMgr | bspwm, sxhkd, dmenu, xdo, rxvt-unicode |
| budgie | DesktopEnv | materia-gtk-theme, budgie, mate-terminal, nemo, papirus-icon-theme |
| cinnamon | DesktopEnv | cinnamon, system-config-printer, gnome-keyring, gnome-terminal, engrampa, gnome-screenshot, gvfs-smb, xed, xdg-user-dirs-gtk |
| cosmic | DesktopEnv | cosmic, xdg-user-dirs |
| cutefish | DesktopEnv | cutefish, noto-fonts |
| deepin | DesktopEnv | deepin, deepin-terminal, deepin-editor |
| enlightenment | WindowMgr | enlightenment, terminology |
| gnome | DesktopEnv | gnome, gnome-tweaks |
| hyprland | DesktopEnv | hyprland, dunst, kitty, uwsm, dolphin, wofi, xdg-desktop-portal-hyprland, qt5-wayland, qt6-wayland, polkit-kde-agent, grim, slurp |
| i3 | WindowMgr | i3-wm, i3lock, i3status, i3blocks, xss-lock, xterm, lightdm-gtk-greeter, lightdm, dmenu |
| labwc | WindowMgr | alacritty, labwc |
| lxqt | DesktopEnv | lxqt, breeze-icons, oxygen-icons, xdg-utils, ttf-freefont, l3afpad, slock |
| mate | DesktopEnv | mate, mate-extra |
| niri | WindowMgr | niri, alacritty, fuzzel, mako, xorg-xwayland, waybar, swaybg, swayidle, swaylock, xdg-desktop-portal-gnome |
| plasma | DesktopEnv | plasma-meta (default; `preset create plasma --variant=extensive` for plasma group, `--variant=minimal` for plasma-desktop) |
| qtile | WindowMgr | qtile, alacritty |
| river | WindowMgr | foot, xdg-desktop-portal-wlr, river |
| sway | WindowMgr | sway, swaybg, swaylock, swayidle, waybar, wmenu, brightnessctl, grim, slurp, pavucontrol, foot, xorg-xwayland |
| xfce4 | DesktopEnv | xfce4, xfce4-goodies, pavucontrol, gvfs, xarchiver |
| xmonad | WindowMgr | xmonad, xmonad-contrib, xmonad-extras, xterm, dmenu |

## Typical Workflows

### Try Hyprland

```fish
metapac preset create hyprland       # Creates archinstall-hyprland.meta
metapac build archinstall-hyprland   # Builds and installs the metapackage
# Use hyprland for a while...
metapac add archinstall-hyprland hyprbar waybar  # Found more useful packages
# Decided it's not for me:
metapac drop archinstall-hyprland    # Removes everything cleanly
```

### Organize existing packages

```fish
metapac new dev-tools
metapac adopt dev-tools git neovim ripgrep fd bat
# Now `pacman -Rns metapac-dev-tools` would remove all of them
```

### Migrate from archinstall defaults

```fish
# Already have hyprland packages installed from archinstall:
metapac preset create hyprland
metapac adopt archinstall-hyprland hyprland dunst kitty uwsm dolphin wofi \
  xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-kde-agent grim slurp
```

## Non-Goals

- AUR package support (use your AUR helper separately)
- Version pinning in meta files
- Remote/shared package repos
- Configuration file management (use stow/chezmoi for dotfiles)
- Replacing pacman for any operation beyond metapackage management
