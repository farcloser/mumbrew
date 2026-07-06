# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see _lib.just).
import '_lib.just'

default: limen just yaml

# limen itself: repair what `just do lint limen` reports — rewrite drifted
# canonical files, create missing mandatory ones, restore aqua pins and
# regenerate aqua-checksums.json (network, when pins changed). Same LIMEN_BIN
# override as the lint recipe (see lint.just).
limen: (_banner "fix" "limen")
    ${LIMEN_BIN:-limen} fix .

# Repair what `just do lint github` reports — plans first, applies on consent
# (pass -yes for unattended use, -org <name> for the organization). Never in
# the default set, same reasoning as the lint twin.
github *args: (_banner "fix" "github")
    ${LIMEN_BIN:-limen} github fix {{ args }}

just: (_banner "fix" "just")
    #!/usr/bin/env bash
    set -euo pipefail
    # --cached --others --exclude-standard: tracked *and* new untracked files,
    # still honoring .gitignore — so a not-yet-staged file is formatted too.
    git ls-files -z --cached --others --exclude-standard 'justfile' 'Justfile' '*.just' '**/justfile' \
      | xargs -0 -I{} just --fmt --justfile {}

yaml: (_banner "fix" "yaml")
    yamlfmt -conf .limen/.yamlfmt

# Go fixers live in their own submodule: `just do fix go` runs them all,
# `just do fix go <recipe>` (e.g. `just do fix go mod`) runs one.
mod go 'fix-go.just'
mod rust 'fix-rust.just'
mod homebrew 'fix-homebrew.just'
