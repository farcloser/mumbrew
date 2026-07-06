# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

set working-directory := '../..'

# Silence just's per-line command echo; recipes announce themselves via _banner.
set quiet

# Shared private _banner recipe (see _lib.just).
import '_lib.just'

# --- Project tooling via aqua (see book/tooling.md). Each recipe takes the
#     owner/repo exactly as it appears in aqua.yaml, e.g. golangci/golangci-lint. ---

# Add a new tool at its latest version, e.g. `just do tools add junegunn/fzf`.
add pkg: (_banner "tools" "add")
    #!/usr/bin/env bash
    set -euo pipefail
    if grep -qE "^[[:space:]]*-[[:space:]]*name:[[:space:]]*{{ pkg }}([[:space:]]|@|$)" aqua.yaml; then
        echo "{{ pkg }} is already in aqua.yaml — use 'just do tools update {{ pkg }}' or 'just do tools set {{ pkg }} <version>'." >&2
        exit 1
    fi
    aqua generate -i "{{ pkg }}"      # append the latest version to aqua.yaml
    aqua update-checksum --prune      # record its checksum (and drop stale ones)
    aqua install --only-link          # install and verify

# Set an existing tool to an exact version, e.g. `just do tools set golangci/golangci-lint v1.55.3`.
set pkg version: (_banner "tools" "set")
    #!/usr/bin/env bash
    set -euo pipefail
    if ! grep -qE "^[[:space:]]*-[[:space:]]*name:[[:space:]]*{{ pkg }}@" aqua.yaml; then
        echo "{{ pkg }} is not pinned in aqua.yaml — add it with 'just do tools add {{ pkg }}'." >&2
        exit 1
    fi
    # An explicit path template: macOS mktemp ignores $TMPDIR and falls back to
    # a per-user temp dir that sandboxes may deny writes to. A sibling file also
    # makes the mv a same-filesystem, truly atomic rename.
    tmp=$(mktemp aqua.yaml.XXXXXX)
    trap 'rm -f "$tmp"' EXIT
    sed -E "s#(^[[:space:]]*-[[:space:]]*name:[[:space:]]*{{ pkg }})@[^[:space:]]*#\1@{{ version }}#" aqua.yaml > "$tmp"
    mv "$tmp" aqua.yaml
    aqua update-checksum --prune      # new checksum in, replaced version's out
    aqua install --only-link          # install and verify

# Update an existing tool to its latest version, e.g. `just do tools update golangci/golangci-lint`.
update pkg: (_banner "tools" "update")
    #!/usr/bin/env bash
    set -euo pipefail
    latest=$(aqua generate "{{ pkg }}" 2>/dev/null | grep -E 'name:' | head -n 1 | sed -E 's/.*@//' | tr -d '[:space:]')
    if [ -z "$latest" ]; then
        echo "could not resolve the latest version of {{ pkg }}." >&2
        exit 1
    fi
    just do tools set "{{ pkg }}" "$latest"

# Remove a tool entirely, e.g. `just do tools remove junegunn/fzf`.
remove pkg: (_banner "tools" "remove")
    #!/usr/bin/env bash
    set -euo pipefail
    if ! grep -qE "^[[:space:]]*-[[:space:]]*name:[[:space:]]*{{ pkg }}([[:space:]]|@|$)" aqua.yaml; then
        echo "{{ pkg }} is not in aqua.yaml — nothing to remove." >&2
        exit 1
    fi
    # See `set` for why mktemp gets an explicit sibling-path template.
    tmp=$(mktemp aqua.yaml.XXXXXX)
    trap 'rm -f "$tmp"' EXIT
    awk -v pkg="{{ pkg }}" '
        function isCont(l) { return (l ~ /^[[:blank:]]+[^[:blank:]#-]/) }
        {
            if (skip) { if (isCont($0)) next; skip = 0 }
            if ($0 ~ "^[[:blank:]]*-[[:blank:]]*name:[[:blank:]]*" pkg "([[:blank:]]|@|$)") { skip = 1; next }
            print
        }
    ' aqua.yaml > "$tmp"
    mv "$tmp" aqua.yaml
    aqua remove "{{ pkg }}" || true   # uninstall the binary (no-op for go_install tools)
    aqua update-checksum --prune      # drop the now-unused checksum
