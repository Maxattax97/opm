# 🌺 Omni Package Manager

Initialized `opm`, pronounced like the magical, fix-it-all plant "Opium" 🌺.

OPM is a POSIX shell (_not Bash_) library and command line tool for managing packages across various Linux/BSD package managers. Instead of asking the user to install `curl` or follow a list of instructions for each package manager before using your program, you can prompt to install it for them or provide a single command to intall it with.
OPM includes access to sophisticated package managers like `apt`, `dnf`, and `zypper`, but also supports `npm`,`gem`, `pip`, and even `flatpak`. It will also attempt to build some packages from source if necessary.

OPM is also useful for distro-independent installers, especially those that might be included in a portable `{bash,zsh,dash,ksh,*}rc` file. When deploying to a new system, all your tools can be pre-installed despite completely switching distributions.

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

## Contributing & Mechanics

OPM functions very simply. It uses a lookup table to find equivalent packages across different package managers. It will prioritize system-specific (or _primary_) managers first, then try to install from _secondary_ package managers like `npm`. If a secondary package manager is not availbe, OPM will do it's best to install it for the user. The same follows for _tertiary_ package managers like Flatpak.

Long story short, if you need to install a particular package and it's not available, add an entry to the `lookup` file. Follow the format specified, and make a pull request.

## Command Line

The command line tool may be used simply by replacing the underscores with spaces in the function calls. This turns functions like `opm_setopt` into the command `opm setopt`. The pattern of arguments remains the same.

## Examples

### Installing curl

```
opm_init
echo "The native package manager $(opm_version)"
opm_refresh
opm_install curl
```

### Upgrading, then Installing several packages

```
opm_init
opm_refresh
opm_upgrade

opm_queue git curl clang

if [ "$EDITOR" = "/usr/bin/emacs" ]; then
    opm_queue emacs
else
    opm_queue vim
fi

opm_install
```


## API
 * [`opm_init`](#opm_init) - Let OPM get setup and probe the local system.
 * [`opm_refresh`](#opm_refresh) - Refresh the local package managers' repos.
 * [`opm_fetch`](#opm_fetch) - Fetch the latest lookup table for OPM.
 * [`opm_queue <package> ...`](#opm_queue-package-) - Queue package(s) for installation.
 * [`opm_install [package] ...`](#opm_install-package-) - Install a (or several queued) package(s).
 * [`opm_uninstall <package> ...`](#opm_uninstall-package-) - Uninstall a (or several queued) package(s).
 * [`opm_reinstall <package>`](#opm_reinstall-package-) - Reinstall a package.
 * [`opm_upgrade`](#opm_upgrade) - Upgrade the local packages to their latest versions.
 * [`opm_clean`](#opm_clean) - Clean the local package managers' cache.
 * [`opm_search <term(s) ... >`](#opm_search-terms-) - Search the local package managers for packages.
 * [`opm_query <term(s) ... >`](#opm_query-terms-) - Search OPM's lookup table for packages.
 * [`opm_info <package>`](#opm_info-package-) - Provide details on a package from a local package manager.
 * [`opm_describe <package>`](#opm_describe-package-) - Print the description of a package from OPM's table.
 * [`opm_verify <package>`](#opm_verify-package-) - Attempt to verify that a package was installed correctly on system.
 * [`opm_fix [package]`](#opm_fix-package-) - Attempt to repair an installed package.
 * [`opm_version`](#opm_version)(#opm_version) - Print OPM's version and detected package managers.
 * [`opm_help`](#opm_help) - Print a list of OPM's available commands.
 * [`opm_setopt <option> <value>`](#opm_setopt-value-) - Set one of OPM's confiugration options.

-----
#### `opm_init`
Loads OPM's resources. This is primarily to detect which package manager(s) are available. Must be loaded before trying to call any other function except `opm_setopt` and `opm_version`. If another function is called before `opm_init`, it will automatically be initialized before proceeding.

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

