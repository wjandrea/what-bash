#!/bin/bash

source indenter.sh || exit 1  # Get function "indenter"

basename=$(basename -- "$0")  # For error messages
exit=0

for path; do
    problem=
    if ! [[ -e $path ]]; then
        problem='No such file'
    elif ! [[ -L $path ]]; then
        problem='Not a symlink'
    fi

    if [[ $problem ]]; then
        printf >&2 '%s: %s: %s\n' "$basename" "$problem" "$path"
        exit=1
        continue
    fi

    printf '%s\n' "$path"
    # While loop accounts for multi-level symlinks
    while [[ -L $path ]]; do
        link_deref="$(readlink -- "$path")"

        # Print the dereferenced file info.
        indenter 1
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
        indenter 1
        printf 'canonical path: %s\n' "$path_canonical"
    fi
done

exit $exit
