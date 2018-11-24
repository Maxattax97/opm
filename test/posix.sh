#! /bin/sh

. ../libopm.sh

opm_lookup_path="../lookup"
opm_opt_quiet=1
opm_opt_nocolor=1

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
