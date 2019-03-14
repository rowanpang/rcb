#!/bin/bash

verbose="7"
nodeinfos=""
nodeinfoFile='./nodeinfo.log'

function pr_info(){
    [ $verbose -ge 2 ] && echo "$@"
}

function pr_debug(){
    [ $verbose -ge 1 ] && echo "$@"
}

function pr_warn(){
    #33m,yellow
    echo -e "\033[1;33m" WARNING! "$@" "\033[0m"
}

function pr_err(){
    #31m,red
    echo -e "\033[1;31m" ERROR! "$@",exit -1 "\033[0m"
    exit -1
}

function pr_hint(){
    #31m,red
    echo -e "\033[1;31m" "$@" "\033[0m"
}

function gotNodePwd(){
    node=$1
    [ -n $node ] || return
    npMatched=""
    for np in $nodesToMonPwds;do
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

    [ $verbose -ge 1 ] && echo "do saveNodeinfo for $node,infoMsg:$info"
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
    toChk=$@

    if ! [ -z $dryRun ];then
	echo "sshChk dryRun return"
	return
    fi

    for cli in $toChk;do
        [ $verbose -ge 1 ] && echo -n "$cli "
	sshpass -p $(gotNodePwd $cli) ssh $cli 'ls >/dev/null 2>&1'
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
		ret=`ls $dir/$s-$op* 2>/dev/null`
		[ $ret ] && issuesNew="$issuesNew $ret" || issuesNew="$issuesNew $dir/$s-$op"
	    done
	done
	finIssues=$issuesNew
    fi
    nums=`echo $finIssues | wc -w`
    echo "finally issues($nums):
	$finIssues
    "
}

function cmdChkInstall(){
    cmd=$1
    pkg=$cmd
    [ $# -ge 2 ] && pkg=$2

    pr_debug "do cmdChkInstall for $cmd, pkg:$pkg"

    command -v $cmd >/dev/null 2>&1

    if ! [ $? ];then
	pr_hint "cmd $cmd not found,do yum install $pkg"
	yum --assumeyes install  $pkg
    fi
}

function commInit() {
    monVer=$verbose

    cmdChkInstall sshpass

    for np in $nodesToMonPwds ;do
	n=${np%,*}
	nodesToMon="$nodesToMon $n"
    done

    sshChk $nodesToMon
}

[ X$0 == Xcomm.sh ] && commInit
