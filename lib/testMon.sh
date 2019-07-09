#!/bin/bash

monOps="stop"

function doMoninit() {
    topdirInit "mondirect"
    resDir="$topdir-`date +%s`"
    if [ -d $resDir ];then
	echo "$resDir duplicate, mv to date +%s format"
	mv $resDir $resDir-`date +%s`
    fi
    mkdir $resDir
    commInit
}

function cleanMon(){
    infos=`ls $nodeinfoFile* 2>/dev/null`
    for f in $infos;do
	pr_debug "do clean for $f"
	nodeinfoFile=$f
	doClean
	rmNodeinfofile
    done

    doCleanChk
}

function doMonDirect() {
    testOps="$monOps"
    optParser $@
    doMoninit $@

    if [ "X$testOps" == "Xstart" ];then
	pr_hint "do mon start"
	preMon
	startMon 'mondirect'
    elif [ "X$testOps" == "Xstop" ];then
	pr_hint "do mon stop"
	stopMonGetRet
	postMon
    else
	pr_hint "do mon clean"
	cleanMon
    fi
}

function testMain(){
    source ./lib/testMon.sh
    echo "hello mon direct "
}

[ X`basename $0` == XtestRcb.sh ] && testMain
