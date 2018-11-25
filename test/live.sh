#! /bin/sh

testInit() {
    opm_init
    sum_managers="$(expr $opm_apt + $opm_dnf + $opm_dnf + $opm_zypper + \
        $opm_portage + $opm_slackpkg + $opm_nix + $opm_npm + \
        $opm_gem + $opm_pip)"
    assertNotEquals "0" "$sum_managers"
    assertEquals "1" "$opm_init_complete"
}

testVersion() {
    result="$(opm_version)"
    assertSame "[~] Omni Package Manager v${OPM_LIB_VERSION}" "$result"
}

testInstallGit() {
    command -v git
    assertNotEquals "Git already installed" "0" "$?"
    opm_install git
    command -v git
    assertEquals "Git was not installed" "0" "$?"
}

oneTimeSetUp() {
    . ../libopm.sh

    opm_lookup_path="../pool.db"
    # opm_opt_quiet=1
    opm_opt_nocolor=1
    opm_opt_noconfirm=1
    opm_opt_dry=0

    interpretter="$(ps h -p $$ -o args='' | cut -f1 -d' ')"
    interpretter_links_to="$(file "$(command -v "$interpretter")")"
    echo "Being interpretted by: $interpretter_links_to"
}

. ./shunit2
