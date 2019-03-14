#!/bin/bash

calcDir="./"
calcTgt="rcb/rfio"

function doCalcInit() {
    tCfgDir=$calcDir
    testOps=$calcTgt

    optParser $@
    commInit

    tgtDir=$tCfgDir
    calcTgt=$testOps

    case $calcTgt in
	rcb)
	    pfx=$cbResDirPfx
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
