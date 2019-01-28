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

function doInit() {
    command -v sshpass >/dev/null 2>&1 || yum install sshpass	    #need epel
    command -v fio >/dev/null 2>&1 || yum install fio

    for np in $nodesPwds;do
	n=${np%,*}
	nodes="$nodes $n"
    done

    node=$n
    #echo "--------$SSHPSCP"
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
	workDir=`sshpass -p $(gotNodePwd $node) ssh $node mktemp -d`
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

function docbsubmit(){
    cbdir="/root/cosbench/0.4.2.c4"
    cbcli="$cbdir/cli.sh"
    issue=$1
    echo "--cosbench submit $issue---"

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
    echo "submit ret $ret"
    wkid=`echo $ret | awk '{print $4}'`
    sleep 1

    while [[ "true" ]]; do
	curNum=$( $cbcli info 2>/dev/null | grep active | awk '{print $2}')
	archiveDir=`ls -d $cbdir/archive/$wkid-* 2>/dev/null`
	if [ X$curNum == X0 -a "X$archiveDir" != X ];then
	    break
	fi
	tNow=`date '+%s'`
	let "tDur=tNow-tStart"
	echo "--$wkid $issue running,escape $tDur s--"
	sleep 1
    done

    echo "archiveDir --$archiveDir---"
    echo "coping archive log--"
    cp -r $archiveDir ./$resDir		#got cosbench archive log
}

function docbIssues() {
    issues="$@"
    for issue in $issues ;do
	if ! [ -s $issue ];then
	    echo "issue file $issue not exist break"
	    break
	fi

	echo -e "\033[0;1;31m--do cosbench for issue $issue--\033[0m"

	#echo "do cosbench for issues $issue"
	# ./cbTest/10m-delete.xml
	idtSuffix=${issue##*/}		    #-->10m-delete.xml
	idtSuffix=${idtSuffix%.*}	    #-->10m-delete
	#echo $idtSuffix
	if [ -z $dryRun ];then
	    resDir="res-$idtSuffix-`date +%m%d%H%M%S`"
	    if [ -d $resDir ];then
		rm -rf $resDir
	    fi
	    mkdir $resDir
	fi

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

    echo "finally issues:
	$issues
    "
    docbIssues "$issues"
}

dryRun=""
cleanRun=""
optIssues=""
testType=""
freeMem=""

function usage () {
    echo "Usage :  $0 [options] [optIssues]
	Options:
	-h	    Display this message
	-d	    dryRun
	-c	    doClean
	-t	    testType
    "
}

function main(){
    while getopts "hdct:" opt;do
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
