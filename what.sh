#!/bin/bash
# Get info about a given command, like a more thorough 'type'.
#
# See functions _what_usage and _what_help for more details.

_what_alias()(
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
        while read -r match; do
            _what_alias_match_parse "$match"
        done <<< "$matches"
    else
        _what_alias_match_parse
    fi

    if [[ $print_definition == true ]]; then
        # Print the *current* definition.
        _what_indent 2
        printf "definition: "
        alias -- "$alias"
    fi
)

_what_alias_match_parse(){
    local match="$1"
    local filename
    local line_num

    if [[ -z $match ]]; then
        _what_indent 2
        printf 'possible source: %s\n' '(not found)'
        return
    fi

    IFS=: read -r filename line_num line <<< "$match"

    _what_indent 2
    printf 'possible source: %s:%s\n' "$filename" "$line_num"

    if [[ $print_definition == true ]]; then
        # Print the definition *from the file*.
        _what_indent 3
        printf "definition: "
        sed 's/^ *//; s/ *$//' <<< "$line"  # Strip surrounding whitespace
    fi
}

_what_command()(
    # Get info about a single command.
    #
    # Runs in a subshell to make it easier to avoid polluting the
    # surrounding scope.

    command="$1"
    exit=0

    _what_executable_bug "$command" || return 1

    # Check command's status.
    if type -ta -- "$command" &> /dev/null; then
        # Command is available
        true
    elif hash -t -- "$command" &>/dev/null; then
        # Command is not availble, but is hashed.
        true
    elif [[ $more_info_command_not_found == true ]]; then
        /usr/lib/command-not-found "$command"
        return 1
    else
        # Command not found.
        printf >&2 '%s: %s: %s: Not found\n' "$basename" "$funcname" "$command"
        return 1
    fi

    printf '%s\n' "$command"

    _what_hashed "$command"

    # Iterate over multiple types/instances of the command.
    for type in $(type -at -- "$command"); do
        _what_indent 1
        printf '%s\n' "$type"

        if [[ $print_type_only == true ]]; then
            continue
        fi

        # Print command info.
        case $type in
        alias)
            _what_alias "$command" ||
                exit=1
            ;;
        builtin)
            ;;
        file)
            # Iterate over each file using bash math.
            _what_file "$command" "$((file_count++))" ||
                exit=1
            ;;
        function)
            _what_function "$command" ||
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

    return $exit
)

_what_executable_bug(){
    # Give an error about the bug described in "_what_help".

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

_what_file()(
    # Get info about a command which is a file.

    command="$1"
    path_number="${2:-1}"  # Default to 1

    # Get command paths
    readarray -t paths <<< "$(type -pa -- "$command")"

    _what_filepath "${paths[$path_number]}"
)

_what_filepath()(
    # Get info about an executable path.

    path="$1"

    _what_indent 2
    printf 'path: %s\n' "$path"

    # If the file is a symlink.
    if [[ -L $path ]]; then
        while IFS= read -r line; do
            _what_indent 2
            printf '%s\n' "$line"
        done <<< "$(symlink-info "$path" | tail +2)"
    fi

    # Show brief file info.
    _what_indent 2
    printf 'file type: '
    file -bL -- "$path" |
        cut -d, -f1
)

_what_function()(
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
    _what_indent 2
    printf 'source: %s:%s\n' "$filename" "$line_num"

    # Print export status.
    _what_indent 2
    printf 'export: '
    if [[ $attrs == *x* ]]; then
        echo yes
    else
        echo no
    fi

    if [[ $print_definition == true ]]; then
        # Print the function definition.
        _what_indent 2
        printf 'definition:\n'
        while IFS= read -r line; do
            _what_indent 3
            printf '%s\n' "$line"
        done <<< "$(declare -f -- "$function")"
    fi
)

_what_hashed(){
    local command
    local hashpath

    command="$1"

    if hashpath="$(hash -t -- "$command" 2>/dev/null)"; then
        _what_indent 1
        printf 'hashed\n'

        if [[ $print_type_only == true ]]; then
            return
        fi

        _what_indent 2
        printf 'path: %s\n' "$hashpath"

        if ! [[ -f $hashpath ]]; then
            printf >&2 '%s: %s: %s: Hashed file does not exist: %s\n' \
                "$basename" \
                "$funcname" \
                "$command" \
                "$hashpath"
            exit=1
        fi
    fi
}

_what_help(){
    _what_usage
    echo
    cat <<'EOF'
Give information about Bash command names, like a more thorough "type".

Arguments:
    NAME    Command name to give information about.
            If none are given, input is taken from stdin.

Options:
    -d      Print definitions for aliases and functions.
    -h      Print this help message and exit.
    -n      Provide more info if a command is not found.
            Uses "/usr/lib/command-not-found" (available on Debian/Ubuntu)
    -t      Print only types, similar to "type -at".

Info provided per type (types ordered by precedence):
    alias
        - possible source file and line number
            - (with option "-d": definition in file)
        - (with option "-d": current definition)
    keyword
    function
        - source file and line number
        - marked for export (yes/no)
        - (with option "-d": definition)
    builtin
    hashed file (though not a type per se)
        - path
        - (if hashed file does not exist: warning)
    file
        - path
            - (if symlink: target, recursively)
            - (if relative symlink: canonical path)
        - file type

Always iterates over multiple types/instances, e.g:
    - echo: builtin and file
    - zsh: two files on Debian

Exit Status:
    3 - Invalid options
    1 - At least one NAME is not found, or any other error
    0 - otherwise

For example:
    "what if type ls what zsh sh /"
    - Covers keyword, builtin, alias/file, function, multiple files/absolute symlinks, relative symlink (on Debian/Ubuntu), and non-command.

Known issues:
    - Some versions of Bash have different output between "type COMMAND" and "type -a COMMAND" if COMMAND is a file but is not executable. "what" will error if affected.
EOF
}

_what_indent(){
    # Indent by given number of indent levels.
    local indent_string='    '
    local end="$1"
    for ((i=1; i<="$end"; i++)); do
        printf '%s' "$indent_string"
    done
}

_what_usage(){
    printf 'Usage: what [-h] [-dnt] [name ...]\n'
}

what()(
    # See _what_help and _what_usage.

    unset IFS  # Just in case

    exit=0

    # Basename of caller, for error messages
    basename=$(basename -- "$0")
    # Name of the main function, for error messages.
    funcname="${FUNCNAME[0]}"

    OPTIND=1
    while getopts :dhnt OPT; do
        case $OPT in
        d)
            print_definition=true
            ;;
        h)
            _what_help
            exit 0
            ;;
        n)
            if ! [[ -f /usr/lib/command-not-found ]]; then
                printf >&2 '%s: %s: Missing required program for "-n": %s\n' \
                    "$basename" \
                    "$funcname" \
                    "/usr/lib/command-not-found"
                exit 3
            fi
            more_info_command_not_found=true
            ;;
        t)
            print_type_only=true
            ;;
        *)
            printf >&2 '%s: %s: Invalid option: -%s\n' \
                "$basename" \
                "$funcname" \
                "$OPTARG"
            _what_usage >&2
            exit 3
            ;;
        esac
    done
    shift "$((OPTIND-1))"

    if [[ $# -eq 0 ]]; then
        # Read command names from stdin
        while read -r line; do
            [[ -z $line ]] && continue  # Skip blank lines

            _what_command "$line" ||
                exit=1
        done
    else
        for arg; do
            _what_command "$arg" ||
                exit=1
        done
    fi

    return $exit
)

# Enable command name completion
complete -c what

# End sourced section
return 2>/dev/null

printf >&2 \
    '%s: Warning: This script is intended to be sourced from Bash, to provide the function "what".\n' \
    "$(basename -- "$0")"
what "$@"
