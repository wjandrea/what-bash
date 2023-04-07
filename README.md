# what-bash

`what` is a Bash function that gets info about a command, like what exactly it is and where. It can help with understanding a command's behaviour and troubleshooting issues. For example, if you run an executable, delete it, then try running it again, Bash may try to run the file that you just deleted (due to pathname hashing), leading to a confusing error message. `what` will tell you about that problem.

Along with it is `symlink-info`, which details complicated symlinks. `what` uses its function `symlink_info` on symlinked executable files.

As well, there's `indenter`, which just prints indentation. Both `what` and `symlink-info` use it for formatting their output.

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
```

A bit more complex:

```none
$ what awk sh ls
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

#### Show definitions of aliases and functions

Use `what -d`:

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

Note that the source of a function can be traced, but not an alias. `what` basically guesses at alias sources. Specifically, it tries to find the alias name in the most common files, using a regex. It doesn't look at the definition, for example:

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

If we create a bad hash:

```none
$ hash -p /nonexistent FAKE_COMMAND
$ what FAKE_COMMAND
bash: what: FAKE_COMMAND: File does not exist: /nonexistent
```

### Help and info

```none
$ what -h
Usage: what [-hi] [-dnt] [name ...]

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

Exit Status:
    3 - Invalid options
    1 - At least one NAME is not found, or any other error
    0 - otherwise
```

```none
$ what -i
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
            - (if symlink: details from "symlink_info")
        - file type

Always iterates over multiple types/instances, e.g:
    - echo: builtin and file
    - zsh: two files on Debian

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

### Help

```none
$ ./symlink-info.sh -h
Usage: symlink-info.sh [-h] [file ...]

Resolve a symlink, recursively and canonically.

Arguments:
    FILE    Filename of symlink to resolve.

Options:
    -h      Print this help message and exit.

Info provided per symlink:
    - target, recursively
    - (if relative: canonical path)

Exit Status:
    3 - Invalid options
    1 - At least one FILE is not found, or any other error
    0 - otherwise
```

## Installation

Put all three scripts in the `$PATH` so that they can `source` each other. That could be as simple as `PATH+=":$PWD/src"` from this project directory.

Everything else is your choice. For example, you might want to put `source what.sh` in your bashrc so that you always have `what` available. You might also want to put `symlink-info.sh` and `indenter.sh` in your `$PATH` as `symlink-info` and `indenter` so you can call them like that from other tools.

Command name completion is included in `what.sh` (`complete -c what`).

### Requirements

* Bash 4.3+
    * Untested on earlier versions, and most later versions for that matter
* Intended for Debian/Ubuntu, but should work on other Linux distros

## Development

If you're editing `what.sh`, don't forget to source it before running it again, e.g. `source ./what.sh; what ...`

## Roadmap

`what`

* Add colour

## License

GNU GPLv3
