# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see lib.just).
import 'lib.just'

default: links yaml shell dockerfile commits just aqua limen

# Go linters live in their own submodule: `just do lint go` runs them all,
# `just do lint go <recipe>` (e.g. `just do lint go mod`) runs one.
mod go 'lint-go.just'
mod rust 'lint-rust.just'

# Homebrew formula linting (`just do lint homebrew`): brew's own vendored
# tooling, resolved by absolute path — the machine-layer exception documented
# in the module itself. Explicit like the language modules, not in the
# default set.
mod homebrew 'lint-homebrew.just'

# limen itself: verify the repository against the Farcloser engineering rules
# (mandatory files, canonical baseline, license, aqua pins). First in the
# default set: the other linters trust the canonical files this one verifies.
# LIMEN_BIN exists for one consumer — the limen repository itself, whose
# the root Justfile points it at `go run ./cmd/limen` so the working tree is judged
# by its own enforcer, not by the (always older) released pin. Everyone else
# runs the aqua-pinned binary.
limen: (_banner "lint" "limen")
    ${LIMEN_BIN:-limen} check .

# GitHub settings audit — `limen github check` against this repository
# (inferred from origin), or any target the subcommand takes
# (`just do lint github -org farcloser`). Named, never in the default set: it
# needs the network and an authed gh, and its subject is the live GitHub
# state, not the tree. Same LIMEN_BIN override as `lint limen`.
github *args: (_banner "lint" "github")
    ${LIMEN_BIN:-limen} github check {{ args }}

just: (_banner "lint" "just")
    #!/usr/bin/env bash
    set -euo pipefail
    # --cached --others --exclude-standard: tracked *and* new untracked files,
    # still honoring .gitignore — so a not-yet-staged file is linted too.
    git ls-files -z --cached --others --exclude-standard 'justfile' 'Justfile' '*.just' '**/justfile' \
      | xargs -0 -I{} just --fmt --check --justfile {}

# godolint — hadolint as pure Go (https://github.com/farcloser/godolint) —
# over every Dockerfile in the repository; passes vacuously when there are
# none, so it can sit in the default set for every repo. Rule exceptions
# belong next to the instruction they excuse, as inline
# `# hadolint ignore=DLxxxx` pragmas — not in the recipe.
dockerfile: (_banner "lint" "dockerfile")
    #!/usr/bin/env bash
    set -euo pipefail
    # --cached --others --exclude-standard: tracked *and* new untracked files,
    # still honoring .gitignore — so a not-yet-staged Dockerfile is linted too
    # (same as `lint just`). The patterns cover the naming conventions — the
    # bare name and the <name>.<variant> / <variant>.<name> forms, at any
    # depth — for both Dockerfile and its OCI-neutral synonym Containerfile
    # (podman/buildah). '*.Dockerfile' needs no '**/' twin — a wildcard pattern
    # already matches across directories; a literal like 'Dockerfile' does not.
    files=()
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <(git ls-files -z --cached --others --exclude-standard \
        'Dockerfile' '**/Dockerfile' 'Dockerfile.*' '**/Dockerfile.*' '*.Dockerfile' \
        'Containerfile' '**/Containerfile' 'Containerfile.*' '**/Containerfile.*' '*.Containerfile')
    # godolint validates RUN instructions through shellcheck when it finds it
    # on PATH — the hermetic PATH (see the root Justfile) always provides the
    # pinned one.
    [ ${#files[@]} -eq 0 ] || godolint "${files[@]}"

yaml: (_banner "lint" "yaml")
    yamlfmt -conf .limen/.yamlfmt -lint

shell: (_banner "lint" "shell")
    #!/usr/bin/env bash
    set -euo pipefail
    # A file is a shell script if it declares itself one, by either signal:
    #   - a .sh/.bash extension → a missing shebang is then a lint error (SC2148), or
    #   - a shebang on line 1 for a dialect shellcheck lints (sh/bash/dash/ksh —
    #     not zsh, which shellcheck cannot check) → covers extension-less scripts.
    # Filtering on the shebang alone would silently skip an *.sh that forgot its shebang.
    # No mapfile (bash 4+): build the array with a read loop, portable to bash 3.2.
    files=()
    while IFS= read -r -d '' f; do
        case "$f" in
            *.sh|*.bash) files+=("$f"); continue ;;
        esac
        head -n 1 "$f" 2>/dev/null | grep -qE '^#!.*\b(bash|dash|ksh|sh)\b' && files+=("$f")
    done < <(git ls-files -z --cached --others --exclude-standard)
    [ ${#files[@]} -eq 0 ] || shellcheck --rcfile .limen/.shellcheckrc "${files[@]}"
    # Shebang recipes inside justfiles are shell scripts too — extract each
    # body from `just --dump --dump-format json` and shellcheck it standalone.
    # In the dump a body line is a fragment list: text fragments are strings,
    # interpolations (double-brace expressions — just syntax, not shell) are
    # arrays, masked as INTERP. One dump of the root justfile covers the whole
    # tree: imports (the root Justfile) are flattened into .recipes — they cannot be
    # parsed standalone, their dependencies may name root-level module paths —
    # and every `mod` nests recursively under .modules. mktemp gets an explicit
    # template because macOS mktemp ignores $TMPDIR.
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/lint-shell.XXXXXX")
    trap 'rm -rf "$tmpdir"' EXIT
    recipes=()
    dump=$(just --dump --dump-format json)
    # Bodies are multi-line: base64 carries each across the one-record-per-line
    # pipe intact (quotes, tabs and all). The trailing tr matters: the native
    # windows jq writes CRLF, and the stray \r lands in the last TSV field,
    # corrupting the base64 ("base64: invalid input"). \r cannot legitimately
    # appear in this stream (recipe names and base64), so a blanket strip is safe.
    while IFS=$'\t' read -r name body; do
        # ':' is illegal in windows filenames — the msys layer creates
        # "do::lint" via a private-use encoding that native shellcheck then
        # cannot open (openBinaryFile: invalid argument). The name is only a
        # label; flatten module separators.
        out="$tmpdir/${name//:/_}"
        printf '%s' "$body" | base64 -d > "$out"
        head -n 1 "$out" | grep -qE '^#!.*\b(bash|dash|ksh|sh)\b' || continue
        recipes+=("$out")
    done < <(printf '%s' "$dump" | jq -r '
        def recipes_of(prefix):
            ((.recipes // {}) | to_entries[]
                | [prefix + .key,
                   (.value.body
                    | map(map(if type == "string" then . else "INTERP" end) | join(""))
                    | join("\n") | @base64)]),
            ((.modules // {}) | to_entries[]
                | .key as $mod | .value | recipes_of(prefix + $mod + "::"));
        recipes_of("") | @tsv' | tr -d '\r')
    # SC1010 is excluded for recipe bodies only: `just do <task>` is our shared
    # namespace, and shellcheck misreads the argument "do" as the shell keyword.
    # The constant-word checks (SC2050/SC2078/SC2157/SC2194) are excluded for
    # recipe bodies only: a masked INTERP is constant to shellcheck but dynamic
    # in reality, so those hits can only be false positives of the masking.
    [ ${#recipes[@]} -eq 0 ] || shellcheck --rcfile .limen/.shellcheckrc --exclude=SC1010,SC2050,SC2078,SC2157,SC2194 "${recipes[@]}"

# Check documentation links with lychee (respects .gitignore, skips hidden files).
links: (_banner "lint" "links")
    #!/usr/bin/env bash
    set -euo pipefail
    # A directory input (not a glob) is what makes lychee honor .gitignore/hidden.
    # Canonical exclusions (and their rationale) live in .limen/lychee.toml; a
    # repository adds its own in a root .lychee.toml. Both must be passed
    # explicitly — any --config disables lychee's ./lychee.toml auto-discovery —
    # and lychee merges them, concatenating the exclude lists.
    args=(--config .limen/lychee.toml)
    if [ -f .lychee.toml ]; then
        args+=(--config .lychee.toml)
    fi
    lychee --no-progress "${args[@]}" .

# Validate commit hygiene — DCO sign-off, subject length, dangling whitespace —
# over a commit range (default: everything ahead of the upstream default branch;
# pass one explicitly otherwise, e.g. `just do lint commits v1.0.0..HEAD`).
commits range="": (_banner "lint" "commits")
    #!/usr/bin/env bash
    set -euo pipefail
    # Contributors' SSH keys, when the repo ships them, arm signature display
    # for humans (git log --show-signature, git tag -v). None of the rules run
    # below verify signatures — this is convenience wiring, not enforcement.
    # See https://github.com/andyfeller/gh-ssh-allowed-signers for automation
    # to retrieve contributor keys.
    if [ -f .allowed_signers ]; then
        git config --unset-all gpg.ssh.allowedSignersFile 2>/dev/null || true
        git config --add gpg.ssh.allowedSignersFile .allowed_signers
    fi
    range="{{ range }}"
    if [ -z "$range" ] && [ -n "${GITHUB_BASE_REF:-}" ]; then
        # GitHub Actions pull request: validate against the PR's actual base
        # branch, whatever it targets. Requires actions/checkout with
        # fetch-depth: 0 — the default shallow checkout has no base refs (and
        # only the synthetic merge commit as "history": vacuously green).
        if git rev-parse --verify -q "origin/$GITHUB_BASE_REF" >/dev/null 2>&1; then
            range="origin/${GITHUB_BASE_REF}..HEAD"
        fi
    fi
    if [ -z "$range" ]; then
        # Default to the commits this branch adds over the upstream default
        # branch. origin/HEAD is only set when `git remote set-head` ran, so
        # fall back through the common default-branch names; with no upstream
        # at all, validate the full history.
        for ref in origin/HEAD origin/main origin/master; do
            if git rev-parse --verify -q "$ref" >/dev/null 2>&1; then
                range="$ref..HEAD"
                break
            fi
        done
    fi
    if [ -n "$range" ]; then
        git-validation -run DCO,short-subject,dangling-whitespace -range "$range"
    else
        git-validation -run DCO,short-subject,dangling-whitespace
    fi

# Verify aqua-checksums.json is complete and in sync with aqua.yaml.
aqua: (_banner "lint" "aqua")
    #!/usr/bin/env bash
    set -euo pipefail
    # aqua has no read-only validator, so regenerate and compare against the
    # committed file (needs network). `git diff HEAD` is staging-independent — it
    # compares the working tree to the last commit, not the index. On drift the
    # corrected file is left in place — review and commit it.
    # --log-level warn: the per-package INFO lines are noise when nothing is wrong.
    aqua --log-level warn update-checksum --prune
    if ! git diff --quiet HEAD -- aqua-checksums.json; then
        echo "aqua-checksums.json was out of sync with aqua.yaml (regenerated above) — review and commit it." >&2
        exit 1
    fi
