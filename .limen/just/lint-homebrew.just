# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see lib.just).
import 'lib.just'

# Homebrew formula linting runs through brew itself: brew vendors its own Ruby
# and its own RuboCop with the Homebrew cops, so this module needs no Ruby
# toolchain — installing rubocop separately would be the wrong setup (plain
# RuboCop does not know the formula audit rules).
#
# brew is the one tool here that is NOT on the hermetic PATH, deliberately:
# it is a machine-layer package manager (not aqua-pinnable), and the PATH
# exclusion exists to stop machine tools substituting for pinned ones — brew
# is not substituting for anything, it IS the subject under test; formulas
# only mean anything on a machine that has it. The exception stays narrow:
# BREW_BIN is captured from the AMBIENT PATH at just startup (see main.just),
# before the hermetic PATH locks down — the invoking shell knows where brew
# lives, whatever the prefix — and the hermetic PATH itself is untouched.

default: style audit

# Homebrew's RuboCop profile over every formula and cask in the repository;
# passes vacuously when there are none. The mutating twin is
# `just do fix homebrew style`.
style: (_banner "lint homebrew" "style")
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _skip_unless_macos }}
    # --cached --others --exclude-standard: tracked *and* new untracked files,
    # still honoring .gitignore (same as `lint just`). The patterns are the
    # modern tap layout ONLY: Formula/ (sharded subdirectories included) and
    # Casks/. The legacy layouts brew still reads (HomebrewFormula/, bare *.rb
    # at the repository root) are deliberately unsupported — a formula living
    # there is invisible here, so put it in Formula/. Discovery runs before
    # the brew lookup so a repo without formulas passes vacuously even
    # brew-less.
    files=()
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <(git ls-files -z --cached --others --exclude-standard \
        'Formula/*.rb' 'Formula/**/*.rb' 'Casks/*.rb' 'Casks/**/*.rb')
    if [ "${#files[@]}" -eq 0 ]; then
        echo "no formulas or casks (Formula/, Casks/) — nothing to lint."
        exit 0
    fi
    {{ _require_brew }}
    # shellcheck disable=SC2154 # BREW_BIN is exported by the canonical Justfile (main.just).
    "$BREW_BIN" style "${files[@]}"

# The semantic checker: URL/sha256 coherence, license tags, deprecated DSL,
# dependency ordering. brew addresses formulas by TAP NAME, never by path, so
# the project must declare which tap it is (export LINT_HOMEBREW_TAP :=
# 'user/name' in the root Justfile) and this recipe registers the working tree
# as that tap — a symlink, so the audit judges the working tree, not a clone —
# for the duration of the run. Extra flags (CI wants --online, which does
# network calls) go through LINT_HOMEBREW_AUDIT_FLAGS.
audit: (_banner "lint homebrew" "audit")
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _skip_unless_macos }}
    # Same vacuous pass as `style`: no formulas, nothing to audit, no brew
    # (and no tap declaration) required.
    if [ -z "$(git ls-files --cached --others --exclude-standard \
        'Formula/*.rb' 'Formula/**/*.rb' 'Casks/*.rb' 'Casks/**/*.rb')" ]; then
        echo "no formulas or casks (Formula/, Casks/) — nothing to audit."
        exit 0
    fi
    {{ _require_brew }}
    tap="${LINT_HOMEBREW_TAP:-}"
    case "$tap" in
        */*) ;;
        *)
            echo "LINT_HOMEBREW_TAP is not set (or not 'user/name') — brew audit addresses formulas" >&2
            echo "by tap name, not by path. Export it in the root Justfile, e.g.:" >&2
            echo "  export LINT_HOMEBREW_TAP := 'farcloser/tap'" >&2
            exit 1
            ;;
    esac
    # shellcheck disable=SC2154 # BREW_BIN is exported by the canonical Justfile (main.just).
    link="$("$BREW_BIN" --repository)/Library/Taps/${tap%%/*}/homebrew-${tap##*/}"
    created=""
    if [ -e "$link" ] || [ -L "$link" ]; then
        # Already tapped: proceed only when it is exactly this checkout —
        # auditing a stale clone of the same tap would judge the wrong tree.
        if [ "$(readlink "$link" 2>/dev/null || true)" != "$PWD" ]; then
            echo "tap $tap is already installed at" >&2
            echo "  $link" >&2
            echo "and is not this checkout — untap it (brew untap $tap) or audit there." >&2
            exit 1
        fi
    else
        mkdir -p "$(dirname "$link")"
        ln -s "$PWD" "$link"
        created="$link"
    fi
    cleanup() {
        if [ -n "$created" ]; then
            rm -f "$created"
        fi
    }
    trap cleanup EXIT
    # shellcheck disable=SC2086 # deliberate word-split of the flags knob.
    "$BREW_BIN" audit --strict --tap "$tap" ${LINT_HOMEBREW_AUDIT_FLAGS:-}

# Homebrew exists on macOS only: everywhere else these recipes degrade to a
# LOUD no-op, so a repository can keep homebrew in its lint/fix aggregates
# and still run the full suite on the linux/windows legs of the matrix.
# Injected into recipe bodies as a just variable (same mechanism as
# _require_brew below); the twin lives in fix-homebrew.just.
[private]
_skip_unless_macos := '''
    if [ "$(uname -s)" != 'Darwin' ]; then
        echo "homebrew is macOS-only — nothing to do on this platform (skipped, not failed)."
        exit 0
    fi
'''

# BREW_BIN is captured from the ambient PATH in main.just (see the module
# comment); this only refuses when that capture came up empty. Injected into
# recipe bodies as a just variable because module recipes cannot share shell
# functions.
[private]
_require_brew := '''
    if [ -z "${BREW_BIN:-}" ]; then
        echo "brew was not found on your PATH when just started." >&2
        echo "brew is a machine-layer tool — install it outside the repo (or export" >&2
        echo "BREW_BIN=/path/to/brew), then re-run." >&2
        exit 1
    fi
'''
