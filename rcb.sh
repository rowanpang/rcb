#!/bin/bash

#node to monitor
nodes=""
nodesPwds="
    127.0.0.1,IPS@jjfab2018
    192.168.100.100,IPS@jjfab2018
    192.168.100.101,IPS@jjfab2018
    192.168.100.102,IPS@jjfab2018
"

#ops name
issues="
    write
    read
    delete
"

monScript="./monitor.sh"
nodeinfos=""
nodeinfoFile='./nodeinfo.log'

SSHPSCP="sshpass -p \$(gotNodePwd \$node) scp"
SSHPSSH="sshpass -p \$(gotNodePwd \$node) ssh"

cbdir="/root/cosbench/0.4.2.c4"

function doInit() {
    command -v sshpass >/dev/null 2>&1 || yum install sshpass	    #need epel
    command -v fio >/dev/null 2>&1 || yum install fio

    for np in $nodesPwds;do
	n=${np%,*}
	nodes="$nodes $n"
    done

    node=$n
    #echo "--------$SSHPSCP"

    if ! [ -d $cbdir ];then
	echo "$cbdir not exist,exit 1"
	exit 1
    fi
}

function gotNodePwd(){
    node=$1
    [ -n $node ] || return
    npMatched=""
    for np in $nodesPwds;do
	if [ $node == `echo $np | awk 'BEGIN {FS=","} {print $1}'` ];then
	    #echo "match node:$node"
	    npMatched=$np
	    break
	fi
    done

    if [ -n $npMatched ];then
	pwd=`echo $npMatched | awk 'BEGIN {FS=","} {print $2}'`
    else
	return
    fi
    echo "$pwd"
}


function saveNodeinfo() {
    node=$1
    info=$2
    echo "do saveNodeinfo for node:$node,info:$info"
    for nodeinfo in $nodeinfos;do
	if [ $node == `echo $nodeinfo | awk 'BEGIN {FS=","} {print $1}'` ];then
	    #echo "match node:$node"
	    infoMatched=$nodeinfo
	    break
	fi
    done

    if [ -n "$infoMatched" ];then
	nodeinfos=`echo $nodeinfos | sed "s#$infoMatched##"`
	info="$infoMatched,$info"
    fi

    nodeinfos="$nodeinfos $info"
    #echo "updated nodeinfos:$nodeinfos---"

    echo "$nodeinfos" > $nodeinfoFile
}

function gotNodeinfos() {
    if [ -z "$nodeinfos" ];then
	if ! [ -s "$nodeinfoFile" ];then
	    exit
	fi
	nodeinfos=`cat $nodeinfoFile`
	#rm -f $nodeinfoFile
    fi
    echo "$nodeinfos"
}

function gotWorkDir(){
    node=$1
    [ -n $node ] || return
    infos=`gotNodeinfos`
    for info in $infos ;do
	if [ $node == `echo $info | awk 'BEGIN {FS=","} {print $1}'` ];then
	    break
	fi
    done

    workDir=`echo $info | awk 'BEGIN {FS=","} {print $2}'`
    echo $workDir
}

function gotIdentify(){
    node=$1
    [ -n $node ] || return
    for info in `gotNodeinfos`;do
	if [ $node == `echo $info | awk 'BEGIN {FS=","} {print $1}'` ];then
	    break
	fi
    done

    identify=${info##*,}
    echo $identify
}

function preMon(){
    for node in $nodes;do
	echo "do preMon for node:$node"
	workDir=`sshpass -p $(gotNodePwd $node) ssh $node mktemp -d '/tmp/rMonTmp.XXXXXXXX'`
	case $? in
	    0)
		;;
	    5)
		echo "--Invalid/incorrect password"
		exit
		;;
	    6)
		echo "--sshpass exits without confirming the new key"
		exit
		;;
	    *)
		echo "--sshpass error,exit"
		exit
	esac

	#nName=`sshpass -p $(gotNodePwd $node) ssh $node hostname`
	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) scp $monScript root@$node:$workDir
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir&&chmod +x ./$monScript"
	    if [ $node != '127.0.0.1' -a X$freeMem != X ];then
		sshpass -p $(gotNodePwd $node) ssh $node "echo 1 > /proc/sys/vm/drop_caches"
	    fi
	fi
	info="$node,$workDir"
	saveNodeinfo $node "$info"
    done

    echo
}

function startMon(){
    idtSuffix=$1
    [ -n $idtSuffix ] || idtSuffix="myRead"
    for node in $nodes;do
	echo "do startMon for node:$node"
	nName=`sshpass -p $(gotNodePwd $node) ssh $node hostname`
	identify="$nName-$idtSuffix"
	workDir=`gotWorkDir $node`
	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && ./$monScript -ui $identify"
	fi
	saveNodeinfo $node $identify
    done
    echo
}

function stopMonGetRet(){
    for node in $nodes;do
	echo "do stopMonGetRet for node:$node"
	workDir=`gotWorkDir $node`
	identify=`gotIdentify $node`
	#echo "wkdir:$workDir"
	#echo "idt:$identify"

	if [ -z "$workDir" ];then
	    echo '---warning--- workDir'
	    exit
	fi

	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && ./$monScript"
	    sshpass -p $(gotNodePwd $node) scp -r root@$node:$workDir/$identify ./$resDir
	fi
	echo
    done
    echo
}

function postMon() {
    for node in $nodes;do
	echo "do postMon for node:$node"
	workDir=`gotWorkDir $node`
	#echo $workDir

	if [ -z "$workDir" ];then
	    echo '---warning--- workDir'
	    exit
	fi

	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "rm -rf $workDir"
	fi
    done
    echo
}

function doClean() {
    for node in $nodes;do
	echo "do doClean for node:$node"
	workDir=`gotWorkDir $node`
	identify=`gotIdentify $node`
	echo "wkdir:$workDir"
	echo "idt:$identify"

	if [ -z "$workDir" ];then
	    echo '---warning--- workDir'
	    exit
	fi

	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && ./$monScript"
	    if [ $? ];then
		sshpass -p $(gotNodePwd $node) ssh $node "rm -rf $workDir"
	    fi
	fi
	echo
    done
    echo
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

function csvParser(){
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
	stage="$stage($opName)"


	[ $verbose -ge 1 ] && echo "$stage $res $iops $opType --"

	if ! [ X$opType == Xread -o X$opType == Xwrite ] ;then
	    [ $verbose -ge 3 ] && echo -n "not read/write, skip? "
	    if [ $i -eq 0 ];then
		[ $verbose -ge 3 ] && echo 'yes'
		continue
	    fi
	    postCont="True"
	    [ $verbose -ge 3 ] && echo 'no,need do resAvg .eg'
	fi

	if [ X$stage == X$lstage ];then
	    ((i++));
	    iopsSum=`echo "scale=2;$iopsSum+$iops" | bc`
	    resSum=`echo "scale=2;$resSum+$res" | bc`
	else
	    if [ X$lstage != X ];then
		resAvg=`echo "scale=2;$resSum/$i"| bc`
		echo -e "stage-iops-res: $lstage\t $iopsSum\t $resAvg"
		[ $verbose -gt 1 ] && echo "  new Stage: $stage "
		if [ X$postCont != X ];then
		    i=0
		    postCont=""
		    continue
		fi
	    else
		[ $verbose -ge 1 ] && echo "first Stage: $stage "
	    fi
	    i=1
	    iopsSum=$iops
	    resSum=$res
	    lstage=$stage
	fi
	[ $verbose -ge 2 ] && echo "cur iopsSum:$iopsSum resSum:$resSum"
    done < $csvFile

    if [ $i -ge 1 ];then
	resAvg=`echo "scale=2;$resSum/$i"| bc`
	echo -e "stage-iops-res: $lstage\t $iopsSum\t $resAvg"
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

function docbsubmit(){
    cbcli="$cbdir/cli.sh"
    issue=$1
    [ $verbose -gt 1 ] && echo "--cosbench submit $issue---"

    while [[ "true" ]]; do
	curNum=$( $cbcli info 2>/dev/null | grep active | awk '{print $2}')
	if [ X$curNum == X0 ];then
	    break
	else
	    echo "---cosbench has active work wait----"
	    sleep 2
	fi
    done
    tStart=`date '+%s'`
    ret=`$cbcli submit $issue 2>/dev/null`
    [ $verbose -gt 1 ] && echo "submit ret $ret"
    wkid=`echo $ret | awk '{print $4}'`
    sleep 1
    resDir="res-$idtSuffix-$wkid"
    if [ -d $resDir ];then
	echo "$resDir duplicate, mv to date +%s format"
	mv $resDir $resDir-`date +%s`
    fi
    mkdir $resDir

    #---->block start ===> not modify this block
    echo -ne '\e[?25l'
    echo -n "--$wkid $issue running,escape "
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

    [ $verbose -gt 1 ] && echo "archiveDir --$archiveDir---"
    sleep 1;cp -r $archiveDir ./$resDir	    #wait log file and got it

    bName=`basename $archiveDir`
    csv="./$resDir/$bName/$bName.csv"
    [ $verbose -gt 1 ] && echo "csv file: $csv"

    if [ -z $dryRun ];then
       csvParser $csv
    fi
}

function docbIssues() {
    issues="$@"
    for issue in $issues ;do
	if ! [ -s $issue ];then
	    echo "test $issue file not exist skip "
	    sleep 3
	    continue
	fi

	echo -e "\033[0;1;31m--do cosbench for issue $issue--\033[0m"

	#echo "do cosbench for issues $issue"
	# ./cbTest/10m-delete.xml
	idtSuffix=${issue##*/}		    #-->10m-delete.xml
	idtSuffix=${idtSuffix%.*}	    #-->10m-delete
	#echo $idtSuffix

	startMon $idtSuffix
	if [ -z $dryRun ];then
	    #----cosbench
	    docbsubmit	$issue
	fi
	stopMonGetRet
	sleep 1
    done
    postMon
}

function dorcb() {
    cbTdir="./cbTest"

    preMon
    if [ "X$optIssues" != X ];then
	issues="$optIssues"
    else
	if [ X$testType == X ];then
	    echo "testType NONE error,exit"
	    exit
	fi
	issuesNew=""
	for issue in $issues ;do
	    issuesNew="$issuesNew $cbTdir/$testType-$issue.xml"
	done
	issues=$issuesNew
    fi

    [ $verbose -gt 1 ] && echo "finally issues:
	$issues
    "
    docbIssues "$issues"
}

dryRun=""
cleanRun=""
optIssues=""
testType=""
freeMem=""
verbose="0"

function usage () {
    echo "Usage :  $0 [options] [optIssues]
	Options:
	-h	    Display this message
	-d	    dryRun
	-c	    doClean
	-t type	    testType	    [$testType]
	-f	    free mem ,dropCache	    [$freeMem]
	-v num	    verbose level   [$verbose]
	-p path	    cosbench path   [$cbdir]
    "
}

function main(){
    while getopts "hdct:v:p:" opt;do
	case $opt in
	    h)
		usage
		exit 0
		;;
	    d)
		dryRun="True"
		;;
	    c)
		cleanRun="True"
		;;
	    t)
		testType="$OPTARG"
		;;
	    f)
		freeMem="True"
		;;
	    v)
		verbose="$OPTARG"
		;;
	    p)
		cbdir="$OPTARG"
		;;

	esac
    done
    shift $(($OPTIND-1))
    optIssues=$@

    doInit
    if [ -n "$cleanRun" ];then
	doClean
    else
	dorcb
    fi
}

main $@
