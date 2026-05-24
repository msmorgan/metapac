# metapac Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `metapac`, a fish shell CLI for managing personal Arch Linux metapackages — plain-text package lists that become real pacman packages you can install and remove as a group.

**Architecture:** A main `metapac` function dispatches to subcommand functions (`metapac-new`, `metapac-build`, etc.). A shared helper `__metapac_read_meta` parses `.meta` files. Package construction builds `.PKGINFO` + `.BUILDINFO`, packs with `tar`+`zstd`, installs with `pacman -U`. Preset data lives in a single `__metapac_presets` function. Tests use fishtape with a mock `pacman` to avoid needing root.

**Tech Stack:** Fish shell, pacman, tar, zstd, fishtape (AUR: `fish-fishtape`)

---

## File Structure

```
functions/
  metapac.fish              # Main entry point — argparse, dispatch to subcommands
  metapac-new.fish          # `metapac new <name>`
  metapac-build.fish        # `metapac build <name>` — core package construction
  metapac-add.fish          # `metapac add <name> <pkg...>`
  metapac-adopt.fish        # `metapac adopt <name> <pkg...>`
  metapac-remove.fish       # `metapac remove <name> <pkg...>`
  metapac-drop.fish         # `metapac drop <name>`
  metapac-list.fish         # `metapac list [name]`
  metapac-status.fish       # `metapac status`
  metapac-preset.fish       # `metapac preset {list|show|create}`
  __metapac_read_meta.fish  # Parse a .meta file → list of package names
  __metapac_presets.fish     # Preset data (21 archinstall desktop profiles)
  __metapac_config_dir.fish # Returns ~/.config/metapac (creating if needed)
  __metapac_cache_dir.fish  # Returns ~/.cache/metapac (creating if needed)
tests/
  setup.fish                # Test helpers: mock pacman, temp dirs
  test_read_meta.fish       # Tests for .meta file parsing
  test_build.fish           # Tests for package construction
  test_new.fish             # Tests for metapac new
  test_add.fish             # Tests for metapac add
  test_adopt.fish           # Tests for metapac adopt
  test_remove.fish          # Tests for metapac remove
  test_drop.fish            # Tests for metapac drop
  test_list.fish            # Tests for metapac list
  test_status.fish          # Tests for metapac status
  test_preset.fish          # Tests for metapac preset
```

---

### Task 1: Project Scaffolding & Test Infrastructure

**Files:**
- Create: `tests/setup.fish`
- Create: `functions/__metapac_config_dir.fish`
- Create: `functions/__metapac_cache_dir.fish`

This task sets up the project layout, installs fishtape, and creates the test harness with a mock `pacman` so tests never touch the real system.

- [ ] **Step 1: Install fishtape**

Run:
```bash
paru -S --noconfirm fish-fishtape
```
Expected: fishtape is installed and available as a fish function.

- [ ] **Step 2: Create directory structure**

Run:
```bash
mkdir -p functions tests
```

- [ ] **Step 3: Write `__metapac_config_dir.fish`**

```fish
# functions/__metapac_config_dir.fish
function __metapac_config_dir
    set dir (set -q METAPAC_CONFIG_DIR; and echo $METAPAC_CONFIG_DIR; or echo ~/.config/metapac)
    mkdir -p $dir
    echo $dir
end
```

- [ ] **Step 4: Write `__metapac_cache_dir.fish`**

```fish
# functions/__metapac_cache_dir.fish
function __metapac_cache_dir
    set dir (set -q METAPAC_CACHE_DIR; and echo $METAPAC_CACHE_DIR; or echo ~/.cache/metapac)
    mkdir -p $dir
    echo $dir
end
```

The `METAPAC_CONFIG_DIR` and `METAPAC_CACHE_DIR` env vars let tests redirect to temp dirs.

- [ ] **Step 5: Write `tests/setup.fish`**

This file is `source`d at the top of every test file. It creates temp dirs, sets env vars, adds `functions/` to the function path, and defines a mock `pacman` that records calls.

```fish
# tests/setup.fish
set -g testdir (mktemp -d)
set -gx METAPAC_CONFIG_DIR $testdir/config
set -gx METAPAC_CACHE_DIR $testdir/cache
mkdir -p $METAPAC_CONFIG_DIR $METAPAC_CACHE_DIR

set -g pacman_calls
set -g pacman_query_db

# Add project functions to the function path
set -p fish_function_path (status dirname)/../functions

function pacman
    set -a pacman_calls "$argv"
    switch $argv[1]
        case -Q --query
            # Simulate installed packages from pacman_query_db
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
            # Pretend all packages exist in repos
            for arg in $argv[2..]
                if string match -q -- '-*' $arg
                    continue
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
```

- [ ] **Step 6: Verify test harness works**

Create a trivial test to confirm fishtape + setup work:

```fish
# tests/test_smoke.fish
source (status dirname)/setup.fish

@test "config dir exists" -d $METAPAC_CONFIG_DIR
@test "cache dir exists" -d $METAPAC_CACHE_DIR
@test "mock pacman works" (pacman -Si fish; echo $status) = 0

cleanup
```

Run: `fishtape tests/test_smoke.fish`
Expected: TAP output, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add functions/__metapac_config_dir.fish functions/__metapac_cache_dir.fish tests/setup.fish tests/test_smoke.fish
git commit -m "scaffold: project structure, test harness with mock pacman"
```

---

### Task 2: Meta File Parser (`__metapac_read_meta`)

**Files:**
- Create: `tests/test_read_meta.fish`
- Create: `functions/__metapac_read_meta.fish`

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_read_meta.fish
source (status dirname)/setup.fish

# Create test meta files
echo '# comment
hyprland
dunst

# another comment
kitty
' > $METAPAC_CONFIG_DIR/test.meta

echo '' > $METAPAC_CONFIG_DIR/empty.meta

echo '  spaced  
	tabbed
trailing   ' > $METAPAC_CONFIG_DIR/whitespace.meta

@test "reads package names" (string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/test.meta)) = "hyprland,dunst,kitty"
@test "skips comments" (count (__metapac_read_meta $METAPAC_CONFIG_DIR/test.meta)) -eq 3
@test "empty meta returns nothing" (count (__metapac_read_meta $METAPAC_CONFIG_DIR/empty.meta)) -eq 0
@test "trims whitespace" (string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/whitespace.meta)) = "spaced,tabbed,trailing"
@test "nonexistent file fails" (begin; __metapac_read_meta /nonexistent 2>/dev/null; end; echo $status) = 1

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_read_meta.fish`
Expected: FAIL — `__metapac_read_meta` not defined.

- [ ] **Step 3: Write the implementation**

```fish
# functions/__metapac_read_meta.fish
function __metapac_read_meta --argument-names metafile
    test -f $metafile
    or begin
        echo "metapac: file not found: $metafile" >&2
        return 1
    end

    string match -rv '^\s*#|^\s*$' < $metafile | string trim
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fishtape tests/test_read_meta.fish`
Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add functions/__metapac_read_meta.fish tests/test_read_meta.fish
git commit -m "feat: add meta file parser"
```

---

### Task 3: Package Builder (`metapac-build`)

**Files:**
- Create: `tests/test_build.fish`
- Create: `functions/metapac-build.fish`

This is the core — building a `.pkg.tar.zst` from a `.meta` file.

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_build.fish
source (status dirname)/setup.fish

echo 'hyprland
dunst
kitty' > $METAPAC_CONFIG_DIR/hyprland.meta

@test "build creates pkg.tar.zst" (metapac-build hyprland; path filter -f $METAPAC_CACHE_DIR/metapac-hyprland-*-1-any.pkg.tar.zst | count) -eq 1

# Extract and verify .PKGINFO from the built package
set pkg (path filter -f $METAPAC_CACHE_DIR/metapac-hyprland-*-1-any.pkg.tar.zst)[1]
set pkginfo (tar -xf $pkg .PKGINFO -O 2>/dev/null)

@test "PKGINFO has pkgname" (string match -q 'pkgname = metapac-hyprland' $pkginfo; echo $status) = 0
@test "PKGINFO has arch = any" (string match -q 'arch = any' $pkginfo; echo $status) = 0
@test "PKGINFO has depend hyprland" (string match -q 'depend = hyprland' $pkginfo; echo $status) = 0
@test "PKGINFO has depend dunst" (string match -q 'depend = dunst' $pkginfo; echo $status) = 0
@test "PKGINFO has depend kitty" (string match -q 'depend = kitty' $pkginfo; echo $status) = 0
@test "build calls pacman -U" (string match -q '*-U *' "$pacman_calls"; echo $status) = 0
@test "nonexistent meta fails" (metapac-build nonexistent 2>/dev/null; echo $status) != 0

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_build.fish`
Expected: FAIL — `metapac-build` not defined.

- [ ] **Step 3: Write the implementation**

```fish
# functions/metapac-build.fish
function metapac-build --description "Build and install a metapackage"
    argparse -s -N1 -X1 -- $argv
    or return

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
    or return

    if test (count $pkgs) -eq 0
        echo "metapac: $name.meta has no packages" >&2
        return 1
    end

    set version (date +%Y%m%d.%H%M%S)
    set pkgname metapac-$name
    set builddate (date +%s)

    set builddir (mktemp -d)

    # .PKGINFO
    echo "pkgname = $pkgname
pkgbase = $pkgname
xdata = pkgtype=pkg
pkgver = $version-1
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
pkgver = $version-1
pkgarch = any
packager = metapac
builddate = $builddate
buildtool = metapac
buildtoolver = 0.1.0" > $builddir/.BUILDINFO

    set outfile $cache_dir/$pkgname-$version-1-any.pkg.tar.zst

    tar -cf - -C $builddir .PKGINFO .BUILDINFO | zstd -q -o $outfile
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

    echo "metapac: built and installed $pkgname $version"
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fishtape tests/test_build.fish`
Expected: All 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add functions/metapac-build.fish tests/test_build.fish
git commit -m "feat: add package builder (metapac build)"
```

---

### Task 4: New Meta (`metapac-new`)

**Files:**
- Create: `tests/test_new.fish`
- Create: `functions/metapac-new.fish`

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_new.fish
source (status dirname)/setup.fish

@test "creates meta file" (metapac-new testmeta; test -f $METAPAC_CONFIG_DIR/testmeta.meta; echo $status) = 0
@test "meta file is empty" (count (string match -rv '^\s*$' < $METAPAC_CONFIG_DIR/testmeta.meta)) -eq 0
@test "refuses duplicate" (metapac-new testmeta 2>/dev/null; echo $status) != 0
@test "requires name" (metapac-new 2>/dev/null; echo $status) != 0

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_new.fish`
Expected: FAIL.

- [ ] **Step 3: Write the implementation**

```fish
# functions/metapac-new.fish
function metapac-new --description "Create a new meta definition"
    argparse -s -N1 -X1 -- $argv
    or return

    set name $argv[1]
    set config_dir (__metapac_config_dir)
    set metafile $config_dir/$name.meta

    if test -f $metafile
        echo "metapac: $name already exists" >&2
        return 1
    end

    touch $metafile
    echo "metapac: created $metafile"
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fishtape tests/test_new.fish`
Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add functions/metapac-new.fish tests/test_new.fish
git commit -m "feat: add metapac new"
```

---

### Task 5: Add Packages (`metapac-add`)

**Files:**
- Create: `tests/test_add.fish`
- Create: `functions/metapac-add.fish`

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_add.fish
source (status dirname)/setup.fish

touch $METAPAC_CONFIG_DIR/wm.meta

@test "adds packages to meta file" (
    metapac-add wm hyprland dunst
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/wm.meta)
) = "hyprland,dunst"

@test "skips duplicates" (
    metapac-add wm hyprland kitty
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/wm.meta)
) = "hyprland,dunst,kitty"

@test "calls pacman -U" (string match -q '*-U *' "$pacman_calls"; echo $status) = 0

@test "calls pacman -D --asdeps" (
    set matched (string match '*-D --asdeps*' $pacman_calls)
    test (count $matched) -gt 0; echo $status
) = 0

@test "nonexistent meta fails" (metapac-add nonexistent pkg 2>/dev/null; echo $status) != 0
@test "requires at least 2 args" (metapac-add wm 2>/dev/null; echo $status) != 0

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_add.fish`
Expected: FAIL.

- [ ] **Step 3: Write the implementation**

```fish
# functions/metapac-add.fish
function metapac-add --description "Add packages to a meta"
    argparse -s -N2 -- $argv
    or return

    set name $argv[1]
    set pkgs $argv[2..]
    set config_dir (__metapac_config_dir)
    set metafile $config_dir/$name.meta

    test -f $metafile
    or begin
        echo "metapac: no meta definition: $name (run metapac new $name first)" >&2
        return 1
    end

    # Validate packages exist in repos or are already installed
    for pkg in $pkgs
        if not pacman -Si $pkg &>/dev/null; and not pacman -Q $pkg &>/dev/null
            echo "metapac: package not found: $pkg" >&2
            return 1
        end
    end

    set existing (__metapac_read_meta $metafile)
    set added

    for pkg in $pkgs
        if not contains -- $pkg $existing
            echo $pkg >> $metafile
            set -a added $pkg
        end
    end

    if test (count $added) -eq 0
        echo "metapac: all packages already in $name"
        return 0
    end

    metapac-build $name
    or return

    sudo pacman -D --asdeps $pkgs
    or begin
        echo "metapac: failed to mark packages as deps" >&2
        return 1
    end

    echo "metapac: added "(count $added)" package(s) to $name"
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fishtape tests/test_add.fish`
Expected: All 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add functions/metapac-add.fish tests/test_add.fish
git commit -m "feat: add metapac add"
```

---

### Task 6: Adopt Packages (`metapac-adopt`)

**Files:**
- Create: `tests/test_adopt.fish`
- Create: `functions/metapac-adopt.fish`

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_adopt.fish
source (status dirname)/setup.fish

touch $METAPAC_CONFIG_DIR/tools.meta
set -g pacman_query_db git neovim ripgrep

@test "adopts installed packages" (
    metapac-adopt tools git neovim
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/tools.meta)
) = "git,neovim"

@test "calls pacman -D --asdeps" (
    set matched (string match '*-D --asdeps*' $pacman_calls)
    test (count $matched) -gt 0; echo $status
) = 0

@test "rejects not-installed packages" (
    metapac-adopt tools notinstalled 2>/dev/null
    echo $status
) != 0

@test "requires at least 2 args" (metapac-adopt tools 2>/dev/null; echo $status) != 0

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_adopt.fish`
Expected: FAIL.

- [ ] **Step 3: Write the implementation**

```fish
# functions/metapac-adopt.fish
function metapac-adopt --description "Migrate installed packages into a meta"
    argparse -s -N2 -- $argv
    or return

    set name $argv[1]
    set pkgs $argv[2..]
    set config_dir (__metapac_config_dir)
    set metafile $config_dir/$name.meta

    test -f $metafile
    or begin
        echo "metapac: no meta definition: $name (run metapac new $name first)" >&2
        return 1
    end

    # Validate all packages are currently installed
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

    for pkg in $pkgs
        if not contains -- $pkg $existing
            echo $pkg >> $metafile
            set -a added $pkg
        end
    end

    if test (count $added) -eq 0
        echo "metapac: all packages already in $name"
        return 0
    end

    metapac-build $name
    or return

    sudo pacman -D --asdeps $pkgs
    or begin
        echo "metapac: failed to mark packages as deps" >&2
        return 1
    end

    echo "metapac: adopted "(count $added)" package(s) into $name"
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fishtape tests/test_adopt.fish`
Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add functions/metapac-adopt.fish tests/test_adopt.fish
git commit -m "feat: add metapac adopt"
```

---

### Task 7: Remove Packages from Meta (`metapac-remove`)

**Files:**
- Create: `tests/test_remove.fish`
- Create: `functions/metapac-remove.fish`

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_remove.fish
source (status dirname)/setup.fish

echo 'hyprland
dunst
kitty' > $METAPAC_CONFIG_DIR/wm.meta

@test "removes package from meta file" (
    metapac-remove --no-orphans wm dunst
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/wm.meta)
) = "hyprland,kitty"

@test "removes multiple packages" (
    echo 'a
b
c
d' > $METAPAC_CONFIG_DIR/multi.meta
    metapac-remove --no-orphans multi b d
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/multi.meta)
) = "a,c"

@test "fails for package not in meta" (metapac-remove --no-orphans wm notinmeta 2>/dev/null; echo $status) != 0
@test "requires at least 2 args" (metapac-remove 2>/dev/null; echo $status) != 0

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_remove.fish`
Expected: FAIL.

- [ ] **Step 3: Write the implementation**

```fish
# functions/metapac-remove.fish
function metapac-remove --description "Remove packages from a meta"
    argparse -s -N2 'no-orphans' -- $argv
    or return

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

    # Validate all packages are in the meta
    for pkg in $pkgs
        if not contains -- $pkg $existing
            echo "metapac: $pkg is not in $name" >&2
            return 1
        end
    end

    # Rewrite the meta file excluding the removed packages,
    # preserving comments and blank lines
    set tmpfile (mktemp)
    while read -l line
        set trimmed (string trim $line)
        if string match -q '#*' $trimmed; or test -z $trimmed
            echo $line >> $tmpfile
        else if not contains -- $trimmed $pkgs
            echo $line >> $tmpfile
        end
    end < $metafile
    command mv $tmpfile $metafile

    if test (count (__metapac_read_meta $metafile)) -gt 0
        metapac-build $name
        or return
    else
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fishtape tests/test_remove.fish`
Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add functions/metapac-remove.fish tests/test_remove.fish
git commit -m "feat: add metapac remove"
```

---

### Task 8: Drop Meta (`metapac-drop`)

**Files:**
- Create: `tests/test_drop.fish`
- Create: `functions/metapac-drop.fish`

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_drop.fish
source (status dirname)/setup.fish

echo 'hyprland
dunst' > $METAPAC_CONFIG_DIR/wm.meta
set -g pacman_query_db metapac-wm

@test "calls pacman -Rns" (
    metapac-drop --delete wm
    set matched (string match '*-Rns metapac-wm' $pacman_calls)
    test (count $matched) -gt 0; echo $status
) = 0

@test "deletes meta file with --delete" (test ! -f $METAPAC_CONFIG_DIR/wm.meta; echo $status) = 0

# Test keeping meta file (default)
echo 'pkg' > $METAPAC_CONFIG_DIR/keep.meta
set -g pacman_query_db metapac-keep

@test "keeps meta file without --delete" (
    metapac-drop keep
    test -f $METAPAC_CONFIG_DIR/keep.meta; echo $status
) = 0

@test "fails for nonexistent meta" (metapac-drop nonexistent 2>/dev/null; echo $status) != 0

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_drop.fish`
Expected: FAIL.

- [ ] **Step 3: Write the implementation**

```fish
# functions/metapac-drop.fish
function metapac-drop --description "Uninstall a metapackage entirely"
    argparse -s -N1 -X1 'delete' -- $argv
    or return

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fishtape tests/test_drop.fish`
Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add functions/metapac-drop.fish tests/test_drop.fish
git commit -m "feat: add metapac drop"
```

---

### Task 9: List Metas (`metapac-list`)

**Files:**
- Create: `tests/test_list.fish`
- Create: `functions/metapac-list.fish`

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_list.fish
source (status dirname)/setup.fish

echo 'hyprland
dunst' > $METAPAC_CONFIG_DIR/wm.meta
echo 'git
neovim' > $METAPAC_CONFIG_DIR/dev.meta

@test "lists all metas" (
    set result (metapac-list)
    test (count $result) -eq 2; echo $status
) = 0

@test "lists contain dev" (metapac-list | string match -q 'dev'; echo $status) = 0
@test "lists contain wm" (metapac-list | string match -q 'wm'; echo $status) = 0

@test "lists packages in a specific meta" (
    string join , (metapac-list wm)
) = "hyprland,dunst"

@test "nonexistent meta fails" (metapac-list nonexistent 2>/dev/null; echo $status) != 0

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_list.fish`
Expected: FAIL.

- [ ] **Step 3: Write the implementation**

```fish
# functions/metapac-list.fish
function metapac-list --description "List metas or packages in a meta"
    argparse -s -X1 -- $argv
    or return

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fishtape tests/test_list.fish`
Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add functions/metapac-list.fish tests/test_list.fish
git commit -m "feat: add metapac list"
```

---

### Task 10: Status (`metapac-status`)

**Files:**
- Create: `tests/test_status.fish`
- Create: `functions/metapac-status.fish`

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_status.fish
source (status dirname)/setup.fish

echo 'hyprland' > $METAPAC_CONFIG_DIR/wm.meta
echo 'git' > $METAPAC_CONFIG_DIR/dev.meta
set -g pacman_query_db metapac-wm

@test "shows installed metas" (metapac-status | string match -q '*wm*installed*'; echo $status) = 0
@test "shows not-installed metas" (metapac-status | string match -q '*dev*not installed*'; echo $status) = 0
@test "lists all metas" (test (count (metapac-status)) -ge 2; echo $status) = 0

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_status.fish`
Expected: FAIL.

- [ ] **Step 3: Write the implementation**

```fish
# functions/metapac-status.fish
function metapac-status --description "Show install status of all metas"
    argparse -s -X0 -- $argv
    or return

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
            set version (pacman -Q $pkgname | string split ' ')[2]
            echo "$name  $pkg_count pkg(s)  installed ($version)"
        else
            echo "$name  $pkg_count pkg(s)  not installed"
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fishtape tests/test_status.fish`
Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add functions/metapac-status.fish tests/test_status.fish
git commit -m "feat: add metapac status"
```

---

### Task 11: Presets (`__metapac_presets` and `metapac-preset`)

**Files:**
- Create: `tests/test_preset.fish`
- Create: `functions/__metapac_presets.fish`
- Create: `functions/metapac-preset.fish`

- [ ] **Step 1: Write the failing tests**

```fish
# tests/test_preset.fish
source (status dirname)/setup.fish

@test "preset list shows all 21 presets" (test (count (metapac-preset list)) -eq 21; echo $status) = 0
@test "preset list includes hyprland" (metapac-preset list | string match -q '*hyprland*'; echo $status) = 0
@test "preset list includes gnome" (metapac-preset list | string match -q '*gnome*'; echo $status) = 0

@test "preset show hyprland lists packages" (
    set pkgs (metapac-preset show hyprland)
    contains -- hyprland $pkgs; echo $status
) = 0

@test "preset show hyprland has dunst" (
    metapac-preset show hyprland | string match -q 'dunst'; echo $status
) = 0

@test "preset create makes meta file" (
    metapac-preset create hyprland
    test -f $METAPAC_CONFIG_DIR/archinstall-hyprland.meta; echo $status
) = 0

@test "preset create meta has correct packages" (
    string join , (__metapac_read_meta $METAPAC_CONFIG_DIR/archinstall-hyprland.meta)
) = "hyprland,dunst,kitty,uwsm,dolphin,wofi,xdg-desktop-portal-hyprland,qt5-wayland,qt6-wayland,polkit-kde-agent,grim,slurp"

@test "preset show unknown fails" (metapac-preset show fakede 2>/dev/null; echo $status) != 0
@test "preset create refuses duplicate" (metapac-preset create hyprland 2>/dev/null; echo $status) != 0

cleanup
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fishtape tests/test_preset.fish`
Expected: FAIL.

- [ ] **Step 3: Write `__metapac_presets.fish`**

This function takes a preset name and outputs its package list. With no arguments, it lists all preset names.

```fish
# functions/__metapac_presets.fish
function __metapac_presets --description "Archinstall desktop preset data"
    if not set -q argv[1]
        echo awesome
        echo bspwm
        echo budgie
        echo cinnamon
        echo cosmic
        echo cutefish
        echo deepin
        echo enlightenment
        echo gnome
        echo hyprland
        echo i3
        echo labwc
        echo lxqt
        echo mate
        echo niri
        echo plasma
        echo qtile
        echo river
        echo sway
        echo xfce4
        echo xmonad
        return
    end

    switch $argv[1]
        case awesome
            echo awesome alacritty xorg-xrandr xterm feh slock terminus-font gnu-free-fonts ttf-liberation xsel | string split ' '
        case bspwm
            echo bspwm sxhkd dmenu xdo rxvt-unicode | string split ' '
        case budgie
            echo materia-gtk-theme budgie mate-terminal nemo papirus-icon-theme | string split ' '
        case cinnamon
            echo cinnamon system-config-printer gnome-keyring gnome-terminal engrampa gnome-screenshot gvfs-smb xed xdg-user-dirs-gtk | string split ' '
        case cosmic
            echo cosmic xdg-user-dirs | string split ' '
        case cutefish
            echo cutefish noto-fonts | string split ' '
        case deepin
            echo deepin deepin-terminal deepin-editor | string split ' '
        case enlightenment
            echo enlightenment terminology | string split ' '
        case gnome
            echo gnome gnome-tweaks | string split ' '
        case hyprland
            echo hyprland dunst kitty uwsm dolphin wofi xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-kde-agent grim slurp | string split ' '
        case i3
            echo i3-wm i3lock i3status i3blocks xss-lock xterm lightdm-gtk-greeter lightdm dmenu | string split ' '
        case labwc
            echo alacritty labwc | string split ' '
        case lxqt
            echo lxqt breeze-icons oxygen-icons xdg-utils ttf-freefont l3afpad slock | string split ' '
        case mate
            echo mate mate-extra | string split ' '
        case niri
            echo niri alacritty fuzzel mako xorg-xwayland waybar swaybg swayidle swaylock xdg-desktop-portal-gnome | string split ' '
        case plasma
            set variant recommended
            if set -q argv[2]
                set variant $argv[2]
            end
            switch $variant
                case recommended
                    echo plasma-meta | string split ' '
                case extensive
                    echo plasma | string split ' '
                case minimal
                    echo plasma-desktop | string split ' '
                case '*'
                    echo "metapac: unknown plasma variant: $variant (use recommended, extensive, or minimal)" >&2
                    return 1
            end
        case qtile
            echo qtile alacritty | string split ' '
        case river
            echo foot xdg-desktop-portal-wlr river | string split ' '
        case sway
            echo sway swaybg swaylock swayidle waybar wmenu brightnessctl grim slurp pavucontrol foot xorg-xwayland | string split ' '
        case xfce4
            echo xfce4 xfce4-goodies pavucontrol gvfs xarchiver | string split ' '
        case xmonad
            echo xmonad xmonad-contrib xmonad-extras xterm dmenu | string split ' '
        case '*'
            echo "metapac: unknown preset: $argv[1]" >&2
            return 1
    end
end
```

- [ ] **Step 4: Write `metapac-preset.fish`**

```fish
# functions/metapac-preset.fish
function metapac-preset --description "Manage archinstall desktop presets"
    argparse -s -N1 'variant=' -- $argv
    or return

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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fishtape tests/test_preset.fish`
Expected: All 9 tests pass.

- [ ] **Step 6: Commit**

```bash
git add functions/__metapac_presets.fish functions/metapac-preset.fish tests/test_preset.fish
git commit -m "feat: add preset support (21 archinstall desktop profiles)"
```

---

### Task 12: Main Entry Point (`metapac`)

**Files:**
- Create: `functions/metapac.fish`

This is the dispatcher that routes subcommands. No separate test file — it's tested via all the existing tests once wired up.

- [ ] **Step 1: Write the implementation**

```fish
# functions/metapac.fish
function metapac --description "Personal metapackage manager for Arch Linux"
    argparse -s -N1 h/help v/version -- $argv
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

    set subcmd $argv[1]
    set args $argv[2..]

    switch $subcmd
        case new
            metapac-new $args
        case add
            metapac-add $args
        case adopt
            metapac-adopt $args
        case remove
            metapac-remove $args
        case build
            metapac-build $args
        case drop
            metapac-drop $args
        case list
            metapac-list $args
        case status
            metapac-status $args
        case preset
            metapac-preset $args
        case '*'
            echo "metapac: unknown command: $subcmd" >&2
            echo "Run 'metapac --help' for usage." >&2
            return 1
    end
end
```

- [ ] **Step 2: Verify all tests still pass**

Run: `fishtape tests/test_*.fish`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add functions/metapac.fish
git commit -m "feat: add main entry point with subcommand dispatch"
```

---

### Task 13: Integration Test & Cleanup

**Files:**
- Modify: `tests/setup.fish` — remove smoke test
- Delete: `tests/test_smoke.fish`

- [ ] **Step 1: Write an end-to-end integration test**

```fish
# tests/test_integration.fish
source (status dirname)/setup.fish

set -g pacman_query_db hyprland dunst kitty

@echo "--- full workflow: preset create → adopt → add → remove → drop ---"

@test "create preset" (metapac preset create hyprland; echo $status) = 0
@test "meta file created" -f $METAPAC_CONFIG_DIR/archinstall-hyprland.meta

@test "adopt installed packages" (
    metapac adopt archinstall-hyprland hyprland dunst kitty
    echo $status
) = 0

@test "add new package" (
    metapac add archinstall-hyprland wofi
    echo $status
) = 0

@test "list shows packages" (test (count (metapac list archinstall-hyprland)) -ge 4; echo $status) = 0

@test "remove package from meta" (
    metapac remove --no-orphans archinstall-hyprland wofi
    echo $status
) = 0

@test "wofi no longer in meta" (
    not contains -- wofi (metapac list archinstall-hyprland)
    echo $status
) = 0

set -g pacman_query_db metapac-archinstall-hyprland

@test "drop meta" (metapac drop --delete archinstall-hyprland; echo $status) = 0
@test "meta file deleted" (test ! -f $METAPAC_CONFIG_DIR/archinstall-hyprland.meta; echo $status) = 0

cleanup
```

- [ ] **Step 2: Run the full test suite**

Run: `fishtape tests/test_*.fish`
Expected: All tests across all files pass.

- [ ] **Step 3: Delete smoke test**

Run: `rm tests/test_smoke.fish`

- [ ] **Step 4: Commit**

```bash
git add tests/test_integration.fish
git rm tests/test_smoke.fish
git commit -m "test: add integration test, remove smoke test"
```

---

### Task 14: Fish Completions

**Files:**
- Create: `completions/metapac.fish`

- [ ] **Step 1: Write completions**

```fish
# completions/metapac.fish
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

# Subcommands
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

# Meta name completions for commands that take a meta name
complete -c metapac -n '__metapac_using_subcmd add' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd adopt' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd remove' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd build' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd drop' -a '(__metapac_list_metas)' -d Meta
complete -c metapac -n '__metapac_using_subcmd list' -a '(__metapac_list_metas)' -d Meta

# Preset subcommands
complete -c metapac -n '__metapac_using_subcmd preset; and not __fish_seen_subcommand_from list show create' -a list -d "List presets"
complete -c metapac -n '__metapac_using_subcmd preset; and not __fish_seen_subcommand_from list show create' -a show -d "Show preset packages"
complete -c metapac -n '__metapac_using_subcmd preset; and not __fish_seen_subcommand_from list show create' -a create -d "Create meta from preset"
complete -c metapac -n '__metapac_using_subcmd preset; and __fish_seen_subcommand_from show create' -a '(__metapac_list_presets)' -d Preset

# Drop flags
complete -c metapac -n '__metapac_using_subcmd drop' -l delete -d "Also delete the .meta file"

# Remove flags
complete -c metapac -n '__metapac_using_subcmd remove' -l no-orphans -d "Skip orphan removal prompt"
```

- [ ] **Step 2: Commit**

```bash
git add completions/metapac.fish
git commit -m "feat: add fish tab completions"
```

---

### Task 15: README & Install Instructions

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with install and usage instructions"
```

---

Plan complete and saved to `docs/superpowers/plans/2026-05-24-metapac-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?

<function_calls>
<invoke name="AskUserQuestion">
<parameter name="questions">[{"question": "How should we execute the plan?", "header": "Execution", "options": [{"label": "Subagent-Driven (Recommended)", "description": "Dispatch a fresh subagent per task with review between tasks. Fast iteration, parallel where possible."}, {"label": "Inline Execution", "description": "Execute tasks sequentially in this session with checkpoints for review."}], "multiSelect": false}]