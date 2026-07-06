# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see _lib.just).
import '_lib.just'

# The mutating counterpart of `just do lint homebrew` — brew's vendored
# RuboCop with --fix. Same machine-layer exception as the lint module:
# BREW_BIN is captured from the ambient PATH at just startup, never from the
# hermetic PATH (the reasoning lives in lint-homebrew.just and main.just).

default: style

# Repair what `just do lint homebrew style` reports; passes vacuously when the
# repository carries no formulas or casks.
style: (_banner "fix homebrew" "style")
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _skip_unless_macos }}
    # --cached --others --exclude-standard: tracked *and* new untracked files,
    # still honoring .gitignore (same as `fix just`). Modern tap layout ONLY —
    # Formula/ and Casks/; the legacy locations are deliberately unsupported
    # (see lint-homebrew.just). Discovery runs before the brew lookup so a
    # repo without formulas passes vacuously even brew-less.
    files=()
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <(git ls-files -z --cached --others --exclude-standard \
        'Formula/*.rb' 'Formula/**/*.rb' 'Casks/*.rb' 'Casks/**/*.rb')
    if [ "${#files[@]}" -eq 0 ]; then
        echo "no formulas or casks (Formula/, Casks/) — nothing to fix."
        exit 0
    fi
    {{ _require_brew }}
    # shellcheck disable=SC2154 # BREW_BIN is exported by the canonical Justfile (main.just).
    "$BREW_BIN" style --fix "${files[@]}"

# Homebrew exists on macOS only: everywhere else this recipe degrades to a
# LOUD no-op — the twin of the variable in lint-homebrew.just; a change here
# must land there too.
[private]
_skip_unless_macos := '''
    if [ "$(uname -s)" != 'Darwin' ]; then
        echo "homebrew is macOS-only — nothing to do on this platform (skipped, not failed)."
        exit 0
    fi
'''

# BREW_BIN comes from main.just (ambient-PATH capture) — the twin of the
# variable in lint-homebrew.just; a change here must land there too.
[private]
_require_brew := '''
    if [ -z "${BREW_BIN:-}" ]; then
        echo "brew was not found on your PATH when just started." >&2
        echo "brew is a machine-layer tool — install it outside the repo (or export" >&2
        echo "BREW_BIN=/path/to/brew), then re-run." >&2
        exit 1
    fi
'''
