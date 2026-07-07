# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see lib.just).
import 'lib.just'

default: code mod vuln licenses

# golangci-lint, once per supported platform (see _per-goos in lib.just:
# platform-specific files are only analyzed for the GOOS that builds them).
# The formatter is build-graph-independent and runs once. The last step bans
# blanket revive suppressions: nolintlint polices golangci directives, and
# revive findings proved environment-nondeterministic across the per-GOOS
# legs — the suppression itself then flakes as "unused". revive's own
# selective directives are invisible to nolintlint, hence stable.
code: (_banner "lint go" "go") (_per-goos "golangci-lint run")
    golangci-lint fmt --diff
    @if git grep -nE 'nolint:[a-z, ]*revive' -- '*.go'; then echo 'blanket revive suppression is banned — use //revive:disable-next-line:<rule> (or a disable/enable block) instead' >&2; exit 1; fi

# go.mod/go.sum tidiness — fails printing the diff; `just do fix go mod` repairs.
mod: (_banner "lint go" "mod")
    go mod tidy -diff

# Known-vulnerability scan against the Go vulnerability database (network:
# govulncheck fetches vuln.go.dev), once per supported platform (see _per-goos
# in lib.just: call paths and dependencies differ by GOOS).
vuln: (_banner "lint go" "vuln") (_per-goos "govulncheck ./...")

# Dependency license compliance, once per supported platform (see _per-goos in
# lib.just: each GOOS pulls its own dependencies). A project that needs extra
# flags — typically --ignore=<module> for the module-layout false positives of
# https://github.com/google/go-licenses/issues/186 — exports them from its
# the root Justfile, the home of all project customization (the variable name
# mirrors the task path `lint go licenses`):
#     export LINT_GO_LICENSES_FLAGS := '--ignore=gotest.tools/v3'
# For a one-off, set it on the invocation instead:
# LINT_GO_LICENSES_FLAGS='--ignore=x' just do lint go licenses
#
# GOROOT is passed explicitly because go-licenses recognizes stdlib packages by
# their location under GOROOT — but, being a go_install binary, its built-in
# default is the GOROOT of whatever toolchain COMPILED it. When that differs
# from the pinned toolchain on PATH (which is where packages actually load
# from), every stdlib package degrades to "does not have module info" errors.
licenses: (_banner "lint go" "licenses") (_per-goos 'GOROOT="$(go env GOROOT)" go-licenses check --include_tests --allowed_licenses=Apache-2.0,BSD-2-Clause,BSD-3-Clause,MIT ${LINT_GO_LICENSES_FLAGS:-} ./...')

# Bounds-check-elimination report: every bounds check the compiler could NOT
# eliminate, for performance tuning. Informational — it never fails, so it is
# not in the default set; and it reports for the native architecture only,
# since BCE results are arch-specific and this is a report for the human
# reading it, not a gate.
bce: (_banner "lint go" "bce")
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Bounds Check Elimination Report"
    echo "================================"
    echo ""
    output=$(go build -gcflags='-d=ssa/check_bce/debug=1' ./... 2>&1 | grep -v '^#' || true)
    if [ -z "$output" ]; then
        echo "No bounds checks detected (BCE fully eliminated)."
    else
        total=$(echo "$output" | wc -l | tr -d ' ')
        echo "Total: $total bounds checks"
        echo ""
        echo "By file:"
        echo "$output" | sed 's/:.*$//' | sort | uniq -c | sort -rn
        echo ""
        echo "Details:"
        echo "$output" | sort
    fi

# Escape-analysis and inlining report — both come from the same compiler pass
# (-gcflags=-m): values the compiler moved to the heap (the prime source of GC
# pressure) and functions it refused to inline, with the reason. Informational
# like bce: never fails, native architecture only, not in the default set.
escape: (_banner "lint go" "escape")
    #!/usr/bin/env bash
    set -euo pipefail
    output=$(go build -gcflags='-m' ./... 2>&1 | grep -v '^#' || true)
    heap=$(echo "$output" | grep -E 'escapes to heap|moved to heap' || true)
    noinline=$(echo "$output" | grep 'cannot inline' || true)
    echo "Escape Analysis Report"
    echo "======================"
    if [ -z "$heap" ]; then
        echo "No heap escapes."
    else
        echo "Total: $(echo "$heap" | wc -l | tr -d ' ') heap escapes"
        echo ""
        echo "By file:"
        echo "$heap" | sed 's/:.*$//' | sort | uniq -c | sort -rn
        echo ""
        echo "$heap" | sort
    fi
    echo ""
    echo "Inlining Failures"
    echo "================="
    if [ -z "$noinline" ]; then
        echo "None."
    else
        echo "Total: $(echo "$noinline" | wc -l | tr -d ' ') functions the compiler could not inline"
        echo ""
        echo "$noinline" | sort
    fi

# Unreachable functions, by whole-program call-graph analysis (deeper than the
# per-package `unused` linter in golangci). -test keeps library-only repos
# analyzable (test binaries serve as roots) and stops dead code from hiding
# behind test-only callers. Informational: native only, not in the default set.
deadcode: (_banner "lint go" "deadcode")
    deadcode -test ./...
