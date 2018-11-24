#! /bin/dash

if [ -n "$OPM_LIB_VERSION" ]; then
    # Prevent source loops
    echo "Aborting excessive source"
    exit
fi

# Constants
# TODO: Implement sem-ver based system for requeusting a manual update from the user.
export OPM_LIB_VERSION="0.0.1"
OPM_DEBUG=1

OPM_RED() { if [ "$opm_opt_nocolor" -eq 0 ]; then printf '\033[0;91m'; fi; }
OPM_GREEN() { if [ "$opm_opt_nocolor" -eq 0 ]; then printf '\033[0;92m'; fi; }
OPM_YELLOW() { if [ "$opm_opt_nocolor" -eq 0 ]; then printf '\033[0;93m'; fi; }
OPM_BLUE() { if [ "$opm_opt_nocolor" -eq 0 ]; then printf '\033[0;94m'; fi; }
OPM_MAGENTA() { if [ "$opm_opt_nocolor" -eq 0 ]; then printf '\033[0;95m'; fi; }
OPM_CYAN() { if [ "$opm_opt_nocolor" -eq 0 ]; then printf '\033[0;96m'; fi; }
OPM_RESET() { if [ "$opm_opt_nocolor" -eq 0 ]; then printf '\033[0m'; fi; }
OPM_BLINK() { if [ "$opm_opt_nocolor" -eq 0 ]; then printf '\033[5m'; fi; }
OPM_HIGHLIGHT() { if [ "$opm_opt_nocolor" -eq 0 ]; then printf '\033[0;94m'; fi; }
OPM_GREP_COLORS='ms=01;94'

OPM_REPO_RAW_ROOT="https://raw.githubusercontent.com/Maxattax97/opm"
OPM_REPO_ROOT="https://github.com/Maxattax97/opm"

OPM_DEFAULT_NODE="node"
OPM_DEFAULT_PYTHON="python"
OPM_DEFAULT_RUBY="ruby"

OPM_DELIM=':'

# Options
opm_opt_quiet=0
opm_opt_nocolor=0
opm_opt_nodecor=0 # Trim off the decor.
opm_opt_lock_sudo=1
opm_opt_parallel=1
opm_opt_dry=1
opm_opt_noconfirm=0

# Data
opm_apt=0
opm_dnf=0
opm_zypper=0
opm_pacman=0
opm_portage=0
opm_slackpkg=0
opm_nix=0
opm_npm=0
opm_gem=0
opm_pip=0

opm_wget=0
opm_curl=0
opm_git=0

opm_os="LINUX"

opm_init_complete=0
opm_fetch_complete=0

opm_lookup_path="./pool.db"

opm_queue_index=0
opm_queue_array=

opm_apt_queue_array=
opm_zypper_queue_array=
opm_dnf_queue_array=
opm_special_queue_array=
opm_npm_queue_array=
opm_pip_queue_array=
opm_gem_queue_array=

opm_will_install_npm=0
opm_will_install_pip=0
opm_will_install_gem=0

opm_apt_queue_string=
opm_zypper_queue_string=
opm_dnf_queue_string=
opm_npm_queue_string=
opm_pip_queue_string=
opm_gem_queue_string=
opm_special_queue_string=

# Logging
msg() {
    if [ "$opm_opt_quiet" -eq 0 ]; then
        if [ -n "$2" ] && [ "$2" -ne 0 ]; then
            printf '%b' "$1"
        else
            printf '%b\n' "$1"
        fi
    fi
}

success() {
    if [ "$opm_opt_nodecor" -eq 0 ]; then
        msg "$(OPM_GREEN)[*]$(OPM_RESET) ${1}${2}" "${3}"
    else
        msg "${1}${2}" "${3}"
    fi
}

info() {
    if [ "$opm_opt_nodecor" -eq 0 ]; then
        msg "$(OPM_BLUE)[~]$(OPM_RESET) ${1}${2}" "${3}"
    else
        msg "${1}${2}" "${3}"
    fi
}

warn() {
    if [ "$opm_opt_nodecor" -eq 0 ]; then
        msg "$(OPM_YELLOW)[!]$(OPM_RESET) ${1}${2}" "${3}"
    else
        msg "${1}${2}" "${3}"
    fi
}

error() {
    if [ "$opm_opt_nodecor" -eq 0 ]; then
        msg "$(OPM_RED)$(OPM_BLINK)[X]$(OPM_RESET) ${1}${2}" "${3}"
    else
        msg "${1}${2}" "${3}"
    fi
}

query() {
    if [ "$opm_opt_nodecor" -eq 0 ]; then
        msg "$(OPM_MAGENTA)$(OPM_BLINK)[?]$(OPM_RESET) ${1}${2}" "1"
    else
        msg "${1}${2}" "${3}"
    fi
}

dry() {
    if [ "$opm_opt_nodecor" -eq 0 ]; then
        msg "$(OPM_MAGENTA) > $(OPM_RESET) ${1}${2}" "${3}"
    else
        msg "${1}${2}" "${3}"
    fi
}

none() {
    if [ "$opm_opt_nodecor" -eq 0 ]; then
        msg "    ${1}${2}" "${3}"
    else
        msg "${1}${2}" "${3}"
    fi
}

debug() {
    if [ "$OPM_DEBUG" -ne 0 ]; then
        if [ "$opm_opt_nodecor" -eq 0 ]; then
            msg "$(OPM_CYAN)$(OPM_BLINK)[#]$(OPM_RESET) ${1}${2}" "${3}"
        else
            msg "${1}${2}" "${3}"
        fi
    fi
}

# Tools
check() {
    if [ "$?" -eq 0 ]; then
        success "$1"
    else
        error "$2"
        if [ -z "$3" ]; then
            opm_abort
        fi
    fi
}

silence() {
    eval "$@" > /dev/null 2>&1
}

opm_confirm_code=2
opm_confirm() {
    continue=0
    while [ "$continue" = 0 ]; do
        if [ -n "$1" ]; then
            query "${1} [y/N] "
        else
            query "Continue? [y/N] "
        fi
        read -r -p "" response
        case "$response" in
            [yY][eE][sS]|[yY])
                continue=1
                opm_confirm_code=1
                ;;
            [nN][oO]|[nN])
                continue=1
                opm_confirm_code=0
                ;;
        esac
    done
}

opm_dry_exec() {
    if [ "$opm_opt_dry" -ne 0 ]; then
        dry "$*"
    else
        eval "$@"
    fi
}

opm_dry_elevated_exec() {
    if [ "$opm_opt_dry" -ne 0 ]; then
        dry "sudo $*"
    else
        eval sudo "$@"
    fi
}

# OPM Internals
opm_abort() {
    error "Aborting ..."
    exit
}

opm_probe() {
    if silence type "$1"; then
        echo "1"
    else
        echo "0"
    fi
}

opm_elevate() {
    if [ "$(id -u)" != 0 ]; then
        if silence sudo -n -v; then
            sudo "$@"
        else
            info "Attempting to elevate to root ..."
            if [ -z "$1" ]; then
                sudo -v
            else
                sudo "$@"
            fi
        fi
    fi
}

opm_refresh_sudo() {
    if [ "$opm_opt_lock_sudo" -ne 0 ]; then
        sudo -v
    fi
}

opm_end_sudo() {
    if [ "$opm_opt_lock_sudo" -ne 0 ]; then
        sudo -k
    fi
}

# Given a string from table and a column, determine what option is set for a
# package manager.
opm_get_column_code() {
    column="$2"
    case "$2" in
        "apt") column=2;;
        "zypper") column=3;;
        "dnf") column=4;;
        "pacman") column=5;;
        "portage") column=6;;
        "slackpkg") column=7;;
        "pkg") column=8;;
        "nix") column=9;;
        "apk") column=10;;
        "npm") column=11;;
        "pip") column=12;;
        "gem") column=13;;
        "cargo") column=14;;
        "go") column=15;;
        "cabal") column=16;;
        "flatpak") column=17;;
        "snap") column=18;;
        "appimage") column=19;;
        "source") column=20;;
        (*[!0-9]*|'') column="$2";;
        *) error "Invalid column: $2" && opm_abort;;
    esac

    value="$(echo "$1" | awk -F',|;' "{ print \$${column} };" | cut -c1-1)"
    if [ "$value" = '%' ]; then
        echo "0"
    elif [ "$value" = '!' ]; then
        if [ "$column" -eq 20 ]; then
            # Source is always ! if it is available.
            echo "1"
        else
            echo "2"
        fi
    elif [ "$value" = '$' ]; then
        echo "3"
    elif [ "$value" = '@' ]; then
        echo "4"
    else
        echo "1"
    fi
}

opm_print_enabled() {
    if [ "$opm_opt_quiet" -eq 0 ]; then
        if [ "$1" -eq 1 ]; then
            printf "$(OPM_GREEN)${2}$(OPM_RESET) "
        elif [ "$1" -eq 0 ]; then
            printf "$(OPM_RED)${2}$(OPM_RESET) "
        else
            printf "$(OPM_YELLOW)${2}$(OPM_RESET) "
        fi
    fi
}

# OPM Externals
opm_init() {
    # Check interpretter
    # debug "OPM is being interpretted by: $(ps h -p $$ -o args='' | cut -f1 -d' ')"
    debug "OPM is being interpretted by :$(ps | grep "$$" | awk '{print $NF}')" # busybox compliant

    # Probe for available package managers.
    opm_apt="$(opm_probe apt)"
    opm_dnf="$(opm_probe dnf)"
    opm_zypper="$(opm_probe zypper)"
    opm_pacman="$(opm_probe pacman)"
    opm_portage="$(opm_probe emerge)"
    opm_slackpkg="$(opm_probe slackpkg)"
    opm_nix="$(opm_probe nix)"

    # Sometimes these managers are hidden due to lazy loading (e.g. by NVM)
    opm_npm="$(opm_probe npm)"
    opm_gem="$(opm_probe gem)"
    opm_pip="$(opm_probe pip)"

    # TODO: Alternate methods of downloading
    # https://unix.stackexchange.com/questions/83926/how-to-download-a-file-using-just-bash-and-nothing-else-no-curl-wget-perl-et
    opm_wget="$(opm_probe wget)"
    opm_curl="$(opm_probe curl)"
    opm_git="$(opm_probe git)"
    opm_gzip="$(opm_probe gzip)" # Really we need gunzip, but gzip has -d flag.

    sum_managers="$(expr $opm_apt + $opm_dnf + $opm_dnf + $opm_zypper + \
        $opm_portage + $opm_slackpkg + $opm_nix + $opm_npm + \
        $opm_gem + $opm_pip)"
    if [ "$sum_managers" -gt 0 ]; then
        success "Discovered $sum_managers package managers on this system:"
        opm_print_enabled "$opm_apt" "apt"
        opm_print_enabled "$opm_dnf" "dnf"
        opm_print_enabled "$opm_zypper" "zypper"

        opm_print_enabled "$opm_npm" "npm"
        opm_print_enabled "$opm_gem" "gem"
        opm_print_enabled "$opm_pip" "pip"

        if [ "$opm_opt_quiet" -eq 0 ]; then
        printf '\n'
        fi

        success "Discovered these tools:"
        opm_print_enabled "$opm_wget" "wget"
        opm_print_enabled "$opm_curl" "curl"
        opm_print_enabled "$opm_git" "git"

        if [ "$opm_opt_quiet" -eq 0 ]; then
            printf '\n'
        fi
    else
        error "Failed to discover any package managers."
        opm_abort
    fi

    opm_detect_os
    if [ -n "$opm_os" ]; then
        info "Detected this OS to be $(OPM_HIGHLIGHT)${opm_os}$(OPM_RESET)."
    fi

    opm_init_complete=1

    if [ ! -s "$opm_lookup_path" ]; then
        opm_fetch
    fi

    success "OPM is ready."
}

opm_install() {
    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    if [ ! -z "$#" ]; then
        opm_queue "$@"
    fi

    # TODO: Sort using: sort -u

    # Long term goal:
    # Build the queues for each individual package manager.
    # Build the commands and store them.
    # Execute each package manager's command in parallel.
    # Order: Primary, {source}, secondary, tertiary (source is synchronous)
    # Short term modification: Everything is synchronous.

    if [ "$opm_apt" -ne 0 ] && [ -n "$opm_apt_queue_string" ]; then
        info "Installing packages via APT ..."
        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opm_opt_noconfirm" -ne 0 ]; then
            args="$args -y"
        fi

        opm_dry_elevated_exec apt-get install $args $opm_apt_queue_string
        check "APT packages installed." "APT failed to install packages."
    fi

    if [ "$opm_dnf" -ne 0 ] && [ -n "$opm_dnf_queue_string" ]; then
        info "Installing packages via DNF ..."

        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opm_opt_noconfirm" -ne 0 ]; then
            args="$args --noconfirm"
        fi

        opm_dry_elevated_exec dnf install $args $opm_dnf_queue_string
        check "DNF packages installed." "DNF failed to install packages."
    fi

    if [ "$opm_zypper" -ne 0 ] && [ -n "$opm_zypper_queue_string" ]; then
        info "Installing packages via Zypper ..."

        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opm_opt_noconfirm" -ne 0 ]; then
            args="$args --non-interactive"
        fi

        opm_dry_elevated_exec zypper install $args $opm_zypper_queue_string
        check "Zypper packages installed." "Zypper failed to install packages."
    fi



    if [ -n "$opm_special_queue_array" ]; then
        IFS="${OPM_DELIM}"
        for package in ${opm_special_queue_array}; do
            package_arg_1="$(echo "$package" | awk -F'_' '{ print $1 }')"
            package_arg_2="$(echo "$package" | awk -F'_' '{ print $2 }')"
            IFS=' '
            opm_install_special "$package_arg_1" "$package_arg_2"
            IFS="${OPM_DELIM}"
        done
        IFS=' '
    fi



    # TODO: Enable freshly installed package managers (e.g. npm, pip, gem).
    if [ "$opm_will_install_npm" -ne 0 ]; then
        opm_will_install_npm=0
        opm_npm=1
        info "NPM has been installed and enabled."
    fi
    if [ "$opm_will_install_pip" -ne 0 ]; then
        opm_will_install_pip=0
        opm_pip=1
        info "Pip has been installed and enabled."
    fi
    if [ "$opm_will_install_gem" -ne 0 ]; then
        opm_will_install_gem=0
        opm_gem=1
        info "Gem has been installed and enabled."
    fi



    # These package managers must install _globally_.
    if [ "$opm_npm" -ne 0 ] && [ -n "$opm_npm_queue_string" ]; then
        info "Installing packages via NPM ..."

        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            # --quiet prints errors.
            # --silent prints nothing.
            args="$args --quiet"
        fi
        # NPM does not offer a non-interactive argument.

        opm_dry_exec npm install -g $args $opm_npm_queue_string
        check "NPM packages installed." "NPM failed to install packages."
    fi

    # Gem refreshes on its own.
    # Pip refreshes on its own.

    # Wipe all installation data.
    opm_apt_queue_array=
    opm_zypper_queue_array=
    opm_dnf_queue_array=
    opm_special_queue_array=
    opm_npm_queue_array=
    opm_pip_queue_array=
    opm_gem_queue_array=

    opm_will_install_npm=0
    opm_will_install_pip=0
    opm_will_install_gem=0

    opm_apt_queue_string=
    opm_zypper_queue_string=
    opm_dnf_queue_string=
    opm_npm_queue_string=
    opm_pip_queue_string=
    opm_gem_queue_string=
    opm_special_queue_string=
}

# Split the package and installer before feeding.
opm_install_special() {
    package="$1"
    manager="$2"
    category=

    if [ -z "$package" ]; then
        error "A package must be specified ($1 $2)"
        opm_abort
    fi

    if [ -z "$manager" ]; then
        error "A manager must be specified ($1 $2)"
        opm_abort
    elif [ "$manager" = "apt" ] || [ "$manager" = "zypper" ] || [ "$manager" = "dnf" ]; then
        category="primary"
    elif [ "$manager" = "npm" ] || [ "$manager" = "pip" ] || [ "$manager" = "gem" ]; then
        category="secondary"
    elif [ "$manager" = "flatpak" ] || [ "$manager" = "snap" ]; then
        category="tertiary"
    else
        category="source"
    fi

    if [ "$manager" = "source" ]; then
        uri_path="packages/${category}/${package}"
    else
        uri_path="packages/${category}/${manager}/${package}"
    fi

    break_loop=0
    while [ "$break_loop" -eq 0 ]; do
        if [ "$opm_wget" -ne 0 ]; then
            debug "Re-enable dry mode"
            wget -O /tmp/OPM_INSTALL "${OPM_REPO_RAW_ROOT}/master/${uri_path}"
        elif [ "$opm_curl" -ne 0 ]; then
            opm_dry_exec curl -o /tmp/OPM_INSTALL "${OPM_REPO_RAW_ROOT}/master/${uri_path}"
        elif [ "$opm_git" -ne 0 ]; then
            opm_dry_exec git clone "${OPM_REPO_ROOT}" /tmp/opm/
            opm_dry_exec cp "/tmp/opm/${uri_path}" /tmp/OPM_INSTALL
        else
            error "No tools are available on this system to fetch remote resources."
        fi

        if [ -s /tmp/OPM_INSTALL ]; then
            info "Previewing installation script ..."
            if [ "$(opm_probe most)" -ne 0 ]; then
                most /tmp/OPM_INSTALL
            elif [ "$(opm_probe less)" -ne 0 ]; then
                less /tmp/OPM_INSTALL
            elif [ "$(opm_probe more)" -ne 0 ]; then
                more /tmp/OPM_INSTALL
            else
                cat /tmp/OPM_INSTALL
            fi

            opm_confirm "Continue installing $(OPM_HIGHLIGHT)$1$(OPM_RESET)?"

            if [ "$opm_confirm_code" -ne 0 ]; then
                info "Beginning to install $(OPM_HIGHLIGHT)$1$(OPM_RESET) ..."
                chmod +x /tmp/OPM_INSTALL
                opm_elevate /tmp/OPM_INSTALL
                check "Installation successful." "Installation failed."
                break_loop=1;
            else
                warn "Aborting installation of $(OPM_HIGHLIGHT)${1}$(OPM_RESET)."
                break_loop=1;
            fi
        else
            error "Failed to download the installer script for $(OPM_HIGHLIGHT)$1$(OPM_RESET)"
            opm_confirm "Retry?"
            if [ "$opm_confirm_code" -eq 0 ]; then
                break_loop=1;
            fi
        fi
    done
}

opm_refresh() {
    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    # TODO: Store processes in a list, execute all at once, check at end.
    # No gap to lose an exit code in.
    jobs=""
    #job_count=0

    if [ "$opm_apt" -ne 0 ]; then
        info "Refreshing APT ..."
        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi

        if [ "$opm_opt_parallel" -ne 0 ]; then
            opm_dry_elevated_exec apt-get $args update &
            jobs="${!}${OPM_DELIM}${jobs}"
            #jobs[job_count]=$!
            #job_count="$(expr 1 + $job_count )"
        else
            opm_dry_elevated_exec apt-get $args update
            check "APT refreshed." "APT failed to refresh."
        fi
    fi

    if [ "$opm_dnf" -ne 0 ]; then
        info "Refreshing DNF ..."

        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi

        if [ "$opm_opt_parallel" -ne 0 ]; then
            opm_dry_elevated_exec dnf $args check-update &
            jobs="${!}${OPM_DELIM}${jobs}"
            #jobs[job_count]=$!
            #job_count="$(expr 1 + $job_count )"
        else
            opm_dry_elevated_exec dnf $args check-update
            check "DNF refreshed." "DNF failed to refresh."
        fi
    fi

    if [ "$opm_zypper" -ne 0 ]; then
        info "Refreshing Zypper ..."

        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi

        if [ "$opm_opt_parallel" -ne 0 ]; then
            opm_dry_elevated_exec zypper $args refresh &
            jobs="${!}${OPM_DELIM}${jobs}"
            #jobs[job_count]=$!
            #job_count="$(expr 1 + $job_count )"
        else
            opm_dry_elevated_exec zypper $args refresh
            check "Zypper refreshed." "Zypper failed to refresh."
        fi
    fi

    # NPM refreshes on its own.
    # Gem refreshes on its own.
    # Pip refreshes on its own.

    opm_refresh_sudo

    failures=0
    jobs="${jobs%%${OPM_DELIM}}"
    IFS="$OPM_DELIM"
    for pid in $jobs; do
        debug "waiting on fork $pid"
        wait $pid || failures="$(expr $failures + 1)"
        opm_refresh_sudo
    done
    IFS=' '

    if [ "$failures" -gt 0 ]; then
        error "A package manager failed to refresh."
    else
        success "All package managers refreshed."
    fi
}

opm_upgrade() {
    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    jobs=
    job_count=0

    if [ "$opm_apt" -ne 0 ]; then
        info "Upgrading APT ..."
        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opm_opt_noconfirm" -ne 0 ]; then
            args="$args -y"
        fi

        opm_dry_elevated_exec apt-get $args upgrade
        check "APT upgraded." "APT failed to upgrade."
    fi

    if [ "$opm_dnf" -ne 0 ]; then
        info "Upgrading DNF ..."

        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opm_opt_noconfirm" -ne 0 ]; then
            args="$args --noconfirm"
        fi

        opm_dry_elevated_exec dnf $args upgrade
        check "DNF upgraded." "DNF failed to upgrade."
    fi

    if [ "$opm_zypper" -ne 0 ]; then
        info "Upgrading Zypper ..."

        args=""
        if [ "$opm_opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opm_opt_noconfirm" -ne 0 ]; then
            args="$args --non-interactive"
        fi

        opm_dry_elevated_exec zypper $args update
        check "Zypper upgraded." "Zypper failed to upgrade."
    fi

    # NPM refreshes on its own.
    # Gem refreshes on its own.
    # Pip refreshes on its own.
}

opm_add_repo() {
    debug "Not yet implemented."
}

opm_fetch() {
    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    # TODO: Upgrade all of OPM since some packages may need downloaded special instructions.
    # ... Unless we get smart and download those on the fly too... :?

    if [ "$opm_fetch_complete" -eq 0 ]; then
        if [ "$opm_wget" -ne 0 ]; then
            opm_dry_exec wget -O /tmp/OPM_UPDATE "${OPM_REPO_RAW_ROOT}/master/lookup"

            check "Fetched latest resources." "Failed to fetch resources."
            opm_dry_exec cp /tmp/OPM_UPDATE "$opm_lookup_path"
            opm_fetch_complete=1
        elif [ "$opm_curl" -ne 0 ]; then
            opm_dry_exec curl -o /tmp/OPM_UPDATE "${OPM_REPO_RAW_ROOT}/master/lookup"

            check "Fetched latest resources." "Failed to fetch resources."
            opm_dry_exec cp /tmp/OPM_UPDATE "$opm_lookup_path"
            opm_fetch_complete=1
        elif [ "$opm_git" -ne 0 ]; then
            opm_dry_exec git clone "${OPM_REPO_ROOT}" /tmp/opm/

            check "Fetched latest resources." "Failed to fetch resources."
            opm_dry_exec cp /tmp/opm/lookup "$opm_lookup_path"
            opm_fetch_complete=1
        else
            error "No tools are available on this system to fetch remote resources."
        fi
    else
        info "Skipping fetch since it was recently completed."
    fi
}

opm_query() {
    if [ -z "$#" ]; then
        error "You must specify a list of terms to search with."
        abort
    fi

    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    search=""
    for i in "$@"; do
        search="${i}|${search}"
    done
    search="${search%%|}"

    results="$(grep -iE "$search" "$opm_lookup_path")"
    
    info "Results for: $*"
    if [ "$opm_opt_quiet" -eq 0 ]; then
        if [ "$opm_opt_nocolor" -eq 0 ]; then
            # This regex is specially crafted to allow reverse lookups; `openjdk-8-jdk` return `jdk8`.
            echo "$results" | awk -F';' '{ print "    " $1 "\t\t\t" $6 }' | GREP_COLORS="${OPM_GREP_COLORS}" grep -iE --color "$search|$"
        else
            echo "$results" | awk -F';' '{ print "    " $1 "\t\t\t" $6 }' | grep -iE "$search|$"
        fi
    fi
}

opm_queue() {
    if [ -z "$#" ]; then
        error "You must specify a list of terms to search with."
        abort
    fi

    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    dependency_array=

    for package in "$@"; do
        # 1 NAME;
        # 2 apt,zypper,dnf,pacman,portage,slackpkg,pkg,nix,apk;
        # 3 npm,pip,gem,cargo,go,cabal;
        # 4 flatpak,snap,appimage;
        # 5 source;
        # 6 DESCRIPTION

        continue=1

        # TODO: Keep track of OPM queued names and report when duplicates
        # are attempted to be installed/queued.
        #debug "EXISTS ${opm_apt_queue_array}${opm_zypper_queue_array}${opm_dnf_queue_array}${opm_npm_queue_array}${opm_pip_queue_array}${opm_gem_queue_array}${opm_source_queue_array}"
        #exists="$(echo "${opm_apt_queue_array}${opm_zypper_queue_array}${opm_dnf_queue_array}${opm_npm_queue_array}${opm_pip_queue_array}${opm_gem_queue_array}${opm_source_queue_array}" \
            #| grep -iE "(${OPM_DELIM}|^)${package}(${OPM_DELIM}|$)")"
        #if [ -n "$exists" ]; then
            #warn "$package is already queued, ignoring ..."
            #continue=0
        #fi

        result_line="$(grep -m 1 -iE "^${package};" "$opm_lookup_path")"
        if [ -z "$result_line" ]; then
            warn "No package matches $(OPM_HIGHLIGHT)$package$(OPM_RESET), ignoring ..."
            continue=0
        fi

        if [ "$continue" -ne 0 ]; then
            apt_package="$(echo "$result_line" | awk -F',|;' '{ print $2 }')"
            zypper_package="$(echo "$result_line" | awk -F',|;' '{ print $3 }')"
            dnf_package="$(echo "$result_line" | awk -F',|;' '{ print $4 }')"
            npm_package="$(echo "$result_line" | awk -F',|;' '{ print $11 }')"
            pip_package="$(echo "$result_line" | awk -F',|;' '{ print $12 }')"
            gem_package="$(echo "$result_line" | awk -F',|;' '{ print $13 }')"
            source_package="$(echo "$result_line" | awk -F',|;' '{ print $20 }')"

            if [ "$opm_apt" -ne 0 ] && [ "$apt_package" != "%" ]; then
                if [ "$apt_package" = "!" ]; then
                    opm_special_queue_array="${package}_apt${OPM_DELIM}${opm_special_queue_array}"
                else
                    opm_apt_queue_array="${apt_package}${OPM_DELIM}${opm_apt_queue_array}"
                fi
            elif [ "$opm_zypper" -ne 0 ] && [ "$zypper_package" != "%" ]; then
                if [ "$zypper_package" = "!" ]; then
                    opm_special_queue_array="${package}_zypper${OPM_DELIM}${opm_special_queue_array}"
                else
                    opm_zypper_queue_array="${zypper_package}${OPM_DELIM}${opm_zypper_queue_array}"
                fi
            elif [ "$opm_dnf" -ne 0 ] && [ "$dnf_package" != "%" ]; then
                opm_dnf_queue_array="${dnf_package}${OPM_DELIM}${opm_dnf_queue_array}"
            elif [ "$npm_package" != "%" ]; then
                if [ "$opm_npm" -ne 0 ] || [ "$opm_will_install_npm" -ne 0 ]; then
                    opm_npm_queue_array="${npm_package}${OPM_DELIM}${opm_npm_queue_array}"
                elif [ "$opm_npm" -eq 0 ] && [ "$opm_will_install_npm" -eq 0 ]; then
                    dependency_array="${OPM_DEFAULT_NODE}${OPM_DELIM}${dependency_array}"
                    opm_npm_queue_array="${npm_package}${OPM_DELIM}${opm_npm_queue_array}"
                fi
            elif [ "$pip_package" != "%" ]; then
                if [ "$opm_pip" -ne 0 ] || [ "$opm_will_install_pip" -ne 0 ]; then
                    opm_pip_queue_array="${pip_package}${OPM_DELIM}${opm_pip_queue_array}"
                elif [ "$opm_pip" -eq 0 ] && [ "$opm_will_install_pip" -eq 0 ]; then
                    dependency_array="${OPM_DEFAULT_PYTHON}${OPM_DELIM}${dependency_array}"
                    opm_pip_queue_array="${pip_package}${OPM_DELIM}${opm_pip_queue_array}"
                fi
            elif [ "$gem_package" != "%" ]; then
                if [ "$opm_gem" -ne 0 ] || [ "$opm_will_install_gem" -ne 0 ]; then
                    opm_gem_queue_array="${gem_package}${OPM_DELIM}${opm_gem_queue_array}"
                elif [ "$opm_gem" -eq 0 ] && [ "$opm_will_install_gem" -eq 0 ]; then
                    dependency_array="${OPM_DEFAULT_RUBY}${OPM_DELIM}${dependency_array}"
                    opm_gem_queue_array="${gem_package}${OPM_DELIM}${opm_gem_queue_array}"
                fi
            elif [ "$source_package" != "%" ]; then
                opm_special_queue_array="${package}_source${OPM_DELIM}${opm_special_queue_array}"
            else
                warn "$package cannot be installed on this system."
            fi
        fi
    done

    if [ -n "$dependency_array" ]; then
        IFS="${OPM_DELIM}"
        for dependency in ${dependency_array}; do
            if [ "$opm_apt" -ne 0 ]; then
                info "Will install $(OPM_HIGHLIGHT)${dependency}$(OPM_RESET) via APT as a dependency."
                opm_apt_queue_array="${dependency}$(OPM_DELIM)${opm_apt_queue_array}"
            elif [ "$opm_zypper" -ne 0 ]; then
                info "Will install $(OPM_HIGHLIGHT)${dependency}$(OPM_RESET) via Zypper as a dependency."
                opm_zypper_queue_array="${dependency}$(OPM_DELIM)${opm_zypper_queue_array}"
            elif [ "$opm_dnf" -ne 0 ]; then
                info "Will install $(OPM_HIGHLIGHT)${dependency}$(OPM_RESET) via DNF as a dependency."
                opm_dnf_queue_array="${dependency}$(OPM_DELIM)${opm_dnf_queue_array}"
            else
                info "Will install $(OPM_HIGHLIGHT)${dependency}$(OPM_RESET) from source as a dependency."
                opm_special_queue_array="${dependency}$(OPM_DELIM)${opm_special_queue_array}"
            fi

            if [ "${dependency}" = "${OPM_DEFAULT_NODE}" ]; then
                opm_will_install_npm=1
            fi
            if [ "${dependency}" = "${OPM_DEFAULT_PIP}" ]; then
                opm_will_install_pip=1
            fi
            if [ "${dependency}" = "${OPM_DEFAULT_GEM}" ]; then
                opm_will_install_gem=1
            fi
        done
        IFS=' '
    fi

    opm_apt_queue_string="$(printf '%s' "$opm_apt_queue_array" | tr "${OPM_DELIM}" " ")"
    opm_zypper_queue_string="$(printf '%s' "$opm_zypper_queue_array" | tr "${OPM_DELIM}" " ")"
    opm_dnf_queue_string="$(printf '%s' "$opm_dnf_queue_array" | tr "${OPM_DELIM}" " ")"
    opm_npm_queue_string="$(printf '%s' "$opm_npm_queue_array" | tr "${OPM_DELIM}" " ")"
    opm_pip_queue_string="$(printf '%s' "$opm_pip_queue_array" | tr "${OPM_DELIM}" " ")"
    opm_gem_queue_string="$(printf '%s' "$opm_gem_queue_array" | tr "${OPM_DELIM}" " ")"
    opm_special_queue_string="$(printf '%s' "$opm_special_queue_array" | tr "${OPM_DELIM}" " ")"

    success "Queued packages:"
    none "APT: ${opm_apt_queue_string}"
    none "Zypper: ${opm_zypper_queue_string}"
    none "DNF: ${opm_dnf_queue_string}"
    none "NPM: ${opm_npm_queue_string}"
    none "Pip: ${opm_pip_queue_string}"
    none "Gem: ${opm_gem_queue_string}"
    none "Special: ${opm_special_queue_string}"
}

opm_describe() {
    if [ "$#" -ne 1 ]; then
        error "You must specify a package."
        abort
    fi

    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    result="$(awk -F';' "BEGIN{IGNORECASE = 1}\$1 ~ /^$1$/ { print };" "$opm_lookup_path")"

    if [ -n "$result" ]; then
        name="$(echo "$result" | awk -F';' '{ print $1 };')"
        description="$(echo "$result" | awk -F';' '{ print $6 };')"
        success "Name: \t\t$name"
        none "Description: \t$description"
        none "Support: \t\t" "" 1
        opm_print_enabled "$(opm_get_column_code "$result" "apt")" "apt"
        opm_print_enabled "$(opm_get_column_code "$result" "dnf")" "dnf"
        opm_print_enabled "$(opm_get_column_code "$result" "zypper")" "zypper"

        opm_print_enabled "$(opm_get_column_code "$result" "npm")" "npm"
        opm_print_enabled "$(opm_get_column_code "$result" "pip")" "pip"
        opm_print_enabled "$(opm_get_column_code "$result" "gem")" "gem"

        opm_print_enabled "$(opm_get_column_code "$result" "source")" "source"

        if [ "$opm_opt_quiet" -eq 0 ]; then
            printf '\n'
        fi
    else
        warn "No entries were found for $(OPM_HIGHLIGHT)$1$(OPM_RESET)."
    fi
}

opm_clean() {
    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    debug "Not yet implemented."
}

opm_version() {
    info "Omni Package Manager v${OPM_LIB_VERSION}"
}

opm_help() {
    info "Available subcommands: $(OPM_HIGHLIGHT)version init fetch refresh describe query queue install upgrade$(OPM_RESET)"
}

# Based on some code contributed to Powerlevel9K
# https://github.com/bhilburn/powerlevel9k/blob/next/functions/utilities.zsh
opm_detect_os() {
    case "$(uname)" in
        Darwin)
            opm_os="OSX"
            ;;
        CYGWIN_NT-* | MSYS_NT-*)
            opm_os="WINDOWS"
            ;;
        FreeBSD)
            opm_os="FREE_BSD"
            ;;
        OpenBSD)
            opm_os="OPEN_BSD"
            ;;
        DragonFly)
            opm_os="DRAGONFLY_BSD"
            ;;
        Linux)
            opm_os="UNKNOWN_LINUX"
            os_release_id="$(grep -E '^ID=([a-zA-Z]*)' /etc/os-release | cut -d '=' -f 2)"
            case "$os_release_id" in
                *arch*)
                    opm_os="ARCH_LINUX"
                    ;;
                *debian*)
                    opm_os="DEBIAN_LINUX"
                    ;;
                *ubuntu*)
                    opm_os="UBUNTU_LINUX"
                    ;;
                *elementary*)
                    opm_os="ELEMENTARY_LINUX"
                    ;;
                *fedora*)
                    opm_os="FEDORA_LINUX"
                    ;;
                *coreos*)
                    opm_os="COREOS_LINUX"
                    ;;
                *gentoo*)
                    opm_os="GENTOO_LINUX"
                    ;;
                *mageia*)
                    opm_os="MAGEIA_LINUX"
                    ;;
                *centos*)
                    opm_os="CENTOS_LINUX"
                    ;;
                *opensuse*|*tumbleweed*)
                    opm_os="OPENSUSE_LINUX"
                    ;;
                *sabayon*)
                    opm_os="SABAYON_LINUX"
                    ;;
                *slackware*)
                    opm_os="SLACKWARE_LINUX"
                    ;;
                *linuxmint*)
                    opm_os="MINT_LINUX"
                    ;;
                *alpine*)
                    opm_os="ALPINE_LINUX"
                    ;;
                *aosc*)
                    opm_os="AOSC_LINUX"
                    ;;
                *nixos*)
                    opm_os="NIXOS_LINUX"
                    ;;
                *devuan*)
                    opm_os="DEVUAN_LINUX"
                    ;;
                *manjaro*)
                    opm_os="MANJARO_LINUX"
                    ;;
                *)
                    opm_os='UNKNOWN_LINUX'
                    error "Unable to determine Linux distribution."
                    ;;
            esac

            # Check if we're running on Android
            case $(uname -o 2>/dev/null) in
                Android)
                    opm_os="ANDROID"
                    ;;
            esac
            ;;
        SunOS)
            opm_os="SOLARIS"
            ;;
        *)
            opm_os="UNKNOWN"
            error "Unable to determine operating system."
            ;;
    esac
}

opm_cli() {
    command="$1"

    if [ -n "$command" ]; then
        case "$command" in
            version)
                opm_version
                ;;
            fetch)
                opm_fetch
                ;;
            refresh)
                opm_refresh
                ;;
            upgrade)
                opm_upgrade
                ;;
            describe)
                opm_describe "$2"
                ;;
            query)
                shift
                opm_query "$@"
                ;;
            queue)
                shift
                opm_queue "$@"
                ;;
            install)
                shift
                opm_install "$@"
                ;;
            init)
                opm_init
                ;;
            help)
                opm_help
                ;;
            --help)
                opm_help
                ;;
            *)
            error "Unrecognized command: $(OPM_HIGHLIGHT)${command}$(OPM_RESET). See $(OPM_HIGHLIGHT)opm help$(OPM_RESET) for a list of commands."
        esac
    fi
}


