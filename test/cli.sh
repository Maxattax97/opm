#! /bin/sh

testLazyLoad() {
    assertNull "OPM version leak detected" "$OPM_LIB_VERSION"    
    opm_cli
    opm_lookup_path="../pool.db"
    assertNotNull "OPM failed to lazy load" "$OPM_LIB_VERSION"    
}

oneTimeSetUp() {
    . ../opm

    opm_lookup_path="../pool.db"
}

. ./shunit2
