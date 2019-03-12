#!/bin/bash

fioTestOps="rand-write,seq-write,rand-read,seq-read,rand-rw,seq-rw"
fioObjSize="4k,16k,64k,512k,1m"
fioTdir="./fioT-rbd"

fioClients=""
fioPressNodes="
    172.16.18.219
    172.16.18.217
"
fioPressNodesIssueChange="
    rbdname=,volume-22a42fb0e3414d869a5d5983d7d23cb3#pool=,pool-bcea376d9b7648df96cb4cf285e12e3A
    rbdname=,volume-22a42fb0e3414d869a5d5983d7d23cb7
"

rfioSvrWorkDir="/tmp/rfioServer-22a42fb0e"
rfioSvrPidfileName="fioServerPid.log"

function dofioOnCtrlC(){
    verbose=7
    [ $verbose -ge 1 ] && echo "Ctrl+c captured"

    doClean

    fServerStop
    exit 1
}

function fServerStart(){
    pr_debug "in func fServerStart"
    if ! [ -z $dryRun ];then
	[ $verbose -ge 1 ] && echo -e "\t--fServerStart dryRun return---"
	return
    fi

    rfioSvrCmd="fio --server --daemonize=$rfioSvrPidfileName"

    sshChk $fioPressNodes
    for node in $fioPressNodes;do
	sshpass -p $(gotNodePwd $node) ssh $node "command -v fio 2>&1 >/dev/null || yum --assumeyes install fio"
	sshpass -p $(gotNodePwd $node) ssh $node "mkdir -p $rfioSvrWorkDir 2>&1 >/dev/null"
	sshpass -p $(gotNodePwd $node) ssh $node "cd $rfioSvrWorkDir && $rfioSvrCmd 2>&1 >/dev/null"
    done
    pr_debug "out func fServerStart"
}

function fServerStop(){
    pr_debug "in func fServerStop"

    if ! [ -z $dryRun ];then
	[ $verbose -ge 1 ] && echo -e "\t--fServerStart dryRun return---"
	return
    fi

    echo "kill fio client with server: $fioClients"
    kill $fioClients

    for node in $fioPressNodes;do
	sshpass -p $(gotNodePwd $node) ssh $node "cd $rfioSvrWorkDir && rfioPid=\$(cat $rfioSvrPidfileName) && kill \$rfioPid 2>&1 >/dev/null"
	sshpass -p $(gotNodePwd $node) ssh $node "rm -rf $rfioSvrWorkDir"
    done

    pr_debug "out func fServerStop"
}

function fServerMkIssue(){
    pr_debug "in func fServerMkIssue"
    src=$1
    dst=$2
    idx=$3

    cp -f $src $dst

    i=1
    for chgs in $fioPressNodesIssueChange;do
	[ $i -eq $idx ] && break;
	((i++))
    done

    chgs=${chgs//#/ }

    for chg in $chgs;do
	chg=${chg//,/ }
	key=`echo $chg | awk '{print $1}'`
	sub=`echo $chg | awk '{print $2}'`

	sed -i "s#$key.*#$key$sub#" $dst
    done
    pr_debug "out func fServerMkIssue"
}

function fServerSubmit(){
    pr_debug "in func fServerSubmit"

    issue=$1
    i=1
    dir=`dirname $issue`
    name=`basename $issue`

    for node in $fioPressNodes;do
	if ! [ -z $dryRun ];then
	    nName=host$i
	else
	    nName=`sshpass -p $(gotNodePwd $node) ssh $node hostname`
	fi

	resfile="$resDir/fioL-$idtSuffix.log.$nName"

	issueNew="$dir/s$i-$name"
	fServerMkIssue $issue $issueNew $i
	((i++))

	if ! [ -z $dryRun ];then
	    [ $verbose -ge 1 ] && echo -e "\t--fServerSubmit dryRun continue---"
	    continue
	fi
	fio --output $resfile --client $node $issueNew 2>&1 >/dev/null &
	fioClients="$fioClients $!"
    done

    [ X"$fioPressNodes" != X ] && sleep 5
    pr_debug "out func fServerSubmit"
}

function dofioInit(){
    trap 'dofioOnCtrlC' INT

    commInit
    cmdChkInstall fio

    echo "fio Servers to use are:$fioPressNodes"

    fServerStart
}

function dorfio(){
    objSize="$fioObjSize"
    testOps="$fioTestOps"
    tCfgDir="$fioTdir"
    optParser $@

    dofioInit
    mkIssuesList $objSize $testOps $tCfgDir

    dofioIssues $finIssues
    fServerStop
}

function dofiosubmit() {
    issue=$1
    echo -e "\033[0;1;31m--do dofiosubmit for issue $issue --\033[0m"

    if ! [ -z $dryRun ];then
	[ $verbose -ge 1 ] && echo -e "\t--dofiosubmit dryRun return---"
	return
    fi

    #fio-rbd/fioT-4k-rw.txt
    dirName=`dirname $issue`
    devType=${dirName#*-}
    resDir="fioR-$devType-${idtSuffix//-/_}-`date +%s`"
    if [ -d $resDir ];then
        echo "$resDir duplicate, mv to date +%s format"
        mv $resDir $resDir-`date +%s`
    fi
    mkdir $resDir

    fServerSubmit $issue

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
    preMon
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
	dofiosubmit $issue
	stopMonGetRet
	sleep 1
    done
    postMon
}

function testMain(){
    source ./lib/comm.sh
    verbose=7
    dryRun="yes"
    fServerStart
    fServerSubmit ./fioT-rbd/4k-rand-rw
    sleep 50
    fServerStop
}

[ X`basename $0` == XtestRfio.sh ] && testMain
