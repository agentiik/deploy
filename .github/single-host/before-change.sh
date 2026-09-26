# shellcheck shell=bash
# Sourced by the README's script before "Change a setting": the operator token in use until then,
# which after-change.sh checks the API refuses once the new one in .env has taken effect.
# shellcheck disable=SC2034 # read by after-change.sh, in the same shell
previous_token=$AGENTIIK_TOKEN
