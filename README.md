# what-bash

`what` is a Bash function that gets info about a command, like what exactly it is and where. It can help with understanding a command's behaviour and troubleshooting issues. For example, if you run an executable, delete it, then try running it again, Bash may try to run the file that you just deleted (due to pathname hashing), leading to a confusing error message. `what` will tell you about that problem.

Along with it is `symlink-info`, which details complicated symlinks. `what` uses it on symlinked executable files.

## `what`

### Usage

Source `what.sh` to get the function `what`. Then run `what` with the names of commands.

`what.sh` can also be run directly, but it's not recommended since it won't have access to the active shell environment, e.g. aliases.

### Examples

(I ran these on my computer running Ubuntu 18.04.)

#### Basic usage

Show basic info about a variety of commands:

```none
$ what if type find what
if
    keyword
type
    builtin
find
    file
        path: /usr/bin/find
        file type: ELF 64-bit LSB shared object
what
    function
        source: /home/wja/.local/lib/bash/what.sh:348
        export: no
$ what awk sh ls  # A bit more complex
awk
    file
        path: /usr/bin/awk
            symlink: /etc/alternatives/awk
            symlink: /usr/bin/mawk
        file type: ELF 64-bit LSB shared object
sh
    file
        path: /bin/sh
            symlink: dash
            canonical path: /bin/dash
        file type: ELF 64-bit LSB shared object
ls
    alias
        possible source: /home/wja/.bash_aliases
    file
        path: /bin/ls
        file type: ELF 64-bit LSB shared object
```

### Show definitions of aliases and functions

```none
$ function foo { bar; }
$ what -d foo ll
foo
    function
        source: main:2
        export: no
        definition:
            foo ()
            {
                bar
            }
ll
    alias
        possible source: /home/wja/.bash_aliases:25
            definition: alias ll='ls -alF'  # all, long, classified
        definition: alias ll='ls -alF'
```

Note that the source of a function can be traced, but not an alias. `what` basically guesses at alias sources. Specifically, it tries to find the source in the most common files, using a regex.

```none
$ alias ll='do_something_else'
$ what -d ll
ll
    alias
        possible source: /home/wja/.bash_aliases:25
            definition: alias ll='ls -alF'  # all, long, classified
        definition: alias ll='do_something_else'
```

#### Show a problem with a hashed path

```none
$ hash -p /nonexistent FAKE_COMMAND  # Create a bad hash
$ what FAKE_COMMAND
bash: what: FAKE_COMMAND: File does not exist: /nonexistent
```

### Help

```none
$ what -h
Usage: what [-h] [-dnt] [name ...]

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
```

## `symlink-info`

Resolve a symlink, recursively and canonically

### Example

Borrowing from the above `what` example:

```none
$ symlink-info /usr/bin/awk /bin/sh
/usr/bin/awk
    symlink: /etc/alternatives/awk
    symlink: /usr/bin/mawk
/bin/sh
    symlink: dash
    canonical path: /bin/dash
```

## Installation

`what` requires `symlink-info.sh` in the `$PATH` as `symlink-info`.

Everything else is your choice. For example you might want to put `what.sh` in your `$PATH`, then `source what.sh` on shell startup, so that you always have `what` available.

If you want command name completions, run `complete -c what`.

### Requirements

* Bash 4.3+
    * Untested on earlier versions, and most later versions for that matter
* Intended for Debian/Ubuntu, but should work on other Linux distros

## Development

If you're editing `what.sh`, don't forget to source it before running it again, e.g. `source what.sh; what ...`

## Roadmap

* Break the indentation functions into their own script

`what`

* Add colour

`symlink-info`

* Break into functions to allow sourcing from `what` for quicker execution on slow systems

## License

GNU GPLv3
