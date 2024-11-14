#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail
# ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★
# (c) 2024 Farcloser <apostasie@farcloser.world>
# Distributed under the terms of the MIT license
# ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ ★

# shellcheck disable=SC2034
readonly LOG_COLOR_BLACK=0
readonly LOG_COLOR_RED=1
readonly LOG_COLOR_GREEN=2
readonly LOG_COLOR_YELLOW=3
# shellcheck disable=SC2034
readonly LOG_COLOR_BLUE=4
# shellcheck disable=SC2034
readonly LOG_COLOR_MAGENTA=5
# shellcheck disable=SC2034
readonly LOG_COLOR_CYAN=6
readonly LOG_COLOR_WHITE=7
# shellcheck disable=SC2034
readonly LOG_COLOR_DEFAULT=9

# shellcheck disable=SC2034
readonly LOG_STYLE_DEBUG=( setaf "$LOG_COLOR_WHITE" )
# shellcheck disable=SC2034
readonly LOG_STYLE_INFO=( setaf "$LOG_COLOR_GREEN" )
# shellcheck disable=SC2034
readonly LOG_STYLE_WARNING=( setaf "$LOG_COLOR_YELLOW" )
# shellcheck disable=SC2034
readonly LOG_STYLE_ERROR=( setaf "$LOG_COLOR_RED" )

readonly LOG_LEVEL_DEBUG=0
# shellcheck disable=SC2034
readonly LOG_LEVEL_INFO=1
# shellcheck disable=SC2034
readonly LOG_LEVEL_WARNING=2
# shellcheck disable=SC2034
readonly LOG_LEVEL_ERROR=3
export _PRIVATE_LOG_LEVEL=2

_log::log(){
  local level
  local style
  local numeric_level
  local message="$2"

  level="$(printf "%s" "$1" | tr '[:lower:]' '[:upper:]')"
  numeric_level="$(printf "LOG_LEVEL_%s" "$level")"
  style="LOG_STYLE_${level}[@]"

  [ "${!numeric_level}" -ge "$_PRIVATE_LOG_LEVEL" ] || return 0

  [ ! "$TERM" ] || [ ! -t 2 ] || >&2 tput "${!style:-}" 2>/dev/null || true
  >&2 printf "[%s] %s: %s\n" "$(date 2>/dev/null || true)" "$(printf "%s" "$level" | tr '[:lower:]' '[:upper:]')" "$message"
  [ ! "$TERM" ] || [ ! -t 2 ] || >&2 tput op 2>/dev/null || true
}

log::init(){
  local _ll
  _ll="$(printf "LOG_LEVEL_%s" "${LOG_LEVEL:-warning}" | tr '[:lower:]' '[:upper:]')"
  _PRIVATE_LOG_LEVEL="${!_ll:-1}"
  [ "$_PRIVATE_LOG_LEVEL" != "$LOG_LEVEL_DEBUG" ] || {
    log::warning "Your log level is set to 'debug'. This is NOT recommended for production use, and MAY leak sensitive information to stderr."
  }
}

log::debug(){
  _log::log debug "$@"
}

log::info(){
  _log::log info "$@"
}

log::warning(){
  _log::log warning "$@"
}

log::error(){
  _log::log error "$@"
}

log::init
