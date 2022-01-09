#!/bin/bash
# Resolve a symlink, recursively and canonically.
#
# See functions _symlink_info_usage and _symlink_info_help for more details.

function _symlink_info_help {
    _symlink_info_usage
    echo
    cat <<'EOF'
Resolve a symlink, recursively and canonically.

Arguments:
    FILE    Filename of symlink to resolve.

Options:
    -h      Print this help message and exit.

Info provided per symlink:
    - target, recursively
    - (if relative: canonical path)

Exit Status:
    4 - Missing dependency ("indenter")
    3 - Invalid options
    1 - At least one FILE is not found, or any other error
    0 - otherwise
EOF
}

function _symlink_info_usage {
    printf 'Usage: %s [-h] [file ...]\n' "$basename"
}

function symlink_info { (
    # See _symlink_info_help and _symlink_info_usage.

    # Defaults
    exit=0

    # Basename of caller, for error messages and help
    basename=$(basename -- "$0")
    # Name of the main function, for error messages.
    funcname="${FUNCNAME[0]}"

    # Check dependencies
    # Files to source from if needed
    declare -A imports=(  # Format: [command_name]=filename_in_bundle
        [indenter]=indenter.sh
    )
    here=${BASH_SOURCE[0]%/*}  # Script location - may be relative
    # shellcheck disable=2043  # Loop runs only once by design
    for dependency in indenter; do
        # Check if command exists
        if ! type -- "$dependency" &> /dev/null; then
            # Try sourcing
            source_filename=${imports[$dependency]}
            source_path="$here/$source_filename"
            # shellcheck source=./indenter.sh
            if ! source "$source_path"; then
                printf >&2 '%s: %s: Missing dependency: %s\n' \
                    "$basename" \
                    "$funcname" \
                    "$dependency"
                printf >&2 '%s: %s: Tried sourcing but failed: %s\n' \
                    "$basename" \
                    "$funcname" \
                    "$source_path"
                exit 4
            fi
        fi
    done

    OPTIND=1
    while getopts :h OPT; do
        case $OPT in
        h)
            _symlink_info_help
            exit 0
            ;;
        *)
            printf >&2 '%s: %s: Invalid option: -%s\n' \
                "$basename" \
                "$funcname" \
                "$OPTARG"
            _symlink_info_usage >&2
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
) }

# End sourced section
return 2>/dev/null

symlink_info "$@"
