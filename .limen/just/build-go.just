# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see _lib.just).
import '_lib.just'

# Ported from the historical Make build system, corrected along the way:
#   - a "binary" is a DIRECTORY under cmd/ that contains Go sources — a stray
#     file or docs directory no longer becomes a phantom target;
#   - version stamping is reproducible: main.version carries `git describe`,
#     and commit/date come from Go's own VCS embedding (`go version -m`) at
#     their COMMIT values — never wall-clock build time, which made the same
#     commit produce different binaries;
#   - build tags are scoped to these commands, never exported globally where
#     they would leak into tests and linters;
#   - static states its preconditions (Linux, CGO) and fails fast instead of
#     dying with a cryptic linker error;
#   - a race build exists.
# Binaries land in build/ (covered by the canonical .gitignore). Projects
# declare `var version = "dev"` in each main package for the stamp to land.
# Extra flags: export BUILD_GO_FLAGS from the root Justfile, the home of all
# project customization (the variable name mirrors the task path), or set it
# on the invocation for a one-off.

# netgo/osusergo force the pure-Go resolver and user lookups. No-ops when
# CGO_ENABLED=0 (pure Go already); with CGO they keep DNS and user handling
# out of libc, which is exactly what makes `static` viable on glibc.
go_tags := 'netgo,osusergo'

# CGO is opt-in per invocation (`CGO_ENABLED=1 just do build go`). Defaulted to 0
# explicitly for every recipe rather than left unset: go's own default is CGO
# on for native builds when a C toolchain exists, and unset must mean pure Go
# here.
export CGO_ENABLED := env('CGO_ENABLED', '0')

# --- C toolchain hardening — only effective when CGO_ENABLED=1 --------------
# The canonical hardening set (see the Red Hat compiler-flags guidance),
# platform-gated: stack-clash protection and the -z linker set are Linux-only
# (ld64 on macOS supports neither).
c_warnings := '-Wall -Werror=format-security'
c_security := '-fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=2' + (if os() == 'linux' { ' -fstack-clash-protection' } else { '' })
cgo_cflags_release := c_warnings + ' -O2 ' + c_security + ' -pipe'

# Debug: -O0 with real debug info. FORTIFY_SOURCE is deliberately absent — it
# requires -O1 or higher and would only produce warnings at -O0.
cgo_cflags_debug := c_warnings + ' -O0 -g -grecord-gcc-switches -pipe'

# libstdc++ assertions are a C++-only concern: valid in CXXFLAGS, not CFLAGS.
cgo_cxxflags_debug := cgo_cflags_debug + ' -D_GLIBCXX_ASSERTIONS'
cgo_ldflags := if os() == 'linux' { '-Wl,-z,defs -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack' } else { '' }

default: release

# Release: reproducible (trimpath, commit-time VCS stamp), stripped, PIE.
# Twin of the builds section in .goreleaser.yaml (the release builder, where
# a project ships one) — a flag change here must land there too. See the
# comment there for the differences that are intended.
release: (_banner "build go" "release")
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(git describe --tags --always --dirty 2>/dev/null || echo dev)
    ldflags="-s -w -X main.version=${version}"
    if [ "${CGO_ENABLED:-0}" = "1" ]; then
        export CGO_CFLAGS='{{ cgo_cflags_release }}'
        export CGO_CXXFLAGS='{{ cgo_cflags_release }}'
        export CGO_LDFLAGS='{{ cgo_ldflags }}'
        ldflags="-linkmode=external -extldflags=-pie ${ldflags}"
    fi
    extra=()
    [ -z "${BUILD_GO_FLAGS:-}" ] || read -ra extra <<<"${BUILD_GO_FLAGS}"
    mkdir -p build
    for dir in cmd/*/; do
        name=$(basename "${dir}")
        ls "${dir}"*.go >/dev/null 2>&1 || continue
        echo "→ build/${name}"
        go build -trimpath -buildmode=pie -tags='{{ go_tags }}' \
            -ldflags "${ldflags}" ${extra[@]+"${extra[@]}"} -o "build/${name}" "./${dir%/}"
    done

# Debug: optimizations and inlining off, symbols kept, real paths kept — no
# trimpath, deliberately: debuggers want actual file locations. -debug suffix.
debug: (_banner "build go" "debug")
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(git describe --tags --always --dirty 2>/dev/null || echo dev)
    ldflags="-X main.version=${version}"
    if [ "${CGO_ENABLED:-0}" = "1" ]; then
        export CGO_CFLAGS='{{ cgo_cflags_debug }}'
        export CGO_CXXFLAGS='{{ cgo_cxxflags_debug }}'
        export CGO_LDFLAGS='{{ cgo_ldflags }}'
        ldflags="-linkmode=external -extldflags=-pie ${ldflags}"
    fi
    extra=()
    [ -z "${BUILD_GO_FLAGS:-}" ] || read -ra extra <<<"${BUILD_GO_FLAGS}"
    mkdir -p build
    for dir in cmd/*/; do
        name=$(basename "${dir}")
        ls "${dir}"*.go >/dev/null 2>&1 || continue
        echo "→ build/${name}-debug"
        go build -buildmode=pie -gcflags='all=-N -l' -tags='{{ go_tags }}' \
            -ldflags "${ldflags}" ${extra[@]+"${extra[@]}"} -o "build/${name}-debug" "./${dir%/}"
    done

# Race: a diagnostic build with the race detector, which requires cgo (forced
# here) and, matching the test module, an external linkmode. Unstripped, real
# paths. -race suffix.
race: (_banner "build go" "race")
    #!/usr/bin/env bash
    set -euo pipefail
    export CGO_ENABLED=1
    version=$(git describe --tags --always --dirty 2>/dev/null || echo dev)
    extra=()
    [ -z "${BUILD_GO_FLAGS:-}" ] || read -ra extra <<<"${BUILD_GO_FLAGS}"
    mkdir -p build
    for dir in cmd/*/; do
        name=$(basename "${dir}")
        ls "${dir}"*.go >/dev/null 2>&1 || continue
        echo "→ build/${name}-race"
        go build -race -tags='{{ go_tags }}' \
            -ldflags "-linkmode=external -X main.version=${version}" \
            ${extra[@]+"${extra[@]}"} -o "build/${name}-race" "./${dir%/}"
    done

# Static: fully static external link. Preconditions enforced, not commented:
# Linux only (macOS has no static libc), and CGO_ENABLED=1 (with CGO off,
# every build is already static — use `release`). No PIE: classic static and
# PIE conflict. -static suffix.
static: (_banner "build go" "static")
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname -s)" != "Linux" ]; then
        echo "static builds require Linux: macOS has no static libc to link against." >&2
        exit 1
    fi
    if [ "${CGO_ENABLED:-0}" != "1" ]; then
        echo "static needs CGO_ENABLED=1 — a pure-Go build is already static (use \`just do build go\`)." >&2
        exit 1
    fi
    version=$(git describe --tags --always --dirty 2>/dev/null || echo dev)
    export CGO_CFLAGS='{{ cgo_cflags_release }}'
    export CGO_CXXFLAGS='{{ cgo_cflags_release }}'
    export CGO_LDFLAGS='{{ cgo_ldflags }}'
    extra=()
    [ -z "${BUILD_GO_FLAGS:-}" ] || read -ra extra <<<"${BUILD_GO_FLAGS}"
    mkdir -p build
    for dir in cmd/*/; do
        name=$(basename "${dir}")
        ls "${dir}"*.go >/dev/null 2>&1 || continue
        echo "→ build/${name}-static"
        go build -trimpath -tags='{{ go_tags }}' \
            -ldflags "-linkmode=external -extldflags=-static -s -w -X main.version=${version}" \
            ${extra[@]+"${extra[@]}"} -o "build/${name}-static" "./${dir%/}"
    done
