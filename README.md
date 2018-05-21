# 🌺 Omni Package Manager

Initialized `opm`, pronounced like the plant "Opium" 🌺.

OPM is a shell (_pure_, not Bash) library for managing packages across various Linux/BSD package managers. Instead of asking the user to install `curl` before using your script, you can prompt to install it for them.
OPM includes access to package managers like `npm`,`gem`, and `pip`, and will also attempt to build some packages from source if necessary.

## Installation

To use OPM as a library, simply `source libopm.sh` in your application.
To use OPM as a command line tool, add `source opm.sh` to your `{bash,zsh,dash,ksh,*}rc` file. This is lazy loaded, so you don't need to worry about it slowing down your terminal.

## Building

To build the latest `libopm.sh` and `opm.sh`:
 1. Clone the repo `git clone https://github.com/maxattax97/opm`
 2. Execute `make`

This process simply stitches the shell files together into a single, more portable file.

## Testing

Docker images will be used for testing, but these are not yet implemented.

## Command Line

The command line tool may be used simply by replacing the underscores with spaces in the function calls. This turns functions like `opm_install` into the command `opm install`. The pattern of arguments remains the same.

## Examples

### Installing curl

```
opm_init
echo "The native package manager $(opm_version)"
opm_refresh
opm_install curl
```

### Installing several packages

```
opm_init
opm_refresh

opm_queue git

if [ "$EDITOR" = "/usr/bin/emacs" ]; then
    opm_queue emacs
else
    opm_queue vim
fi

opm_install
```


## API
 * [`opm_init`](#opm_init)
 * [`opm_refresh`](#opm_refresh)
 * [`opm_queue <package> ...`](#opm_queue)
 * `opm_install [package] ...`
 * `opm_uninstall <package> ...`
 * `opm_reinstall <package>`
 * `opm_clean`
 * `opm_search <term(s) ... >`
 * `opm_info <package>`
 * `opm_verify <package>`
 * `opm_fix [package]`
 * `opm_version`
 * `opm_setopt <option> <value>`

-----
#### `opm_init`
Loads OPM's resources. This is primarily to detect which package manager(s) are available. Must be loaded before trying to call any other function except `opm_setopt`. If another function is called before `opm_init`, it will automatically be initialized before proceeding.

-----
#### `opm_refresh`
Fetches the metadata for the latest packages from the configured repositories.

-----
#### `opm_queue <package> ...`
Places a package in the queue to be installed. This package will be installed along with all the other queued packages when `opm_install` is next called.

-----

## Options
A list of options follows for use in the `opm_setopt` function. Default values are in parentheses.
 * `elevate_root` (`true`): Attempts to elevate to root access for package installation.
 * `quiet` (`false`): Will silence output to `stdout` and `stderr`.

## Contributing

To be implemented.

## License

BSD 3-Clause

