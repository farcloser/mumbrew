# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see lib.just).
import 'lib.just'

default: unit

# `go test` runs funnel through gotestsum: same exit semantics, readable live
# output (its format is gotestsum's own GOTESTSUM_FORMAT knob). -count=1
# defeats Go's test result cache — a test task must actually test. The shared
# timeout is project-overridable from the root Justfile, the home of all project
# customization:
#     export TEST_GO_TIMEOUT := '20m'

# Unit tests.
unit: (_banner "test go" "unit")
    gotestsum -- -count=1 -timeout "${TEST_GO_TIMEOUT:-10m}" ./...

# Unit tests under the race detector. The final link is delegated to the
# system linker: the race detector injects runtime/cgo into every package, and
# hardened CGO_CFLAGS (-fstack-protector-strong, -fPIE) make those objects
# reference libc symbols Go's internal linker cannot resolve on Linux
# ("relocation target stderr not defined") — see golang/go#52690, #54313,
# #58619. On macOS with Xcode 15+, ld emits "has malformed LC_DYSYMTAB"
# warnings for race builds; cosmetic, the binaries are correct (golang/go#61229).
race: (_banner "test go" "race")
    CGO_ENABLED=1 gotestsum -- -count=1 -timeout "${TEST_GO_TIMEOUT:-10m}" -ldflags=-linkmode=external -race ./...

# Benchmarks, with allocation stats. -run '^$' deselects unit tests so only
# benchmarks run — `just do test go` already covers the tests themselves.
bench: (_banner "test go" "bench")
    go test -count=1 -timeout "${TEST_GO_TIMEOUT:-10m}" -run '^$' -bench . -benchmem ./...

# Coverage: per-function summary, an HTML report under build/coverage/, and an
# optional minimum gate — export TEST_GO_COVER_MIN := '80' (integer percent)
# from the root Justfile to enforce a floor; unset or 0 reports without gating.
cover: (_banner "test go" "cover")
    #!/usr/bin/env bash
    set -euo pipefail
    dir=build/coverage
    mkdir -p "$dir"
    gotestsum -- -count=1 -timeout "${TEST_GO_TIMEOUT:-10m}" -coverprofile="$dir/coverage.out" ./...
    go tool cover -func="$dir/coverage.out"
    go tool cover -html="$dir/coverage.out" -o "$dir/coverage.html"
    echo "HTML report: $dir/coverage.html"
    min="${TEST_GO_COVER_MIN:-0}"
    if [ "$min" -gt 0 ] 2>/dev/null; then
        total=$(go tool cover -func="$dir/coverage.out" | awk '/^total:/ { gsub(/%/, "", $3); print $3 }')
        if [ "${total%%.*}" -lt "$min" ]; then
            echo "coverage ${total}% is below the ${min}% minimum" >&2
            exit 1
        fi
        echo "coverage ${total}% meets the ${min}% minimum"
    fi

# CPU and memory profiles, one pair per package, with pprof top-20 summaries
# printed and PNG call graphs rendered via the pinned `dot` (goccy/go-graphviz:
# real graphviz compiled to WASM, so it lives in aqua like any Go tool).
# Informational: a package whose tests fail is still profiled past, never
# fails the run. Artifacts land under build/profiles/ (raw) and
# build/profiles-docs/ (PNG); analyze interactively with `go tool pprof`.
profile: (_banner "test go" "profile")
    #!/usr/bin/env bash
    set -euo pipefail
    prof=build/profiles
    docs=build/profiles-docs
    mkdir -p "$prof" "$docs"
    # pprof's own -png shells out to dot writing to a pipe, which the WASM dot
    # cannot do (it needs -o) — so render from pprof's -dot text instead. The
    # pre-create matters: under a sandbox the WASM runtime can overwrite files
    # but not always create them. Paths stay cwd-relative for the same reason
    # (the runtime preopens only the working directory).
    render() {
        src=$1; png=$2; shift 2
        go tool pprof -dot -nodecount=20 "$@" "$src" > "$png.dot" 2>/dev/null
        : > "$png"
        dot -Tpng -o "$png" "$png.dot"
        rm -f "$png.dot"
        echo "  -> $png"
    }
    for pkg in $(go list ./...); do
        name=${pkg##*/}
        echo "Profiling $pkg..."
        go test -count=1 -o "$prof/$name.test" "$pkg" \
            -cpuprofile "$prof/${name}_cpu.prof" \
            -memprofile "$prof/${name}_mem.prof" || true
        if [ -s "$prof/${name}_cpu.prof" ]; then
            echo "  CPU profile (top 20):"
            go tool pprof -top -nodecount=20 "$prof/${name}_cpu.prof" 2>/dev/null || true
            render "$prof/${name}_cpu.prof" "$docs/${name}_cpu.png"
        fi
        if [ -s "$prof/${name}_mem.prof" ]; then
            echo "  Memory profile — alloc_space (top 20):"
            go tool pprof -top -nodecount=20 -alloc_space "$prof/${name}_mem.prof" 2>/dev/null || true
            render "$prof/${name}_mem.prof" "$docs/${name}_alloc.png" -alloc_space
        fi
    done
    echo "Profiles written to $prof/, diagrams to $docs/"
