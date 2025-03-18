#!/bin/bash
# Resolve a symlink, recursively and canonically.
#
# See functions "_usage" and "_help" for more details.

## COLOR
GREEN="\033[0;32m"
NORMAL="\033[0;00m"

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
    - (if broken: warning)

Exit Status:
    3 - Invalid options
    1 - At least one FILE is not found, or any other error
    0 - otherwise
EOF
}

function _usage {
    cat <<'EOF'
Usage: symlink-info [-hv] [file ...]
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

# Static
version='0.3.2'

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
        echo "symlink-info $version"
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
    if ! [[ -L $path ]]; then
        if ! [[ -e $path ]]; then
            problem='No such file'
        else
            problem='Not a symlink'
        fi
    fi

    if [[ $problem ]]; then
        printf >&2 '%s: %s: %s\n' "$basename" "$problem" "$path"
        exit=1
        continue
    fi

    printf '%s\n' "$path"
    # While loop accounts for multi-level symlinks
    while [[ -L $path ]]; do
        target="$(readlink -- "$path")"

        _indent 1
        printf "${GREEN}symlink${NORMAL}: %s\n" "$target"

        if [[ $target == /* ]]; then
            # Target is absolute.
            path="$target"
        else
            # Target is relative, so join with path dirname.
            path="$(dirname -- "$path")/$target"
        fi
    done

    # Canonical path
    path_canonical="$(readlink -m -- "$path")"
    if [[ $path_canonical != "$target" ]]; then
        _indent 1
        printf "${GREEN}canonical path${NORMAL}: %s\n" "$path_canonical"
    fi

    if [[ ! -e $path_canonical ]]; then
        printf >&2 "%s: Warning: Broken symlink. Target does not exist: %s\n" \
            "$basename" \
            "$path_canonical"
        exit=1
    fi
done

exit $exit
