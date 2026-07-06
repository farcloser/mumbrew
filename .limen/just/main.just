# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# The root Justfile is the project's own: a shim that imports this file and
# then carries the project's recipes — everything shared lives here, so the
# shim never has to change.

# The project may redefine the shared recipes below (info, or an explicit
# default) in its root Justfile: the later definition — the project's — wins.
set allow-duplicate-recipes

# Project name, derived from the directory the root Justfile lives in.
project := file_name(justfile_directory())

# brew — the one machine-layer tool a shared recipe may call (the homebrew
# modules) — is captured from the AMBIENT PATH here, above the hermetic PATH
# so the lookup still sees the invoking shell's environment: brew is not
# aqua-pinnable and installs at machine-chosen prefixes, so that shell knows
# best where it lives. Empty when absent (the homebrew recipes then fail with
# guidance); override by exporting BREW_BIN.
export BREW_BIN := env_var_or_default('BREW_BIN', `command -v brew || true`)

# Hermetic PATH: aqua-pinned tools + base system only (no homebrew), so any tool that
# isn't pinned fails loudly instead of silently resolving to an unpinned copy.
# Windows (git-bash) is the sanctioned exception to that hermeticity: there is no
# knowable base-system directory list (sh, coreutils, and git live at
# install-dependent roots), and the separator is ';' — so the pinned tools are
# prepended to the ambient PATH instead. Pins still shadow everything, and
# hermeticity stays enforced by the posix legs of the CI matrix.
aqua_bin := env_var_or_default('AQUA_ROOT_DIR', env_var_or_default('XDG_DATA_HOME', home_directory() / '.local/share') / 'aquaproj-aqua') / 'bin'
export PATH := if os() == 'windows' { aqua_bin + ';' + env_var('PATH') } else { aqua_bin + ":/usr/bin:/bin:/usr/sbin:/sbin" }

# Hermetic Go env: ambient variables tunnel straight through the hermetic PATH.
# An inherited GOROOT (IDEs inject one, often pointing into the module cache,
# which `go clean -modcache` deletes) overrides where the pinned go finds its
# stdlib — with modern Go it should never be set: go derives it from its own
# location. Emptied rather than unexported: go treats '' as unset, and unlike
# `unexport`, an `export` propagates into module recipes. GOTOOLCHAIN=local
# forbids silent toolchain switching: when go.mod outpaces the pin, recipes
# fail loudly asking for a pin bump instead of downloading an unpinned
# toolchain behind your back.
export GOROOT := ''
export GOTOOLCHAIN := 'local'

# Hermetic, per-project linter cache (same doctrine as PATH and GOROOT: no
# shared mutable state across repos). Lives under build/ — gitignored, and
# local runs behave like CI instead of diverging on cache state.
export GOLANGCI_LINT_CACHE := justfile_directory() / 'build/cache/golangci-lint'

# just's default recipe is the FIRST one defined in the root Justfile, so a
# project's first own recipe takes over from this one — deliberately: the
# default belongs to the project.
# Show every available recipe — the project's own and the shared `do` tree.
default:
    @just --list

# Print meaningful information about this project.
info:
    @echo "name:     {{ project }}"
    @echo "upstream: $(git remote get-url origin 2>/dev/null || echo '(none)')"
    @echo "semver:   $(git describe --tags --abbrev=0 2>/dev/null || echo '(none)')"
    @echo "commit:   $(git rev-parse --short HEAD 2>/dev/null || echo '(none)')"
    @echo "date:     $(git log --max-count=1 --format=%cd --date=short 2>/dev/null || echo '(none)')"

# Every shared limen task: `just do lint`, `just do build go`, `just do release v1.2.3` — the top level stays the project's.
mod do 'do.just'
