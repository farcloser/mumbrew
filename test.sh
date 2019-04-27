#!/usr/bin/env bash

shellcheck -a -x "./test.sh"
shellcheck -a -x "./mumbrew"

# travis is very outdated and this takes forever
# ./mumbrew
