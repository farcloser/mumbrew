# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

# Go tests live in their own submodule: `just do test go` runs the unit tests,
# `just do test go <recipe>` (e.g. `just do test go race`) runs one task.
#
# Bare `just do test` deliberately refuses: tests are always language-bound, so
# there is nothing a universal default could run that would not fail (or lie)
# on some repo. Which suites apply is each project's call — name one
# explicitly, and define the project-wide aggregate as `test-all` in
# the root Justfile (the CI workflow's entry point, mirroring lint-all).
default:
    @echo 'just test has no default — name a suite (e.g. `just do test go`), or run the project'"'"'s `just test-all`.' >&2
    @exit 1

mod go 'test-go.just'
