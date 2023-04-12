#!/bin/bash
# Get info about a given command, like a more thorough 'type'.
#
# For more details, see functions _What_usage and _What_help
# as well as _What_info.

function _What_alias { (
    # Get info about an alias.

    alias="$1"

    # Files that normally contain aliases.
    bash_files=(
        /etc/profile
        /etc/bash.bashrc
        ~/.profile
        ~/.bash_profile
        ~/.bash_login
        ~/.bashrc
        ~/.bash_aliases
        ~/.bash_functions
        )

    # Check if the alias exists in the Bash files.
    alias_regex="alias +(-- +)?$alias="
    matches="$(grep -snEH "$alias_regex" "${bash_files[@]}")"

    # Print matches.
    # "while" loop accounts for multiple.
    if [[ $matches ]]; then
        printf '%s\n' "$matches" | while read -r match; do
            _What_alias_match_parse "$match"
        done
    else
        _What_alias_match_parse ''
    fi

    if [[ $print_definition == true ]]; then
        # Print the *current* definition.
        _What_indent 2
        printf "definition: "
        alias -- "$alias"
    fi
) }

function _What_alias_match_parse {
    local match="$1"
    local filename
    local line_num
    local line

    if [[ -z $match ]]; then
        _What_indent 2
        printf 'possible source: %s\n' '(not found)'
        return
    fi

    IFS=: read -r filename line_num line <<< "$match"

    _What_indent 2
    printf 'possible source: %s:%s\n' "$filename" "$line_num"

    if [[ $print_definition == true ]]; then
        # Print the definition *from the file*.
        _What_indent 3
        printf "definition: "
        sed 's/^ *//; s/ *$//' <<< "$line"  # Strip surrounding whitespace
    fi
}

function _What_command { (
    # Get info about a single command.
    #
    # Runs in a subshell to make it easier to avoid polluting the
    # surrounding scope.

    command="$1"
    exit=0
    # For printing hash in the right place
    hash_encountered=false

    _What_executable_bug "$command" || return 1

    # Check command's status.
    if type -ta -- "$command" &> /dev/null; then
        # Command is available
        true
    elif hash -t -- "$command" &>/dev/null; then
        # Command is not availble, but is hashed.
        true
    elif [[ $more_info_command_not_found == true ]]; then
        "$command_not_found_handler" "$command"
        return 1
    else
        # Command not found.
        printf >&2 '%s: %s: Not found: %s\n' "$basename" "$funcname" "$command"
        return 1
    fi

    printf '%s\n' "$command"

    # Iterate over multiple types/instances of the command.
    for type in $(type -at -- "$command"); do
        if [[ $type == file && $hash_encountered == false ]]; then
            _What_hashed "$command"
            hash_encountered=true
        fi

        _What_indent 1
        printf '%s\n' "$type"

        if [[ $print_type_only == true ]]; then
            continue
        fi

        # Print command info.
        case $type in
        alias)
            _What_alias "$command" ||
                exit=1
            ;;
        builtin)
            ;;
        file)
            # Iterate over each file using bash math.
            _What_file "$command" "$((file_count++))" ||
                exit=1
            ;;
        function)
            _What_function "$command" ||
                exit=1
            ;;
        keyword)
            ;;
        *)
            # This should never happen.
            printf >&2 '%s: %s: %s: Invalid type: %s\n' \
                "$basename" \
                "$funcname" \
                "$command" \
                "$type"
            exit=1
            ;;
        esac
    done

    if [[ $hash_encountered == false ]]; then
        _What_hashed "$command"
    fi

    return $exit
) }

function _What_executable_bug {
    # Give an error about the issue described in "_What_info".

    local command
    local path
    local problem
    local type

    command="$1"

    path="$(type -P -- "$command")"
    type="$(type -t -- "$command")"

    if [[ $type == "file" ]]; then
        if [[ -d $path ]]; then
            problem="Is a directory"
        elif [[ ! -f $path ]]; then
            problem="File does not exist"
        elif [[ ! -x $path ]]; then
            problem="File is not executable"
        fi

        if [[ $problem ]]; then
            printf >&2 '%s: %s: %s: %s: %s\n' \
                "$basename" \
                "$funcname" \
                "$command" \
                "$problem" \
                "$path"
            exit=1
            return 1
        fi
    fi
}

function _What_file { (
    # Get info about a command which is a file.

    command="$1"
    path_number="${2:-1}"  # Default to 1

    # Get command paths
    readarray -t paths <<< "$(type -pa -- "$command")"

    _What_filepath "${paths[$path_number]}"
) }

function _What_filepath { (
    # Get info about an executable path.

    path="$1"

    _What_indent 2
    printf 'path: %s\n' "$path"

    # If the file is a symlink.
    if [[ -L $path ]]; then
        symlink-info "$path" |
            tail -n +2 |
            _What_indent_many 2  # symlink-info already adds 1 indentation
    fi

    # Show brief file info.
    _What_indent 2
    printf 'file type: '
    file -bL -- "$path" |
        cut -d, -f1
) }

function _What_function { (
    # Get info about a function.

    function="$1"

    read -r _ attrs _ <<< "$(declare -pF -- "$function")"

    # Find the source by turning on extended debugging.
    # Looping not required because only one definition exists at a time.
    read -r _ line_num filename <<< "$(
        shopt -s extdebug
        declare -F -- "$function"
        )"

    # Print.
    _What_indent 2
    printf 'source: %s:%s\n' "$filename" "$line_num"

    # Print export status.
    _What_indent 2
    printf 'export: '
    if [[ $attrs == *x* ]]; then
        echo yes
    else
        echo no
    fi

    if [[ $print_definition == true ]]; then
        # Print the function definition.
        _What_indent 2
        printf 'definition:\n'
        declare -f -- "$function" |
            _What_indent_many 3
    fi
) }

function _What_hashed {
    local command
    local hashpath

    command="$1"

    if ! hashpath="$(hash -t -- "$command" 2>/dev/null)"; then
        return
    fi

    _What_indent 1
    printf 'hashed\n'

    if ! [[ -f $hashpath ]]; then
        printf >&2 '%s: %s: %s: Hashed file does not exist: %s\n' \
            "$basename" \
            "$funcname" \
            "$command" \
            "$hashpath"
        exit=1
    fi

    if [[ $print_type_only == true ]]; then
        return
    fi

    _What_indent 2
    printf 'path: %s\n' "$hashpath"
}

function _What_help {
    _What_usage
    echo
    cat <<'EOF'
Give information about Bash command names, like a more thorough "type".

Arguments:
    NAME    Command name to give information about.
            If none are given, input is taken from stdin.

Options:
    -d      Print definitions for aliases and functions.
    -h      Print this help message and exit.
    -i      Print the info message and exit.
    -n      Provide more info if a command is not found.
            Uses "/usr/lib/command-not-found" (available on Debian/Ubuntu)
    -t      Print only types, similar to "type -at".
    -v      Print the version and exit.

Exit Status:
    4 - Missing dependency ("symlink-info" or optionally the "-n" handler)
    3 - Invalid options
    1 - At least one NAME is not found, or any other error
    0 - otherwise
EOF
}

function _What_info {
    cat <<'EOF'
Info provided per type (types ordered by precedence):
    alias
        - possible source file(s) and line number(s)
            - (with option "-d": definition in file)
        - (with option "-d": current definition)
    keyword
    function
        - source file and line number
        - marked for export (yes/no)
        - (with option "-d": definition)
    builtin
    hashed file (though not a type per se)
        - (if hashed file does not exist: warning)
        - path
    file(s)
        - path
            - (if symlink: details from "symlink-info")
        - file type

Always iterates over multiple types/instances, e.g:
    - echo: builtin and file
    - zsh: two files on Debian

For example:
    "what if type ls what zsh sh /"
    - Covers keyword, builtin, alias/file, function, multiple
      files/absolute symlinks, relative symlink (on Debian/Ubuntu),
      and non-command.

Known issues:
    - Bash may have different output between "type COMMAND" and
      "type -a COMMAND" if COMMAND is a file but is not executable.
      That includes:
        - If the user doesn't have execute permissions to the file
        - If the file is a directory
        - If the file does not exist, as a hashed path
      Some of this behaviour depends on the version of Bash.

      Since "what" relies on the output of "type" to make sense of the
      environment, it will print an error or warning if affected.
EOF
}

function _What_indent {
    # Indent by the given number of indent levels.

    local end="${1-1}"
    local i
    local indent_string="${2-    }"

    for ((i=1; i<="$end"; i++)); do
        printf '%s' "$indent_string"
    done
}

function _What_indent_many {
    # Indent each line from stdin.
    # Wraps "_What_indent".

    local line

    while IFS= read -r line; do
        _What_indent "$@"
        printf '%s\n' "$line"
    done
}

function _What_usage {
    cat <<'EOF'
Usage: what [-hi] [-dnt] [name ...]
EOF
}

function what { (
    # For details, see _What_help and _What_usage, as well as _What_info.

    unset IFS  # Just in case

    # Defaults
    exit=0

    # Basename of caller, for error messages
    basename=$(basename -- "$0")
    # Name of the main function, for error messages.
    funcname="${FUNCNAME[0]}"

    command_not_found_handler=/usr/lib/command-not-found

    # Check dependencies
    # shellcheck disable=SC2043  # Loop only runs once for one dependency
    for dependency in symlink-info; do
        # Check if command exists
        if ! type -- "$dependency" &> /dev/null; then
            printf >&2 '%s: %s: Missing dependency: %s\n' \
                "$basename" \
                "$funcname" \
                "$dependency"
            exit 4
        fi
    done

    OPTIND=1
    while getopts :dhintv OPT; do
        case $OPT in
        d)
            print_definition=true
            ;;
        h)
            _What_help
            exit 0
            ;;
        i)
            _What_info
            exit 0
            ;;
        n)
            if ! [[ -f $command_not_found_handler ]]; then
                printf >&2 '%s: %s: Missing required program for "%s": %s\n' \
                    "$basename" \
                    "$funcname" \
                    "-$OPT" \
                    "$command_not_found_handler"
                exit 4
            fi
            more_info_command_not_found=true
            ;;
        t)
            print_type_only=true
            ;;
        v)
            echo "what 0.2.0"
            exit 0
            ;;
        *)
            printf >&2 '%s: %s: Invalid option: %s\n' \
                "$basename" \
                "$funcname" \
                "-$OPTARG"
            _What_usage >&2
            exit 3
            ;;
        esac
    done
    shift "$((OPTIND-1))"

    if [[ $# -eq 0 ]]; then
        # Read command names from stdin
        while read -r line; do
            [[ -z $line ]] && continue  # Skip blank lines

            _What_command "$line" ||
                exit=1
        done
    else
        for arg; do
            _What_command "$arg" ||
                exit=1
        done
    fi

    return $exit
) }

# End sourced section
return 2>/dev/null

# shellcheck disable=SC2317  # Not unreachable if run as script
{
    printf >&2 \
        '%s: Warning: This script is intended to be sourced from Bash, to provide the function "what".\n' \
        "$(basename -- "$0")"
    what "$@"
}
