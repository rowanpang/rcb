#!/bin/bash

cbTestOps="write,read,delete"
cbObjSize="4k,16k,256k,1m"
cbTdir="./cbTest"

cbdir="/root/cosbench/0.4.2.c4"

rcbcsvHeader="stage-iops-bw-lat"

cbResDirPfx="cbRes-"
cbResCalcPfx='cbRes-w*-'

cbIssueMaxRunSecs="1200"

function rcbcsvInit(){
    rcbResCSV="${topdir:-.}/rcbResult.csv"
    if ! [ -s $rcbResCSV ];then
	pr_hint "cb result csv [init] : $rcbResCSV"
	echo "${rcbcsvHeader//-/,}" > $rcbResCSV
    else
	pr_hint "cb result csv [appent] : $rcbResCSV"
	echo "${rcbcsvHeader//-/,}" >> $rcbResCSV
	echo "${rcbcsvHeader//-/,}" >> $rcbResCSV
    fi

    rcbResCSVPer="${topdir:-.}/rcbResult.per.csv"
    if ! [ -s $rcbResCSVPer ];then
	pr_hint "cb result csv [init] : $rcbResCSVPer"
	echo "${rcbcsvHeader//-/,}" > $rcbResCSVPer
    else
	pr_hint "cb result csv [appent] : $rcbResCSVPer"
	echo "${rcbcsvHeader//-/,}" >> $rcbResCSVPer
	echo "${rcbcsvHeader//-/,}" >> $rcbResCSVPer
    fi
}

function rcbcsvAppend(){
    line=$@

    echo -en "\tfinal $rcbcsvHeader: "
    for res in $line;do
	echo -en "$res\t"
    done
    echo

    echo ${line// /,} >> $rcbResCSV
}

function rcbcsvAppendPer(){
    line=$@

    echo -en "\tper $rcbcsvHeader: "
    for res in $line;do
	echo -en "$res\t"
    done
    echo

    echo ${line// /,} >> $rcbResCSVPer
}
function docbOnCtrlC(){
    verbose=1
    [ $verbose -ge 1 ] && echo "Ctrl+c captured"

    echo -e "\e[0m"
    echo -e '\e[?25h'

    if [ X$wkid != X ];then
        docbCancel
    fi

    doClean
    doCleanChk
    exit 1
}

function docbInit() {
    trap 'docbOnCtrlC' INT
    topdirInit "logRCB"

    mkIssuesList $objSize $testOps $tCfgDir
    docbMkIssueXml $finIssues
    if ! [ -d $cbdir ];then
	echo "$cbdir not exist,exit 1"
	exit 1
    fi

    cbcli="$cbdir/cli.sh"
    if ! [ -s $cbcli ];then
	echo "$cbcli not exist,exit 1"
	exit 1
    fi

    commInit
    rcbcsvInit
}

function lineadj(){
    ln=$1
    lo=$2
    bs=""
    nsp=""

    lb=$ln
    if [ $ln -lt $lo ];then
	((ld=lo-ln))
	while [ $ld -ge 1 ];do
	    nsp="$nsp "
	    ((ld=ld-1))
	done
	echo -en "$nsp"

	lb=$lo
    fi

    while [ $lb -ge 1 ];do
	bs="$bs\\b"
	((lb=lb-1))
    done
    echo -en "$bs\b\b"
}

function docbcsvParser(){
    csvFile="$HOME/w570-s3-1m/w570-s3-1m.csv"
    csvFile="$HOME/w171-4m-read/w171-4m-read.csv"
    csvFile=$1

    hitHeader=""
    lstage=""
    i="0"

    if ! [ -s $csvFile ];then
	echo "$csvFile not exist,return"
	return
    fi

    while read line ;do
	if ! [ $hitHeader ];then
	    hitHeader=`echo $line | grep -c '^Stage,Op-Name,'`
	    [ $verbose -ge 1 ] && echo "hit header: $hitHeader"
	    continue
	fi

	stage=`echo $line | awk 'BEGIN {FS=","} { print $1}'`
	opName=`echo $line | awk 'BEGIN {FS=","} { print $2}'`
	opType=`echo $line | awk 'BEGIN {FS=","} { print $3}'`
	lat=`echo $line | awk 'BEGIN {FS=","} { print $6}'`
	iops=`echo $line | awk 'BEGIN {FS=","} { print $14}'`
	bw=`echo $line | awk 'BEGIN {FS=","} { print $15/1024/1024}'`
	stage="$stage($opName)"


	[ $verbose -ge 1 ] && echo "$stage $lat $iops $opType --"

	if ! [ X$opType == Xread -o X$opType == Xwrite ] ;then
	    [ $verbose -ge 3 ] && echo -n "not read/write, skip? "
	    if [ $i -eq 0 ];then
		# i==0, not int calc stage,skip it
		[ $verbose -ge 3 ] && echo 'yes'
		continue
	    fi
	    postCont="True"
	    # i!=0, int calc stage,need do lat latAvg
	    [ $verbose -ge 3 ] && echo 'no,need do latAvg .eg'
	fi

	if [ X$stage == X$lstage ];then
	    ((i++));
	    iopsSum=`echo "scale=2;$iopsSum+$iops" | bc`
	    bwSum=`echo "scale=2;$bwSum+$bw" | bc`
	    latSum=`echo "scale=2;$latSum+$lat" | bc`
	else
	    #$lstage != NULL, and $statge != $lstage indicate
	    #lstage finished, do final calc,exp latAvg
	    if [ X$lstage != X ];then
		latAvg=`echo "scale=2;$latSum/$i"| bc`
		rcbcsvAppend $lstage $iopsSum $bwSum $latAvg
		[ $verbose -ge 1 ] && echo "  new Stage: $stage "

		#if in postCont,indicate not read/write stage, just next line continue
		if [ X$postCont != X ];then
		    i=0
		    postCont=""
		    continue
		fi
	    else
		[ $verbose -ge 1 ] && echo "first Stage: $stage "
	    fi

	    #new stage,init sum
	    i=1
	    iopsSum=$iops
	    bwSum=$bw
	    latSum=$lat
	    lstage=$stage
	fi
	[ $verbose -ge 2 ] && echo "cur iopsSum:$iopsSum bwSum:$bwSum latSum:$latSum"

	rcbcsvAppendPer "$stage.driver$i" $iops $bw $lat
    done < $csvFile

    #file finished by read/write type stage. need do calc
    if [ $i -ge 1 ];then
	latAvg=`echo "scale=2;$latSum/$i"| bc`
	rcbcsvAppend $lstage $iopsSum $bwSum $latAvg
    fi
}

:<<EOF
    ./cli cmd output msg
    [root@as13kp9 0.4.2.c4]# ./cli.sh submit conf/workload-config.xml
	Accepted with ID: w428
    [root@as13kp9 0.4.2.c4]# ./cli.sh info
	Drivers:
	driver1	http://127.0.0.1:18088/driver
	driver2	http://127.0.0.1:18188/driver
	driver3	http://127.0.0.1:18288/driver
	Total: 3 drivers

	Active Workloads:
	w428	Wed Mar 06 14:14:21 CST 2019	PROCESSING	s1-init
	Total: 1 active workloads

    [root@as13kp9 0.4.2.c4]# ./cli.sh submit conf/workload-config.xml
	Accepted with ID: w429
    [root@as13kp9 0.4.2.c4]# ./cli.sh info
	Drivers:
	driver1	http://127.0.0.1:18088/driver
	driver2	http://127.0.0.1:18188/driver
	driver3	http://127.0.0.1:18288/driver
	Total: 3 drivers

	Active Workloads:
	w428	Wed Mar 06 14:14:21 CST 2019	PROCESSING	s2-prepare
	w429	Wed Mar 06 14:14:26 CST 2019	QUEUING	None
	Total: 2 active workloads

    [root@as13kp9 0.4.2.c4]#
EOF

function docbWkldChk() {
    while [[ "true" ]]; do
	curNum=$($cbcli info 2>/dev/null | grep active | awk '{print $2}')
	if [ X$curNum == X0 ];then
	    break
	else
	    echo "---cosbench has active work wait----"
	    sleep 2
	fi
    done
}

function docbCancel(){
    pr_debug "in func docbCancel wkid: $wkid"

    $cbcli cancel $wkid
}

function docbsubmit(){
    issue=$1
    echo -e "\033[0;1;31m--submit for issue $issue--\033[0m"
    tStart=`date '+%s'`

    ret=`$cbcli submit $issue 2>/dev/null`
    [ $verbose -ge 1 ] && echo "submit ret $ret"
    wkid=`echo $ret | awk '{print $4}'`
    sleep 1

    resDir="$topdir/$cbResDirPfx$wkid-$idtSuffix"
    if [ -d $resDir ];then
	echo "$resDir duplicate, mv to date +%s format"
	mv $resDir $resDir-`date +%s`
    fi
    mkdir $resDir

    #---->block start ===> not modify this block
    echo -ne '\e[?25l'
    echo -ne "\t--$wkid $issue running,escape "
    tdlo=0
    echo -ne "\e[0;1;31m"
    while [[ "true" ]]; do
	curNum=$( $cbcli info 2>/dev/null | grep active | awk '{print $2}')
	archiveDir=`ls -d $cbdir/archive/$wkid-* 2>/dev/null`
	if [ X$curNum == X0 -a "X$archiveDir" != X ];then
	    break
	fi
	tNow=`date '+%s'`
	let "tDur=tNow-tStart"
	tdln=${#tDur}
	echo -n "$tDur s"
	lineadj $tdln $tdlo
	tdlo=$tdln

	if [ $tDur -ge $cbIssueMaxRunSecs ];then
	    pr_warn "$wkid runtime great than $cbIssueMaxRunSecs,cancel it"
	    docbCancel
	fi
	sleep 1
    done
    echo -ne "\e[0m"
    echo -e '\e[?25h'
    #---->block end ===> not modify this block

    [ $verbose -ge 1 ] && echo "archiveDir --$archiveDir---"
    sleep 1;cp -r $archiveDir ./$resDir	    #wait log file and got it

    bName=`basename $archiveDir`
    csv="./$resDir/$bName/$bName.csv"
    [ $verbose -ge 1 ] && echo "csv file: $csv"

    if [ -z $dryRun ];then
       docbcsvParser $csv
    fi
}

function docbIssues() {
    issues="$@"
    preMon
    for issue in $issues ;do
	if ! [ -s $issue ];then
	    echo "test $issue file not exist skip "
	    sleep 3
	    continue
	fi

	[ $verbose -ge 1 ] && echo "--do cosbench for issue $issue---"

	#echo "do cosbench for issues $issue"
	# ./cbTest/10m-delete.xml
	idtSuffix=${issue##*/}		    #-->10m-delete.xml
	idtSuffix=${idtSuffix%.*}	    #-->10m-delete
	#echo $idtSuffix

	docbWkldChk
	startMon $idtSuffix
	if [ -z $dryRun ];then
	    docbsubmit	$issue
	fi
	stopMonGetRet
	sleep 1
    done
    postMon
}

function docbMkIssueXml(){
    fNamePfx=4k
    issues="$@"
    [ $verbose -ge 1 ] && echo "---in func docbMkIssueXml---"

    for issue in $issues;do
	toMk=$issue
	if [ -s $toMk ];then
	    [ $verbose -ge 1 ] && echo "$toMk exist,skip"
	    continue
	fi

	dir=`dirname $toMk`
	name=`basename $toMk`
	pfx=${name%-*}		#4k-xx  or rt4k-xx	-->4k/rt4k

	pfxTmp=$(echo $pfx | sed 's/[[:digit:]]\S\+$//')    #--> ''/rt
	size=$(echo $pfx | sed 's/^[[:alpha:]]\+//')	    #--> 4k

	[ X$pfxTmp != X ] && fNamePfx=${pfxTmp}4k

	if [ X$fNamePfx == X$pfx ];then
	    continue
	    [ $verbose -ge 1] && echo "tmpxml self,skip"
	fi
	val=`echo $size | tr -d '[:alpha:]'`
	unit=`echo $size | tr -d '[:digit:]'`
	case $unit in
	    k)
		unit=KB
		;;
	    m)
		unit=MB
		;;
	    *)
		echo "unit error $unit,exit 1"
		exit 1
		;;
	esac
	op=${name%.*};op=${op#*-}

	[ $verbose -ge 1 ] && echo "docbMkIssueXml for $toMk,name(op): $name($op)"

	src=`ls $dir/$fNamePfx-$op* 2>/dev/null`
	if [ X$src == X ];then
	    pr_warn "template '$dir/$fNamePfx-$op*' not exist,skip"
	    continue
	fi

	cp -f $src $toMk
	sed -i "s/4k/$size/; s/c(4)KB/c($val)$unit/" $toMk
    done
    [ $verbose -ge 1 ] && echo "---out func docbMkIssueXml---"
}

function dorcb() {
    objSize="$cbObjSize"
    testOps="$cbTestOps"
    tCfgDir="$cbTdir"
    optParser $@

    docbInit $@
    docbIssues $finIssues

    #hostname add a ' ' for empty host'
    doSysCalc $cbResCalcPfx "$strHostNames " "$pressHostNames " $objSize
}

function testMain(){
    source ./lib/comm.sh
    rcbcsvInit
    rcbcsvAppend 5 4 3 2
    rcbcsvAppend 5 4 3 2  1
}

[ X`basename $0` == XtestRcb.sh ] && testMain
