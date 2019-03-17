#!/bin/bash

calcDir="./"
calcTgtType="rcb/rfio"

function doCalcOpts(){
    objSize=""
    tCfgDir=$calcDir
    testOps=$calcTgtType

    optParser $@

    calcTgtDir=$tCfgDir
    calcTgtType=$testOps

    case $calcTgtType in
	rcb)
	    pfx=$cbResCalcPfx
	    sizes=$cbObjSize
	    ;;
	rfio)
	    pfx=$fioResDirPfx
	    sizes=$fioObjSize
	    ;;
	*)
	    pr_err "calc target should be [rcb or rfio]"
	    exit -1
	    ;;
    esac

    [ X$objSize != X ] && sizes=$objSize
}

function doCalcInit() {
    doCalcOpts $@

    commInit
}

function doCalcCmd(){
    pr_hint "doCmd doCalcCmd"
    doCalcInit $@
    doSysCalc $pfx "$strHostNames " "$pressHostNames " $sizes

    pr_debug "out func doCalcCmd"
}

function testMain(){
    source ./lib/comm.sh
    doCalcCmd
}

[ X`basename $0` == Xtestcalc.sh ] && testMain
