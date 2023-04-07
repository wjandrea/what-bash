#!/bin/bash
# Indent each line from stdin using "indenter_many".
# Can also be sourced to provide "indenter", the base function.

function indenter {
    # Indent by the given number of indent levels.

    local end="${1-1}"
    local i
    local indent_string="${2-    }"

    for ((i=1; i<="$end"; i++)); do
        printf '%s' "$indent_string"
    done
}

function indenter_many {
    # Indent each line from stdin.
    # Wraps "indenter".

    local line

    while IFS= read -r line; do
        indenter "$@"
        printf '%s\n' "$line"
    done
}

# End sourced section
return 2>/dev/null

# shellcheck disable=SC2317  # Not unreachable if run as script
indenter_many "$@"
