# 💊 Omni Package Manager

Initialized `opm`, pronounced like the plant "Opium."

OPM is a shell library for managing packages across Linux/BSD distributions. Instead of asking the user to install `curl` before using your script, you can prompt to install it for them.

## Installation

To use OPM as a library, simply `source libopm.sh`.
To use OPM as a command line tool, add `source opm.sh` to your `{bash,zsh,dash,ksh,*}rc` file.

## Command Line

## Examples

## API
 * `opm_init`
 * `opm_refresh`
 * `opm_queue <package> ...`
 * `opm_install [package] ...`
 * `opm_uninstall <package> ...`
 * `opm_reinstall <package>`
 * `opm_clean`
 * `opm_search <term(s) ... >`
 * `opm_info <package>`
 * `opm_add_repository <repo>`
 * `opm_remove_repository <repo>`
 * `opm_verify <package>`
 * `opm_fix [package]`
 * `opm_version`
 * `opm_set_opt <option> <value>`
-----
### `opm_init`
Loads OPM's resources. This is primarily to detect which package manager(s) are available. Must be loaded before trying to call any other function except `opm_set_opt`. If another function is called before `opm_init`, it will automatically be initialized before proceeding.

-----
### `opm_refresh`

-----
### `opm_queue`

-----

## Contributing

## License

BSD 3-Clause

