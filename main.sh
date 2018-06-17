#! /bin/dash

if [ -n "$OPM_LIB_VERSION" ]; then
    # Prevent source loops
    echo "Aborting excessive source"
    exit
fi

# Constants
export OPM_LIB_VERSION="0.0.1"

OPM_GREEN='\033[0;92m'
OPM_BLUE='\033[0;94m'
OPM_RED='\033[0;91m'
OPM_YELLOW='\033[0;93m'
OPM_RESET='\033[0m'

OPM_REPO_RAW_ROOT="https://raw.githubusercontent.com/Maxattax97/opm"
OPM_REPO_ROOT="https://github.com/Maxattax97/opm"

OPM_DELIM=':'

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

opm_queue_index=0
opm_queue_array=

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
        "appimage") column=17;;
        "source") column=18;;
        (*[!0-9]*|'') column="$2";;
        *) error "Invalid column: $2" && opm_abort;;
    esac

    value="$(echo "$1" | awk -F',|;' "{ print \$${column} };" | cut -c1-1)"
    if [ "$value" = '%' ]; then
        echo "0"
    elif [ "$value" = '!' ]; then
        echo "2"
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

    apt_queue_index=0
    apt_queue=
    zypper_queue_index=0
    zypper_queue=
    dnf_queue_index=0
    dnf_queue=

    source_queue_index=0
    source_queue=

    npm_queue_index=0
    npm_queue=
    pip_queue_index=0
    pip_queue=
    gem_queue_index=0
    gem_queue=

    for package in "${opm_queue_array[@]}"; do
        echo "$package"

        # 1 NAME;
        # 2 apt,zypper,dnf,pacman,portage,slackpkg,pkg,nix,apk;
        # 3 npm,pip,gem,cargo,go,cabal;
        # 4 flatpak,snap,appimage;
        # 5 source;
        # 6 DESCRIPTION

        result_line="$(grep -m 1 -E "^${package};" lookup)"

        apt_package="$(echo "$result_line" | awk -F',|;' '{ print $2 }')"
        zypper_package="$(echo "$result_line" | awk -F',|;' '{ print $3 }')"
        dnf_package="$(echo "$result_line" | awk -F',|;' '{ print $4 }')"

        npm_package="$(echo "$result_line" | awk -F',|;' '{ print $11 }')"
        pip_package="$(echo "$result_line" | awk -F',|;' '{ print $12 }')"
        gem_package="$(echo "$result_line" | awk -F',|;' '{ print $13 }')"

        source_package="$(echo "$result_line" | awk -F',|;' '{ print $20 }')"

        if [ "$opm_apt" -ne 0 ] && [ "$apt_package" != "%" ]; then
            apt_queue["$apt_queue_index"]="$apt_package"
            apt_queue_index="$(expr $apt_queue_index + 1)"
        elif [ "$opm_zypper" -ne 0 ] && [ "$zypper_package" != "%" ]; then
            zypper_queue["$zypper_queue_index"]="$zypper_package"
            zypper_queue_index="$(expr $zypper_queue_index + 1)"
        elif [ "$opm_dnf" -ne 0 ] && [ "$dnf_package" != "%" ]; then
            dnf_queue["$dnf_queue_index"]="$dnf_package"
            dnf_queue_index="$(expr $dnf_queue_index + 1)"
        elif [ "$opm_npm" -ne 0 ] && [ "$npm_package" != "%" ]; then
            npm_queue["$npm_queue_index"]="$npm_package"
            npm_queue_index="$(expr $npm_queue_index + 1)"
        elif [ "$opm_pip" -ne 0 ] && [ "$pip_package" != "%" ]; then
            pip_queue["$pip_queue_index"]="$pip_package"
            pip_queue_index="$(expr $pip_queue_index + 1)"
        elif [ "$opm_gem" -ne 0 ] && [ "$gem_package" != "%" ]; then
            gem_queue["$gem_queue_index"]="$gem_package"
            gem_queue_index="$(expr $gem_queue_index + 1)"
        else
            warn "$package can not be installed on this system."
        fi
    done

    info "APT: ${apt_queue[*]}"
    info "Zypper: ${zypper_queue[*]}"
    info "DNF: ${dnf_queue[*]}"
    info "NPM: ${npm_queue[*]}"
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
            opm_elevate apt-get $args update &
            jobs="${!}${OPM_DELIM}${jobs}"
            #jobs[job_count]=$!
            #job_count="$(expr 1 + $job_count )"
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
            jobs="${!}${OPM_DELIM}${jobs}"
            #jobs[job_count]=$!
            #job_count="$(expr 1 + $job_count )"
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
            jobs="${!}${OPM_DELIM}${jobs}"
            #jobs[job_count]=$!
            #job_count="$(expr 1 + $job_count )"
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

    info "Results for: $* \n$(echo "$results" | awk -F';' '{ print $1 "\t\t\t" $6 }')"
}

opm_queue() {
    if [ -z "$#" ]; then
        error "You must specify a list of terms to search with."
        abort
    fi

    if [ "$opm_init_complete" -eq 0 ]; then
        opm_init
    fi

    for i in "$@"; do
        opm_queue_array["$opm_queue_index"]="$i"
        opm_queue_index="$(expr $opm_queue_index + 1)"
    done

    info "Queued: ${opm_queue_array[*]}"
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
        info "Description: \t$description"
        info "Support:"
        opm_print_enabled "$(opm_get_column_code "$result" "apt")" "apt"
        opm_print_enabled "$(opm_get_column_code "$result" "dnf")" "dnf"
        opm_print_enabled "$(opm_get_column_code "$result" "zypper")" "zypper"

        opm_print_enabled "$(opm_get_column_code "$result" "npm")" "npm"
        opm_print_enabled "$(opm_get_column_code "$result" "pip")" "pip"
        opm_print_enabled "$(opm_get_column_code "$result" "gem")" "gem"

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

    warn "Not yet implemented."
}

opm_version() {
    info "Omni Package Manager v${OPM_LIB_VERSION}"
}

opm_version

opm_init

#opm_fetch

#opm_refresh

opm_describe jdk
opm_describe jdk8
opm_describe ternjs
opm_describe TERNJS
opm_describe nvm
opm_describe tern

opm_query jdk
opm_query jdk java

opm_queue jdk8
opm_queue jdk8 git

#opm_install jdk10 ternjs

#opm_upgrade
