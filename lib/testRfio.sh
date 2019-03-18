#!/bin/bash

fioTestOps="rand-write,seq-write,rand-read,seq-read,rand-rw,seq-rw"
fioObjSize="4k,16k,64k,512k,1m"
fioTdir="./fioT-rbd"

fioResDirPfx="fioR-"
fioResCalcPfx='fioR-*-'

fioClients=""
fServerNodes="
    172.16.18.219
    172.16.18.217
"
fServerNodesIssueChange="
    rbdname=,volume-22a42fb0e3414d869a5d5983d7d23cb3#pool=,pool-bcea376d9b7648df96cb4cf285e12e3A
    rbdname=,volume-22a42fb0e3414d869a5d5983d7d23cb7
"

rfioSvrWorkDir="/tmp/rfioServer-22a42fb0e"
rfioSvrPidfileName="fioServerPid.log"

rfiocsvHeader="stage-iops-bw-latAvg-latStd"

function rfiocsvInit() {
    #function_body
    rfioResCSV="${topdir:-.}/rcbResult.csv"
    if ! [ -s $rfioResCSV ];then
	pr_hint "rfio result csv [init] : $rfioResCSV"
	echo "${rcbcsvHeader//-/,}" > $rfioResCSV
    else
	pr_hint "rfio result csv [appent] : $rfioResCSV"
	echo "${rcbcsvHeader//-/,}" >> $rfioResCSV
	echo "${rcbcsvHeader//-/,}" >> $rfioResCSV
    fi

    rfioResCSVPer="${topdir:-.}/rcbResult.per.csv"
    if ! [ -s $rfioResCSVPer ];then
	pr_hint "rfio result csv [init] : $rfioResCSVPer"
	echo "${rcbcsvHeader//-/,}" > $rfioResCSV
    else
	pr_hint "rfio result csv [appent] : $rfioResCSVPer"
	echo "${rcbcsvHeader//-/,}" >> $rfioResCSVPer
	echo "${rcbcsvHeader//-/,}" >> $rfioResCSVPer
    fi
}

function rfiocsvAppend(){
    line=$@

    echo -en "\trfio final $rfiocsvHeader: "
    for res in $line;do
	echo -en "$res\t"
    done
    echo

    echo ${line// /,} >> $rfioResCSV
}

function rfiocsvAppendPer(){
    line=$@

    echo -en "\tper $rfiocsvHeader: "
    for res in $line;do
	echo -en "$res\t"
    done
    echo

    echo ${line// /,} >> $rfioResCSVPer
}

function dofioOnCtrlC(){
    verbose=1
    [ $verbose -ge 1 ] && echo "Ctrl+c captured"

    doClean
    doCleanChk

    fServerStop
    exit 1
}

function fServerStart(){
    [ X$multiRfio == X ] && return

    pr_debug "in func fServerStart"
    echo "fio Servers to use are:$fServerNodes"
    if ! [ -z $dryRun ];then
	[ $verbose -ge 1 ] && echo -e "\t--fServerStart dryRun return---"
	return
    fi

    rfioSvrCmd="fio --server --daemonize=$rfioSvrPidfileName"

    sshChk $fServerNodes
    for node in $fServerNodes;do
	sshpass -p $(gotNodePwd $node) ssh $node "command -v fio >/dev/null 2>&1|| yum --assumeyes install fio"
	sshpass -p $(gotNodePwd $node) ssh $node "mkdir -p $rfioSvrWorkDir >/dev/null 2>&1"
	sshpass -p $(gotNodePwd $node) ssh $node "cd $rfioSvrWorkDir && $rfioSvrCmd >/dev/null 2>&1"
    done
    pr_debug "out func fServerStart"
}

function fServerStop(){
    [ X$multiRfio == X ] && return
    pr_debug "in func fServerStop"

    if ! [ -z $dryRun ];then
	[ $verbose -ge 1 ] && echo -e "\t--fServerStart dryRun return---"
	return
    fi

    for node in $fServerNodes;do
	sshpass -p $(gotNodePwd $node) ssh $node "cd $rfioSvrWorkDir && rfioPid=\$(cat $rfioSvrPidfileName) && kill \$rfioPid >/dev/null 2>&1"
	sshpass -p $(gotNodePwd $node) ssh $node "rm -rf $rfioSvrWorkDir"
    done

    pr_debug "out func fServerStop"
}

function fServerMkIssue(){
    [ X$multiRfio == X ] && return
    pr_debug "in func fServerMkIssue"
    src=$1
    dst=$2
    idx=$3

    cp -f $src $dst

    i=1
    for chgs in $fServerNodesIssueChange;do
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
    [ X$multiRfio == X ] && return
    pr_debug "in func fServerSubmit"

    issue=$1
    i=1
    dir=`dirname $issue`
    name=`basename $issue`
    fioClients=""

    for node in $fServerNodes;do
	if ! [ -z $dryRun ];then
	    nName=host$i
	else
	    nName=`sshpass -p $(gotNodePwd $node) ssh $node hostname`
	fi

	resfile="$resDir/fioL-$idtSuffix.log.$nName"

	issueNew="$dir/rfioSvr$i-$name"
	fServerMkIssue $issue $issueNew $i
	((i++))

	if ! [ -z $dryRun ];then
	    [ $verbose -ge 1 ] && echo -e "\t--fServerSubmit dryRun continue---"
	    continue
	fi
	fio --output $resfile --client $node $issueNew >/dev/null 2>&1 &
	fioClients="$fioClients $!"
    done

    pr_debug "out func fServerSubmit"
}

function fServerWkChk() {
    [ X$multiRfio == X ] && return
    while [ "TRUE" ];do
	toChk=""

	for cli in $fioClients;do
	    ps $cli
	    [ $? -eq 0 ] && toChk="$toChk $cli"
	done

	[ X"$toChk" == X ] && break

	pr_warn "fio Clients $toChk still running,wait"
	fioClients=$toChk
	sleep 1
    done
}

function rfioDepChk() {
    cmdChkInstall fio

    rbdso=`ldconfig -p | grep librbd 2>/dev/null`

    if [ X"$rbdso" == X ];then
	want=`promptdefIgnore "librbd.so not exist chk it?"`
	[ X$want == X ] && pr_debug "ignore it" || pr_err "librbd not exist"
    fi
}

function dofioInit(){
    trap 'dofioOnCtrlC' INT

    commInit
    rfioDepChk

    topdirInit "rfioTest"
    rfiocsvInit

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


    doSysCalc "$fioResCalcPfx" "$strHostNames " "$pressHostNames " $objSize
}

function iopsbwParserLine() {
    line="$1"
    ops=`echo $line | awk '{print $3}'`
    ops=${ops%,};ops=${ops#*=}

    opsVal=`echo $ops | tr -d '[:alpha:]' `
    opsUnit=`echo $ops | tr -d '[:digit:]'.`
    pr_devErr "opsVal-opsUnit: $opsVal-$opsUnit"

    case $opsUnit in
	k|K)
	   opsVal=`echo "scale=2;$opsVal*1000" | bc `
	   ;;
    esac

    bw=`echo $line | awk '{print $4}'`
    bw=${bw#*=}

    bwVal=`echo $bw | tr -d '[:alpha:]/'`
    bwUnit=`echo $bw | tr -d '[:digit:]'.`
    pr_devErr "bwVal-bwUnit: $bwVal-$bwUnit"

    case $bwUnit in
	MiB/s)
	   ;;
    esac
    pr_devErr echo "iops-bw: $ops - $bw"

    echo "$opsVal,$bwVal"
}

function latAvgStdParserLine() {
    line="$1"

    unit=`echo $line | awk '{print $3}'`
    unit=`echo $unit | tr -d '():'`

    avg=`echo $line | awk '{print $6}' `
    avgVal=${avg%,};avgVal=${avgVal#*=}

    std=`echo $line | awk '{print $7}' `
    stdVal=${std%,};stdVal=${stdVal#*=}

    pr_devErr "unit-avgVal-stdVal: $unit-$avgVal-$stdval"

    case $unit in
	usec)
	    avgVal=`echo "scale=2;$avgVal/1000" | bc`
	    stdVal=`echo "scale=2;$stdVal/1000" | bc`
	    ;;
    esac
    #function_body

    echo "$avgVal,$stdVal"
}

function dorfioCalcRes() {
    idt=$1
    pfx=$2

    pr_debug "in func dorfioCalcRes"

    files=`ls $pfx* 2>/dev/null`
    [ X"$files" == X ] && pr_err "dorfioCalcRes res file not exist,fpx $pfx"

    opsValSum=0
    bwValSum=0
    avgValSum=0
    stdValSum=0
    i=0
    for f in $files;do
	hidt=${f#*.}
	iopsline=`grep -m 1 ' IOPS' $f`
	pr_devErr "$iopsline"

	opbw=`iopsbwParserLine "ALIGN $iopsline"`	    #add ALIGN word to align with grep multi files
	opsVal=${opbw%,*}
	bwVal=${opbw#*,}

	opsValSum=`echo "scale=2; $opsValSum+$opsVal" | bc `
	bwValSum=`echo "scale=2; $bwValSum+$bwVal" | bc `

	latline=`grep -m 1 ' lat ' $f`

	if [ X"$latline" != X ];then
	    ((i++))
	    avgstd=`latAvgStdParserLine "ALIGN $latline"`
	    avgVal=${avgstd%,*}
	    stdVal=${avgstd#*,}

	    avgValSum=`echo "scale=2; $avgValSum+$avgVal" | bc `
	    stdValSum=`echo "scale=2; $stdValSum+$stdVal" | bc `
	fi

	rfiocsvAppendPer "$idt.$hidt,$opsVal,$bwVal,$avgVal,$stdVal"
    done

    avgVal=`echo "scale=2;$avgValSum/$i" | bc`
    stdVal=`echo "scale=2;$stdValSum/$i" | bc`

    rfiocsvAppend "$idt,$opsValSum,$bwValSum,$avgVal,$stdVal"

    pr_debug "out func dorfioCalcRes"
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
    resDir="$topdir/$fioResDirPfx$devType-${idtSuffix}"
    if [ -d $resDir ];then
        echo "$resDir duplicate, mv to date +%s format"
        mv $resDir $resDir-`date +%s`
    fi
    mkdir $resDir

    fServerSubmit $issue

    resLog="$resDir/fioL-$idtSuffix.log"
    [ $verbose -ge 1 ] && echo "resLogfile: $resLog"
    fio $issue --output $resLog

    fServerWkChk

    echo

    dorfioCalcRes $idtSuffix $resLog
}

function dofioIssues() {
    issues="$@"
    preMon
    for issue in $issues ;do
	if ! [ -s $issue ];then
	    pr_warn "test $issue file not exist skip "
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
    multiRfio="yes"
    fServerStart
    fServerSubmit ./fioT-rbd/4k-rand-rw
    sleep 50
    fServerStop
}

[ X`basename $0` == XtestRfio.sh ] && testMain
