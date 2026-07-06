# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see _lib.just).
import '_lib.just'

default: code mod

# golangci-lint auto-fixes, once per supported platform (see _per-goos in
# _lib.just: platform-specific files are only analyzed for the GOOS that
# builds them). The formatter is build-graph-independent and runs once — last,
# so the fixes' edits end up formatted.
code: (_banner "fix go" "go") (_per-goos "golangci-lint run --fix")
    golangci-lint fmt

# Tidy go.mod/go.sum.
mod: (_banner "fix go" "mod")
    go mod tidy

# Update every dependency to its latest version, then tidy.
up: (_banner "fix go" "up") && mod
    go get -u ./...
