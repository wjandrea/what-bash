#!/bin/bash
# Resolve a symlink, recursively and canonically.

function symlink_info { (
    source indenter.sh || exit 1  # Get function "indenter"

    # Basename of caller, for error messages
    basename=$(basename -- "$0")
    # Name of the main function, for error messages.
    funcname="${FUNCNAME[0]}"
    exit=0

    for path; do
        problem=
        if ! [[ -e $path ]]; then
            problem='No such file'
        elif ! [[ -L $path ]]; then
            problem='Not a symlink'
        fi

        if [[ $problem ]]; then
            printf >&2 '%s: %s: %s: %s\n' "$basename" "$funcname" "$problem" "$path"
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
); }

# End sourced section
return 2>/dev/null

symlink_info "$@"
