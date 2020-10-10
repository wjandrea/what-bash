#!/bin/bash

_indent(){
    # Indent by given number of indent levels.
    local indent_string='    '
    local end="$1"
    for ((i=1; i<="$end"; i++)); do
        printf '%s' "$indent_string"
    done
}

exit=0

for path; do
    if ! [[ -L $path ]]; then
        printf >&2 '%s: Not a symlink: %s\n' "$0" "$path"
        exit=1
        continue
    fi

    printf '%s\n' "$path"
    # While loop accounts for multi-level symlinks
    while [[ -L $path ]]; do
        link_deref="$(readlink -- "$path")"

        # Print the dereferenced file info.
        _indent 1
        printf 'symlink: %s\n' "$link_deref"

        # If deref'd path starts with a slash.
        if [[ "$link_deref" == /* ]]; then
            # Link is absolute.
            path="$link_deref"
        else
            # Link is relative, so get absolute path.
            path="${path%/*}/$link_deref"
        fi
    done

    # Canonical path
    path_canonical="$(readlink -m -- "$path")"
    if [[ $path_canonical != "$link_deref" ]]; then
        _indent 1
        printf 'canonical path: %s\n' "$path_canonical"
    fi
done

exit $exit
