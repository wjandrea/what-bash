#!/bin/bash
# Resolve a symlink, recursively and canonically.
#
# See functions "_usage" and "_help" for more details.

function _help {
    _usage
    echo
    cat <<'EOF'
Resolve a symlink, recursively and canonically.

Arguments:
    FILE    Filename of symlink to resolve.

Options:
    -h      Print this help message and exit.
    -v      Print the version and exit.

Info provided per symlink:
    - target, recursively
    - (if relative: canonical path)

Exit Status:
    3 - Invalid options
    1 - At least one FILE is not found, or any other error
    0 - otherwise
EOF
}

function _usage {
    cat <<'EOF'
Usage: symlink-info [-h] [file ...]
EOF
}

function _indent {
    # Indent by the given number of indent levels.

    local end="${1-1}"
    local i
    local indent_string="${2-    }"

    for ((i=1; i<="$end"; i++)); do
        printf '%s' "$indent_string"
    done
}

basename=$(basename -- "$0")  # For error messages and help

# Defaults
exit=0

OPTIND=1
while getopts :hv OPT; do
    case $OPT in
    h)
        _help
        exit 0
        ;;
    v)
        echo "symlink-info 0.2.0"
        exit 0
        ;;
    *)
        printf >&2 '%s: Invalid option: -%s\n' \
            "$basename" \
            "$OPTARG"
        _usage >&2
        exit 3
        ;;
    esac
done
shift "$((OPTIND-1))"

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
