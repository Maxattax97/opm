#! /bin/sh

. ../libopm.sh

opm_lookup_path="../pool.db"
opm_opt_quiet=1
opm_opt_nocolor=1

interpretter="$(ps h -p $$ -o args='' | cut -f1 -d' ')"
interpretter_links_to="$(file "$(which "$interpretter")")"
echo "Being interpretted by: $interpretter_links_to"

testInit() {
    opm_init
    sum_managers="$(expr $opm_apt + $opm_dnf + $opm_dnf + $opm_zypper + \
        $opm_portage + $opm_slackpkg + $opm_nix + $opm_npm + \
        $opm_gem + $opm_pip)"
    assertNotEquals "0" "$sum_managers"
    assertEquals "1" "$opm_init_complete"
}

testVersion() {
    opm_opt_quiet=0
    result="$(opm_version)"
    opm_opt_quiet=1
    assertSame "[~] Omni Package Manager v${OPM_LIB_VERSION}" "$result"
}

testQueue() {
    opm_queue nvm
    assertEquals "nvm_source:" "$opm_special_queue_array"
    opm_queue
}

. ./shunit2
