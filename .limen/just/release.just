# DO NOT EDIT MANUALLY.
# This file provides shared tasks common to all projects and managed by limen.
# Project recipes live in the root Justfile, below the shared-baseline import.

# Imported flat into the canonical Justfile — not a module — so the recipe can
# take arguments (`just do release v1.2.3`; a module invocation would parse the
# tag as a recipe path). Deliberately no settings and no _lib import here: an
# import's settings would apply to the whole importing module.

# Release. The default is the CI lane; everything local is opted into with
# --local (see book/recipes.md):
#
#   just do release vX.Y.Z
#       Verify a clean tree, create the signed tag (your key signs the
#       INTENT), push — the release workflow builds, signs the artifacts
#       (keyless cosign), and publishes.
#
#   just do release --local <cosign-key> vX.Y.Z [--cosign-password <password>]
#       The fully local lane: tag + goreleaser + key-based cosign from this
#       machine. The key path is a mandatory argument; the password is
#       prompted when not given. For private repos (nothing touches Rekor's
#       public log) — and the escape hatch when CI is down.
#
#   just do release --local --dry-run
#       Unsigned local snapshot into build/release/: no tag, no token, no
#       publish — and works on a dirty tree, by design.
#
#   just do release --ci
#       The workflow half of the default lane (GitHub Actions only): the
#       pushed tag triggered us; run goreleaser with keyless signing.
#
# Tag pushes are always exactly one tag, never --tags: stray local tags stay
# local. A tag already on HEAD is reused, so a failed publish retries safely.
[doc('Release: `vX.Y.Z` tags for CI · `--local <cosign-key> vX.Y.Z` · `--local --dry-run` · `--ci`')]
release *args:
    #!/usr/bin/env bash
    set -euo pipefail
    # Releasing is opt-in, by carrying a goreleaser config (project-owned, like
    # the root Justfile — limen neither pins nor seeds it). Checked before
    # anything else: past this point the recipe creates tags and pushes.
    if [ ! -f .goreleaser.yaml ] && [ ! -f .goreleaser.yml ]; then
        echo "this project has no .goreleaser.yaml — goreleaser releases are opt-in (see book/recipes.md)." >&2
        exit 1
    fi
    usage() {
        echo "usage: just do release <tag>                                               # signed tag + push; CI builds, signs (keyless), publishes" >&2
        echo "       just do release --local <cosign-key> <tag> [--cosign-password <p>]  # fully local, key-based cosign" >&2
        echo "       just do release --local --dry-run                                   # local unsigned snapshot into build/release/" >&2
        echo "       just do release --ci                                                # workflow half of the default lane (GitHub Actions only)" >&2
    }
    require_clean() {
        # A dirty tree is the most common failure and goreleaser hard-refuses
        # it — check long before anything is created or pushed.
        if [ -n "$(git status --porcelain)" ]; then
            echo "the working tree is dirty — commit or stash before releasing:" >&2
            git status --short >&2
            exit 1
        fi
    }
    require_version_tag() {
        if ! printf '%s' "$1" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$'; then
            echo "'$1' is not a version tag (vX.Y.Z or vX.Y.Z-prerelease, e.g. v0.0.0-test.1)." >&2
            exit 2
        fi
    }
    tag_and_push() {
        # Create the signed tag — unless it already exists pointing at HEAD, so
        # a retry after a failed publish resumes instead of failing here.
        if existing=$(git rev-parse -q --verify "refs/tags/$1^{commit}"); then
            if [ "$existing" != "$(git rev-parse HEAD)" ]; then
                echo "tag $1 already exists and does not point at HEAD — refusing." >&2
                exit 1
            fi
            echo "tag $1 already on HEAD — reusing it."
        else
            git tag -s "$1" -m "$1"
        fi
        git push origin HEAD
        git push origin "refs/tags/$1"
    }
    set -- {{ args }}
    case "${1:-}" in
        --local)
            shift
            if [ "${1:-}" = "--dry-run" ]; then
                # Snapshot builds skip signing: no key material needed.
                exec goreleaser release --snapshot --clean --skip=sign
            fi
            key="${1:-}"
            if [ -z "$key" ]; then
                usage
                exit 2
            fi
            shift
            tag=""
            password=""
            while [ $# -gt 0 ]; do
                case "$1" in
                    --cosign-password)
                        if [ $# -lt 2 ]; then
                            echo "--cosign-password needs a value." >&2
                            exit 2
                        fi
                        password="$2"
                        shift 2
                        ;;
                    -*)
                        echo "unknown option: $1" >&2
                        usage
                        exit 2
                        ;;
                    *)
                        if [ -n "$tag" ]; then
                            echo "unexpected argument: $1 (tag already given: $tag)" >&2
                            usage
                            exit 2
                        fi
                        tag="$1"
                        shift
                        ;;
                esac
            done
            if [ -z "$tag" ]; then
                usage
                exit 2
            fi
            if [ ! -f "$key" ]; then
                echo "cosign key not found: $key" >&2
                echo "generate a key pair once with 'cosign generate-key-pair'; commit cosign.pub, keep the private key out of the tree." >&2
                exit 1
            fi
            require_version_tag "$tag"
            require_clean
            if [ -z "${GITHUB_TOKEN:-}" ]; then
                echo "GITHUB_TOKEN is not set — goreleaser needs it to publish the GitHub release." >&2
                exit 1
            fi
            if [ -z "$password" ]; then
                # cosign under goreleaser cannot prompt (no tty on its stdin):
                # collect the passphrase up front. Empty is legal — it means an
                # unencrypted key.
                printf 'cosign key password (empty for an unencrypted key): ' >&2
                read -rs password
                echo >&2
            fi
            export COSIGN_KEY="$key"
            export COSIGN_PASSWORD="$password"
            tag_and_push "$tag"
            exec goreleaser release --clean
            ;;
        --ci)
            # The workflow half: the tag exists (its push triggered this run,
            # and CI checks out exactly that commit), publishing uses the
            # workflow's GITHUB_TOKEN, and signing is keyless — the OIDC
            # identity replaces any key.
            if [ -z "${GITHUB_ACTIONS:-}" ]; then
                echo "--ci is the workflow half — locally, 'just do release <tag>' cuts the tag CI releases." >&2
                exit 1
            fi
            if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
                echo "no OIDC token available — the workflow needs 'id-token: write' for keyless signing." >&2
                exit 1
            fi
            if [ -z "${GITHUB_TOKEN:-}" ]; then
                echo "GITHUB_TOKEN is not set — pass the workflow token to this step's env." >&2
                exit 1
            fi
            if ! git describe --exact-match --tags HEAD >/dev/null 2>&1; then
                echo "HEAD carries no tag — this lane only runs on a tag push." >&2
                exit 1
            fi
            # Keyless is enforced, not defaulted: a key leaking into the CI
            # environment must not silently flip the signing mode.
            unset COSIGN_KEY
            exec goreleaser release --clean
            ;;
        --dry-run)
            echo "dry runs are a local concern: use 'just do release --local --dry-run'." >&2
            exit 2
            ;;
        "")
            usage
            exit 2
            ;;
        -*)
            echo "unknown option: $1" >&2
            usage
            exit 2
            ;;
        *)
            # The default lane: cut the signed tag and push — the release
            # workflow takes it from here.
            tag="$1"
            shift
            if [ $# -gt 0 ]; then
                echo "unexpected argument: $1" >&2
                usage
                exit 2
            fi
            require_version_tag "$tag"
            require_clean
            tag_and_push "$tag"
            echo "tag $tag pushed — the release workflow builds, signs, and publishes from here."
            ;;
    esac
