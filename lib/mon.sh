#!/bin/bash

shToScp="./lib/monitor.sh"
monScript="./monitor.sh"

function preMon(){
    if [ -s $nodeinfoFile ];then
	echo -n "---file $nodeinfoFile exist"
	nodeinfoFile="$nodeinfoFile.`date +%s`"
	echo ",use $nodeinfoFile---"
    fi

    echo "nodes to Mon are:
	$nodesToMon
    "

    for node in $nodesToMon;do
	[ $verbose -ge 1 ] && echo "do preMon for node:$node"
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
	    sshpass -p $(gotNodePwd $node) scp $shToScp root@$node:$workDir
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && chmod +x ./$monScript"
	    if [ $node != '127.0.0.1' -a X$freeMem != X ];then
		sshpass -p $(gotNodePwd $node) ssh $node "echo 1 > /proc/sys/vm/drop_caches"
	    fi
	fi
	info="$node,$workDir"
	saveNodeinfo $node "$info"
    done

    [ $verbose -ge 1 ] && echo
}

function startMon(){
    idtSuffix=$1
    [ -n $idtSuffix ] || idtSuffix="myRead"
    for node in $nodesToMon;do
	[ $verbose -ge 1 ] && echo "do startMon for node:$node"
	nName=`sshpass -p $(gotNodePwd $node) ssh $node hostname`
	identify="$nName-$idtSuffix"
	workDir=`gotWorkDir $node`
	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && ./$monScript -d $identify -v $monVer"
	fi
	saveNodeinfo $node $identify
    done
    [ $verbose -ge 1 ] && echo
}

function stopMonGetRet(){
    for node in $nodesToMon;do
	[ $verbose -ge 1 ] && echo "do stopMonGetRet for node:$node"
	workDir=`gotWorkDir $node`
	identify=`gotIdentify $node`
	#echo "wkdir:$workDir"
	#echo "idt:$identify"

	if [ -z "$workDir" ];then
	    echo 'monitor workDir not exist return'
	    return
	fi

	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && ./$monScript -v $monVer"
	    sshpass -p $(gotNodePwd $node) scp -r root@$node:$workDir/$identify ./$resDir
	fi
	[ $verbose -ge 1 ] && echo
    done
    [ $verbose -ge 1 ] && echo
}

function postMon() {
    for node in $nodesToMon;do
	[ $verbose -ge 1 ] && echo "do postMon for node:$node"
	workDir=`gotWorkDir $node`
	#echo $workDir

	if [ -z "$workDir" ];then
	    echo 'monitor workDir not exist return'
	    return
	fi

	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "rm -rf $workDir"
	fi
	[ $verbose -ge 1 ] && echo
    done
    [ $verbose -ge 1 ] && echo
}

function doClean() {
    pr_debug "in func doClean"
    for node in $nodesToMon;do
	echo -e "\tdo doClean for node:$node"
	workDir=`gotWorkDir $node`
	identify=`gotIdentify $node`
	pr_info "wkdir:$workDir"
	pr_info "idt:$identify"

	if [ -z "$workDir" ];then
	    pr_warn 'monitor workDir not exist continue'
	    continue
	fi

	if [ -z $dryRun ];then
	    sshpass -p $(gotNodePwd $node) ssh $node "cd $workDir && ./$monScript"
	    if [ $? ];then
		sshpass -p $(gotNodePwd $node) ssh $node "rm -rf $workDir"
	    fi
	fi
	echo
    done
    pr_debug "out func doClean"
}
