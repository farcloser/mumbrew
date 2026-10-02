# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see lib.just).
import 'lib.just'

# Security scans are not linters. A linter judges the tree, and the same tree
# gets the same verdict tomorrow; a scan judges the tree against a database
# that moves on its own, so a green turns red with nothing pushed. Hence a
# family of their own, apart from lint, and a CI lane of their own
# (.github/workflows/security.yaml), so a new advisory reddens one check that
# says what it is, and a red here is answered by a bump, not by a code change.

# The Go scans live in their own submodule: `just do security go` runs them
# all, `just do security go <recipe>` (vuln) runs one.
mod go 'security-go.just'

# A submodule's recipe IS addressable as a dependency (go::default); only a
# bare module path (go) is not.
default: go::default

# Every Go binary aqua pins carries its own copy of the standard library, built
# by its upstream with whatever Go they used that day: a fixed net/http or
# crypto/tls reaches us only when THEY rebuild. This scans each such binary
# against the Go vulnerability database (network: govulncheck fetches
# vuln.go.dev), by the symbols it links, so a known standard-library or module
# vulnerability in a pinned tool is seen the day the advisory lands, whoever
# built it. The binaries the pinned toolchain builds here (tools/go.mod) are
# the go vuln lane's; this one is for what we did not build. Enumerated from
# aqua's proxies: `aqua which` answers only for the names this repository's
# config provides, and `go version -m` tells a Go executable from the rest.
#
# Named, not yet in the default set: its first run found every pinned Go
# binary but the toolchain's own, golangci-lint and limen carrying known
# vulnerabilities, aqua included, and a red no repository can clear is
# noise. It joins the default set once the pinned tools are built here with
# the pinned toolchain and aqua's own pin is current.
binaries: (_banner "security" "binaries") (_go-tool "govulncheck" "golang.org/x/vuln/cmd/govulncheck")
    #!/usr/bin/env bash
    set -euo pipefail
    bin="$(aqua root-dir)/bin"
    # A newline-delimited list, not an associative array: macOS ships bash 3.
    seen=$'\n'
    fail=0
    for proxy in "$bin"/*; do
        name=${proxy##*/}
        name=${name%.exe}
        path=$(aqua which "$name" 2>/dev/null) || continue
        [ -f "$path" ] || continue
        case "$seen" in *$'\n'"$path"$'\n'*) continue;; esac
        seen="$seen$path"$'\n'
        go version -m "$path" >/dev/null 2>&1 || continue
        echo "→ $name"
        # A darwin universal binary (goreleaser ships one) is beyond govulncheck's
        # reader; the other platforms' legs scan that tool's thin binaries, so
        # the darwin leg says so and moves on rather than failing on a format.
        if ! out=$(build/tools/govulncheck -mode binary "$path" 2>&1); then
            case "$out" in
                *"unrecognized binary format"*) echo "  skipped: universal binary, scanned on the other platforms";;
                *) printf '%s\n' "$out"; fail=1;;
            esac
        fi
    done
    exit "$fail"
