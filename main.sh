#! /bin/sh

# Constants
opm_lib_version=0.0.1

OPM_GREEN='\033[0;92m'
OPM_BLUE='\033[0;94m'
OPM_RED='\033[0;91m'
OPM_YELLOW='\033[0;93m'
OPM_RESET='\033[0m'

OPM_REPO_RAW_ROOT="https://raw.githubusercontent.com/Maxattax97/opm"
OPM_REPO_ROOT="https://github.com/Maxattax97/opm"

# Options
opt_opm_quiet=0
opt_opm_lock_sudo=1
opt_opm_parallel=1

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

# Logging
msg() {
    if [ "$opt_opm_quiet" -eq 0 ]; then
        printf '%b\n' "$1"
    fi
}

success() {
    msg "${OPM_GREEN}[*]${OPM_RESET} ${1}${2}"
}

info() {
    msg "${OPM_BLUE}[~]${OPM_RESET} ${1}${2}"
}

warn() {
    msg "${OPM_YELLOW}[!]${OPM_RESET} ${1}${2}"
}

error() {
    msg "${OPM_RED}[X]${OPM_RESET} ${1}${2}"
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
    if [ $EUID != 0 ]; then
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

opm_print_enabled() {
    if [ "$opt_opm_quiet" -eq 0 ]; then
        if [ "$1" -ne 0 ]; then
            printf "${OPM_GREEN}${2}${OPM_RESET} "
        else
            printf "${OPM_RED}${2}${OPM_RESET} "
        fi
    fi
}

# OPM Externals
opm_init() {
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

opm_version() {
    info "Omni Package Manager v${opm_lib_version}"
}

opm_refresh() {
    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    # TODO: Store processes in a list, execute all at once, check at end.
    # No gap to lose an exit code in.
    #jobs=()
    job_count=0

    if [ "$opm_apt" -ne 0 ]; then
        info "Refreshing APT ..."
        args=""
        if [ "$opt_quiet" -ne 0 ]; then
            args="$args --quiet"
        fi

        if [ "$opt_opm_parallel" -ne 0 ]; then
            opm_elevate apt-get $args update &
            jobs[job_count]=$!
            job_count="$(expr 1 + $job_count )"
        else
            opm_elevate apt-get $args update
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
            opm_elevate dnf $args check-update &
            jobs[job_count]=$!
            job_count="$(expr 1 + $job_count )"
        else
            opm_elevate dnf $args check-update
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
            opm_elevate zypper $args refresh &
            jobs[job_count]=$!
            job_count="$(expr 1 + $job_count )"
        else
            opm_elevate zypper $args refresh
            check "Zypper refreshed." "Zypper failed to refresh."
        fi
    fi

    # NPM refreshes on its own.
    # Gem refreshes on its own.
    # Pip refreshes on its own.

    opm_refresh_sudo

    failures=0
    for pid in ${jobs[*]}; do
        wait $pid || failures="$(expr $failures + 1)"
        opm_refresh_sudo
    done

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

    jobs=()
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

        opm_elevate apt-get $args upgrade
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

        opm_elevate dnf $args upgrade
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

        opm_elevate zypper $args up
        check "Zypper upgraded." "Zypper failed to upgrade."
    fi

    # NPM refreshes on its own.
    # Gem refreshes on its own.
    # Pip refreshes on its own.
}

opm_fetch() {
    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    # TODO: Upgrade all of OPM since some packages may need downloaded special instructions.
    # ... Unless we get smart and download those on the fly too... :?

    if [ "$opm_fetch_complete" -eq 0 ]; then
        if [ "$opm_wget" -ne 0 ]; then
            wget -O /tmp/OPM_UPDATE "${OPM_REPO_RAW_ROOT}/master/lookup"

            check "Fetched latest resources." "Failed to fetch resources."
            cp /tmp/OPM_UPDATE "$opm_lookup_path"
            opm_fetch_complete=1
        elif [ "$opm_curl" -ne 0 ]; then
            curl -o /tmp/OPM_UPDATE "${OPM_REPO_RAW_ROOT}/master/lookup"

            check "Fetched latest resources." "Failed to fetch resources."
            cp /tmp/OPM_UPDATE "$opm_lookup_path"
            opm_fetch_complete=1
        elif [ "$opm_git" -ne 0 ]; then
            git clone "${OPM_REPO_ROOT}" /tmp/opm/

            check "Fetched latest resources." "Failed to fetch resources."
            cp /tmp/opm/lookup "$opm_lookup_path"
            opm_fetch_complete=1
        else
            error "No tools are available on this system to fetch remote resources."
        fi
    else
        info "Skipping fetch since it was recently completed."
    fi
}

opm_clean() {
    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    warn "Not yet implemented."
}

opm_query() {
    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    warn "Not yet implemented."
}

opm_version

opm_init
opm_fetch
#opm_refresh
#opm_upgrade
