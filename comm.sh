#!/bin/bash

nodeinfos=""
nodeinfoFile='./nodeinfo.log'

function gotNodePwd(){
    node=$1
    [ -n $node ] || return
    npMatched=""
    for np in $nodesPwds;do
	if [ X$node == X`echo $np | awk 'BEGIN {FS=","} {print $1}'` ];then
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

    [ $verbose -ge 1 ] && echo "do saveNodeinfo for node:$node,info:$info"
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

function rmNodeinfofile {
    [ -e $nodeinfoFile ] && rm -f $nodeinfoFile
}

function gotNodeinfos() {
    if [ -z "$nodeinfos" ];then
	if ! [ -s "$nodeinfoFile" ];then
	    echo "$nodeinfoFile not exist,exit 1"
	    exit 1
	fi
	nodeinfos=`cat $nodeinfoFile`
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

function sshChk() {
    [ $verbose -ge 1 ] && echo "---in func sshChk---"
    toChk=$1

    if ! [ -z $dryRun ];then
	echo "sshChk dryRun return"
	return
    fi

    for cli in $toChk;do
        [ $verbose -ge 1 ] && echo -n "$cli "
	sshpass -p $(gotNodePwd $cli) ssh $cli 'ls 2>&1 >/dev/null'
        ret=$?
        if [ $ret -ne 0 ];then
	    [ $verbose -le 0 ] && echo -n "$cli "
            echo "sshChk error,exit 1"
            exit 1
        fi

        [ $verbose -ge 1 ] && echo "sshChk ok"
    done

    [ $verbose -ge 1 ] && echo "---out func sshChk---"
}

function commInit() {
    monVer=$verbose
    command -v sshpass >/dev/null 2>&1 || yum install sshpass	    #need epel
    command -v fio >/dev/null 2>&1 || yum install fio

    for np in $nodesPwds;do
	n=${np%,*}
	nodes="$nodes $n"
    done

    sshChk $nodes
}

function mkIssuesList() {
    sizes="$1"
    ops="$2"
    dir="$3"

    if [ "X$optIssues" != X ];then
	finIssues="$optIssues"
    else
	if [ X$objSize == X ];then
	    echo "objSize NONE error,exit 1"
	    exit 1
	fi
	issuesNew=""
	ops="${ops//,/ }"
	for op in $ops ;do
	    sizes="${sizes//,/ }"
	    for s in $sizes;do
		issuesNew="$issuesNew `ls $dir/$s-$op* 2>/dev/null`"
	    done
	done
	finIssues=$issuesNew
    fi

    echo "finally issues:
	$finIssues
    "
}

