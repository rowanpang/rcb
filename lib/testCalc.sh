#!/bin/bash

calcDir="./"
calcTgt="rcb/rfio"

function doCalcOpts(){
    tCfgDir=$calcDir
    testOps=$calcTgt

    optParser $@

    tgtDir=$tCfgDir
    calcTgt=$testOps

    case $calcTgt in
	rcb)
	    pfx=$cbResCalcPfx
	    sizes=$cbObjSize
	    ;;
	rfio)
	    pfx=$cbResDirPfx
	    sizes=$cbObjSize
	    ;;
	*)
	    pr_err "calc target should be [rcb or rfio]"
	    exit -1
	    ;;
    esac
}

function doCalcInit() {
    doCalcOpts $@

    commInit
    initHostName
}

function doCalcCmd(){
    pr_debug "in func doCalcCmd"

    doCalcInit $@
    doSysCalc $pfx "$strHostNames " "$pressHostNames " $sizes

    pr_debug "out func doCalcCmd"
}

function testMain(){
    source ./lib/comm.sh
    doCalcCmd
}

[ X`basename $0` == Xtestcalc.sh ] && testMain
