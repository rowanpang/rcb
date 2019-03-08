#!/bin/bash

fioTestOps="rand-write,rand-read,rand-rw"
fioObjSize="4k,16k,64k,512k,1m"
fioTdir="./fioT-rbd"

function dofioOnCtrlC(){
    [ $verbose -ge 1 ] && echo "Ctrl+c captured"

    doClean
    exit 1
}


function dofioInit(){
    trap 'dofioOnCtrlC' INT

    commInit
}

function dorfio(){
    objSize="$fioObjSize"
    testOps="$fioTestOps"
    tCfgDir="$fioTdir"
    optParser $@

    dofioInit
    mkIssuesList $objSize $testOps $tCfgDir
    dofioIssues $finInssues
}

function dofiosubmit() {
    issue=$1
    echo -e "\033[0;1;31m--do dofio for issue $issue--\033[0m"

    #fio-rbd/fioT-4k-rw.txt
    dirName=`dirname $issue`
    devType=${dirName#*-}
    resDir="fio-$devType-res-${idtSuffix//-/_}-`date +%s`"
    if [ -d $resDir ];then
        echo "$resDir duplicate, mv to date +%s format"
        mv $resDir $resDir-`date +%s`
    fi
    mkdir $resDir

    resLog="$resDir/fioL-$idtSuffix.log"
    [ $verbose -ge 1 ] && echo "resLogfile: $resLog"

    fio $issue --output $resLog

    echo
    resTxt=`grep ': IOPS=' $resLog`
    echo -e "\t$resTxt"
    resTxt=`grep ' lat' -m 1 $resLog`
    echo -e "\t$resTxt"
    echo
}

function dofioIssues() {
    issues="$@"
    for issue in $issues ;do
	if ! [ -s $issue ];then
	    echo "test $issue file not exist skip "
            sleep 3
            continue
	fi

	[ $verbose -ge 1 ] && echo "--do fio for issue $issue---"

	#fioT-blk/fioT-randR-4k-10G-10Job.txt
	idtSuffix=${issue##*/}		    #fioT-xx.txt
	idtSuffix=${idtSuffix%.*}	    #fioT-xx
	startMon $idtSuffix
	if [ -z $dryRun ];then
	    dofiosubmit $issue
	fi
	stopMonGetRet
	sleep 1
    done
    postMon
}

function dofio() {
    preMon
    if [ X$optIssues != X ];then
	issues=$optIssues
    else
	#根据testType 构造issue fileNames
	if [ X$testType == X ];then
	    echo "testType NONE error,exit"
	    exit
	fi
	issuesNew=""
	for issue in $issues ;do
	    issuesNew="$issuesNew fioT-$testType/$issue"
	done
	issues=$issuesNew
    fi

    echo "finally issues:
	$issues
    "
    dofioIssues "$issues"
}
