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

OPM_RED='\033[0;91m'
OPM_GREEN='\033[0;92m'
OPM_YELLOW='\033[0;93m'
OPM_BLUE='\033[0;94m'
OPM_MAGENTA='\033[0;95m'
OPM_CYAN='\033[0;96m'
OPM_RESET='\033[0m'
OPM_BLINK='\033[5m'
OPM_GREP_COLORS='ms=01;94'

OPM_REPO_RAW_ROOT="https://raw.githubusercontent.com/Maxattax97/opm"
OPM_REPO_ROOT="https://github.com/Maxattax97/opm"

OPM_DEFAULT_NODE="node"
OPM_DEFAULT_PYTHON="python"
OPM_DEFAULT_RUBY="ruby"

OPM_DELIM=':'

# Options
opt_opm_quiet=0
opt_opm_lock_sudo=1
opt_opm_parallel=1
opt_opm_dry=1

opt_quiet=0
opt_noconfirm=0

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

opm_init_complete=0
opm_fetch_complete=0

opm_lookup_path="./lookup"

opm_queue_index=0
opm_queue_array=

apt_queue_array=
zypper_queue_array=
dnf_queue_array=
source_queue_array=
npm_queue_array=
pip_queue_array=
gem_queue_array=

will_install_npm=0
will_install_pip=0
will_install_gem=0

# Logging
msg() {
    if [ "$opt_opm_quiet" -eq 0 ]; then
        if [ -n "$2" ] && [ "$2" -ne 0 ]; then
            printf '%b' "$1"
        else
            printf '%b\n' "$1"
        fi
    fi
}

success() {
    msg "${OPM_GREEN}[*]${OPM_RESET} ${1}${2}" "${3}"
}

info() {
    msg "${OPM_BLUE}[~]${OPM_RESET} ${1}${2}" "${3}"
}

warn() {
    msg "${OPM_YELLOW}[!]${OPM_RESET} ${1}${2}" "${3}"
}

error() {
    msg "${OPM_RED}${OPM_BLINK}[X]${OPM_RESET} ${1}${2}" "${3}"
}

dry() {
    msg "${OPM_MAGENTA} > ${OPM_RESET} ${1}${2}" "${3}"
}

none() {
    msg "    ${1}${2}" "${3}"
}

debug() {
    if [ "$OPM_DEBUG" -ne 0 ]; then
        msg "${OPM_CYAN}${OPM_BLINK}[#]${OPM_RESET} ${1}${2}" "${3}"
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

opm_dry_exec() {
    if [ "$opt_opm_dry" -ne 0 ]; then
        dry "$*"
    else
        eval "$@"
    fi
}

opm_dry_elevated_exec() {
    if [ "$opt_opm_dry" -ne 0 ]; then
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
    if [ "$opt_opm_lock_sudo" -ne 0 ]; then
        sudo -v
    fi
}

opm_end_sudo() {
    if [ "$opt_opm_lock_sudo" -ne 0 ]; then
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
    if [ "$opt_opm_quiet" -eq 0 ]; then
        if [ "$1" -eq 1 ]; then
            printf "${OPM_GREEN}${2}${OPM_RESET} "
        elif [ "$1" -eq 0 ]; then
            printf "${OPM_RED}${2}${OPM_RESET} "
        else
            printf "${OPM_YELLOW}${2}${OPM_RESET} "
        fi
    fi
}

# OPM Externals
opm_init() {
    # Check interpretter
    warn "OPM is being interpretted by: $(ps h -p $$ -o args='' | cut -f1 -d' ')"

    # Probe for available package managers.
    opm_apt="$(opm_probe apt)"
    opm_dnf="$(opm_probe dnf)"
    opm_zypper="$(opm_probe zypper)"
    opm_pacman="$(opm_probe pacman)"
    opm_portage="$(opm_probe emerge)"
    opm_slackpkg="$(opm_probe slackpkg)"
    opm_nix="$(opm_probe nix)"
    opm_npm="$(opm_probe npm)"
    opm_gem="$(opm_probe gem)"
    opm_pip="$(opm_probe pip)"

    opm_wget="$(opm_probe wget)"
    opm_curl="$(opm_probe curl)"
    opm_git="$(opm_probe git)"

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

        if [ "$opt_opm_quiet" -eq 0 ]; then
        printf '\n'
        fi

        success "Discovered these tools:"
        opm_print_enabled "$opm_wget" "wget"
        opm_print_enabled "$opm_curl" "curl"
        opm_print_enabled "$opm_git" "git"

        if [ "$opt_opm_quiet" -eq 0 ]; then
            printf '\n'
        fi
    else
        error "Failed to discover any package managers."
        opm_abort
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

    if [ "$opm_apt" -ne 0 ] && [ -n "$apt_queue_string" ]; then
        info "Installing packages via APT ..."
        args=""
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opt_noconfirm" -ne 0 ]; then
            args="$args -y"
        fi

        opm_dry_elevated_exec apt-get install $args $apt_queue_string
        check "APT packages installed." "APT failed to install packages."
    fi

    if [ "$opm_dnf" -ne 0 ] && [ -n "$dnf_queue_string" ]; then
        info "Installing packages via DNF ..."

        args=""
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opt_noconfirm" -ne 0 ]; then
            args="$args --noconfirm"
        fi

        opm_dry_elevated_exec dnf install $args $dnf_queue_string
        check "DNF packages installed." "DNF failed to install packages."
    fi

    if [ "$opm_zypper" -ne 0 ] && [ -n "$zypper_queue_string" ]; then
        info "Installing packages via Zypper ..."

        args=""
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opt_noconfirm" -ne 0 ]; then
            args="$args --non-interactive"
        fi

        opm_dry_elevated_exec zypper install $args $zypper_queue_string
        check "Zypper packages installed." "Zypper failed to install packages."
    fi


    # Enable freshly installed package managers.
    if [ "$will_install_npm" -ne 0 ]; then
        info "NPM has been installed and enabled."
        opm_npm=1
    fi
    if [ "$will_install_pip" -ne 0 ]; then
        info "Pip has been installed and enabled."
        opm_pip=1
    fi
    if [ "$will_install_gem" -ne 0 ]; then
        info "Gem has been installed and enabled."
        opm_gem=1
    fi

    # These package managers must install _globally_.
    if [ "$opm_npm" -ne 0 ] && [ -n "$npm_queue_string" ]; then
        info "Installing packages via NPM ..."

        args=""
        if [ "$opt_quiet" -ne 0 ]; then
            # --quiet prints errors.
            # --silent prints nothing.
            args="$args --quiet"
        fi
        # NPM does not offer a non-interactive argument.

        opm_dry_exec npm install -g $args $npm_queue_string
        check "NPM packages installed." "NPM failed to install packages."
    fi

    # Gem refreshes on its own.
    # Pip refreshes on its own.
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
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi

        if [ "$opt_opm_parallel" -ne 0 ]; then
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
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi

        if [ "$opt_opm_parallel" -ne 0 ]; then
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
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi

        if [ "$opt_opm_parallel" -ne 0 ]; then
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
        echo "waiting on fork $pid"
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
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opt_noconfirm" -ne 0 ]; then
            args="$args -y"
        fi

        opm_dry_elevated_exec apt-get $args upgrade
        check "APT upgraded." "APT failed to upgrade."
    fi

    if [ "$opm_dnf" -ne 0 ]; then
        info "Upgrading DNF ..."

        args=""
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opt_noconfirm" -ne 0 ]; then
            args="$args --noconfirm"
        fi

        opm_dry_elevated_exec dnf $args upgrade
        check "DNF upgraded." "DNF failed to upgrade."
    fi

    if [ "$opm_zypper" -ne 0 ]; then
        info "Upgrading Zypper ..."

        args=""
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi
        if [ "$opt_noconfirm" -ne 0 ]; then
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

    results="$(grep -iE "$search" lookup)"

    info "Results for: $*"
    if [ "$opt_opm_quiet" -eq 0 ]; then
        echo "$results" | awk -F';' '{ print "    " $1 "\t\t\t" $6 }' | GREP_COLORS="${OPM_GREP_COLORS}" grep -iE --color "$search"
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
        #debug "EXISTS ${apt_queue_array}${zypper_queue_array}${dnf_queue_array}${npm_queue_array}${pip_queue_array}${gem_queue_array}${source_queue_array}"
        #exists="$(echo "${apt_queue_array}${zypper_queue_array}${dnf_queue_array}${npm_queue_array}${pip_queue_array}${gem_queue_array}${source_queue_array}" \
            #| grep -iE "(${OPM_DELIM}|^)${package}(${OPM_DELIM}|$)")"
        #if [ -n "$exists" ]; then
            #warn "$package is already queued, ignoring ..."
            #continue=0
        #fi

        result_line="$(grep -m 1 -iE "^${package};" lookup)"
        if [ -z "$result_line" ]; then
            warn "No package matches $package, ignoring ..."
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
                apt_queue_array="${apt_package}${OPM_DELIM}${apt_queue_array}"
            elif [ "$opm_zypper" -ne 0 ] && [ "$zypper_package" != "%" ]; then
                zypper_queue_array="${zypper_package}${OPM_DELIM}${zypper_queue_array}"
            elif [ "$opm_dnf" -ne 0 ] && [ "$dnf_package" != "%" ]; then
                dnf_queue_array="${dnf_package}${OPM_DELIM}${dnf_queue_array}"
            elif [ "$npm_package" != "%" ]; then
                if [ "$opm_npm" -ne 0 ] || [ "$will_install_npm" -ne 0 ]; then
                    npm_queue_array="${npm_package}${OPM_DELIM}${npm_queue_array}"
                elif [ "$opm_npm" -eq 0 ] && [ "$will_install_npm" -eq 0 ]; then
                    dependency_array="${OPM_DEFAULT_NODE}${OPM_DELIM}${dependency_array}"
                    npm_queue_array="${npm_package}${OPM_DELIM}${npm_queue_array}"
                fi
            elif [ "$pip_package" != "%" ]; then
                if [ "$opm_pip" -ne 0 ] || [ "$will_install_pip" -ne 0 ]; then
                    pip_queue_array="${pip_package}${OPM_DELIM}${pip_queue_array}"
                elif [ "$opm_pip" -eq 0 ] && [ "$will_install_pip" -eq 0 ]; then
                    dependency_array="${OPM_DEFAULT_PYTHON}${OPM_DELIM}${dependency_array}"
                    pip_queue_array="${pip_package}${OPM_DELIM}${pip_queue_array}"
                fi
            elif [ "$gem_package" != "%" ]; then
                if [ "$opm_gem" -ne 0 ] || [ "$will_install_gem" -ne 0 ]; then
                    gem_queue_array="${gem_package}${OPM_DELIM}${gem_queue_array}"
                elif [ "$opm_gem" -eq 0 ] && [ "$will_install_gem" -eq 0 ]; then
                    dependency_array="${OPM_DEFAULT_GEM}${OPM_DELIM}${dependency_array}"
                    gem_queue_array="${gem_package}${OPM_DELIM}${gem_queue_array}"
                fi
            elif [ "$source_package" != "%" ]; then
                source_queue_array="${package}${OPM_DELIM}${source_queue_array}"
            else
                warn "$package cannot be installed on this system."
            fi
        fi
    done

    if [ -n "$dependency_array" ]; then
        IFS="${OPM_DELIM}"
        for dependency in ${dependency_array}; do
            if [ "$opm_apt" -ne 0 ]; then
                info "Will install ${dependency} via APT as a dependency."
                apt_queue_array="${dependency}${OPM_DELIM}${apt_queue_array}"
            elif [ "$opm_zypper" -ne 0 ]; then
                info "Will install ${dependency} via Zypper as a dependency."
                zypper_queue_array="${dependency}${OPM_DELIM}${zypper_queue_array}"
            elif [ "$opm_dnf" -ne 0 ]; then
                info "Will install ${dependency} via DNF as a dependency."
                dnf_queue_array="${dependency}${OPM_DELIM}${dnf_queue_array}"
            else
                info "Will install ${dependency} from source as a dependency."
                source_queue_array="${dependency}${OPM_DELIM}${source_queue_array}"
            fi
        done
        IFS=' '
    fi

    apt_queue_string="$(printf '%s' "$apt_queue_array" | tr "${OPM_DELIM}" " ")"
    zypper_queue_string="$(printf '%s' "$zypper_queue_array" | tr "${OPM_DELIM}" " ")"
    dnf_queue_string="$(printf '%s' "$dnf_queue_array" | tr "${OPM_DELIM}" " ")"
    npm_queue_string="$(printf '%s' "$npm_queue_array" | tr "${OPM_DELIM}" " ")"
    pip_queue_string="$(printf '%s' "$pip_queue_array" | tr "${OPM_DELIM}" " ")"
    gem_queue_string="$(printf '%s' "$gem_queue_array" | tr "${OPM_DELIM}" " ")"
    source_queue_string="$(printf '%s' "$source_queue_array" | tr "${OPM_DELIM}" " ")"

    info "Queued packages:"
    none "APT: ${apt_queue_string}"
    none "Zypper: ${zypper_queue_string}"
    none "DNF: ${dnf_queue_string}"
    none "NPM: ${npm_queue_string}"
    none "Pip: ${pip_queue_string}"
    none "Gem: ${gem_queue_string}"
    none "Source: ${source_queue_string}"
}

opm_describe() {
    if [ "$#" -ne 1 ]; then
        error "You must specify a package."
        abort
    fi

    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    result="$(awk -F';' "BEGIN{IGNORECASE = 1}\$1 ~ /^$1$/ { print };" lookup)"

    if [ -n "$result" ]; then
        name="$(echo "$result" | awk -F';' '{ print $1 };')"
        description="$(echo "$result" | awk -F';' '{ print $6 };')"
        info "Name: \t\t$name"
        none "Description: \t$description"
        none "Support: \t\t" "" 1
        opm_print_enabled "$(opm_get_column_code "$result" "apt")" "apt"
        opm_print_enabled "$(opm_get_column_code "$result" "dnf")" "dnf"
        opm_print_enabled "$(opm_get_column_code "$result" "zypper")" "zypper"

        opm_print_enabled "$(opm_get_column_code "$result" "npm")" "npm"
        opm_print_enabled "$(opm_get_column_code "$result" "pip")" "pip"
        opm_print_enabled "$(opm_get_column_code "$result" "gem")" "gem"

        opm_print_enabled "$(opm_get_column_code "$result" "source")" "source"

        if [ "$opt_opm_quiet" -eq 0 ]; then
            printf '\n'
        fi
    else
        warn "No entries were found for $1."
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

opm_version

opm_init

opm_fetch

opm_refresh

opm_describe jdk
opm_describe jdk8
opm_describe ternjs
opm_describe TERNJS
opm_describe nvm
opm_describe tern

opm_query jdk
opm_query jdk java
opm_query JDK JAVA

opm_queue jdk8 git
opm_queue ternjs

opm_install jdk10 nvm

opm_upgrade
