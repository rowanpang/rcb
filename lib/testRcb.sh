#!/bin/bash

cbTestOps="write,read,delete"
cbObjSize="4k,16k,256k,1m"
cbTdir="./cbTest"

cbdir="/root/cosbench/0.4.2.c4"

rcbResCSV="./rcbResult.csv"
rcbcsvHeader="stage-iops-bw-lat"

cbResDirPfx="cbRes-"
cbResCalcPfx="cbRes-w*-"

function rcbcsvInit(){
    if ! [ -s $rcbResCSV ];then
	pr_hint "[init] cb result csv: $rcbResCSV"
	echo "${rcbcsvHeader//-/,}" > $rcbResCSV
    else
	pr_hint "[appent] to cb result csv: $rcbResCSV"
	echo "${rcbcsvHeader//-/,}" >> $rcbResCSV
	echo "${rcbcsvHeader//-/,}" >> $rcbResCSV
    fi
}

function rcbcsvAppend(){
    line=$@

    echo -en "\t$rcbcsvHeader: "
    for res in $line;do
	echo -en "$res\t"
    done
    echo

    echo ${line// /,} >> $rcbResCSV
}

function docbOnCtrlC(){
    verbose=7
    [ $verbose -ge 1 ] && echo "Ctrl+c captured"

    echo -e "\e[0m"
    echo -e '\e[?25h'

    if [ X$wkid != X ];then
        docbCancel
    fi

    doClean
    exit 1
}

function docbInit() {
    trap 'docbOnCtrlC' INT

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
    topdirInit "rcbTest"
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
	res=`echo $line | awk 'BEGIN {FS=","} { print $6}'`
	iops=`echo $line | awk 'BEGIN {FS=","} { print $14}'`
	bw=`echo $line | awk 'BEGIN {FS=","} { print $15/1024/1024}'`
	stage="$stage($opName)"


	[ $verbose -ge 1 ] && echo "$stage $res $iops $opType --"

	if ! [ X$opType == Xread -o X$opType == Xwrite ] ;then
	    [ $verbose -ge 3 ] && echo -n "not read/write, skip? "
	    if [ $i -eq 0 ];then
		# i==0, not int calc stage,skip it
		[ $verbose -ge 3 ] && echo 'yes'
		continue
	    fi
	    postCont="True"
	    # i!=0, int calc stage,need do lat resAvg
	    [ $verbose -ge 3 ] && echo 'no,need do resAvg .eg'
	fi

	if [ X$stage == X$lstage ];then
	    ((i++));
	    iopsSum=`echo "scale=2;$iopsSum+$iops" | bc`
	    bwSum=`echo "scale=2;$bwSum+$bw" | bc`
	    resSum=`echo "scale=2;$resSum+$res" | bc`
	else
	    #$lstage != NULL, and $statge != $lstage indicate
	    #lstage finished, do final calc,exp resAvg
	    if [ X$lstage != X ];then
		resAvg=`echo "scale=2;$resSum/$i"| bc`
		rcbcsvAppend $lstage $iopsSum $bwSum $resAvg
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
	    resSum=$res
	    lstage=$stage
	fi
	[ $verbose -ge 2 ] && echo "cur iopsSum:$iopsSum bwSum:$bwSum resSum:$resSum"
    done < $csvFile

    #file finished by read/write type stage. need do calc
    if [ $i -ge 1 ];then
	resAvg=`echo "scale=2;$resSum/$i"| bc`
	rcbcsvAppend $lstage $iopsSum $bwSum $resAvg
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
    tmpPrefix=4k
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
	size=${name%-*}
	if [ X$tmpPrefix == X$size ];then
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

	src=`ls $dir/$tmpPrefix-$op* 2>/dev/null`
	if [ X$src == X ];then
	    pr_warn "template '$dir/$tmpPrefix-$op*' not exist,skip"
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
