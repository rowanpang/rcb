#!/bin/bash

source ./lib/comm.sh
source ./lib/mon.sh
source ./lib/levelCalc.sh
source ./lib/testRcb.sh
source ./lib/testRfio.sh
source ./lib/testCalc.sh
source ./lib/testMon.sh

#source ./lib/testClean.sh

SSHPSCP="sshpass -p \$(gotNodePwd \$node) scp"
SSHPSSH="sshpass -p \$(gotNodePwd \$node) ssh"

function usage () {
    mpress=`echo $fServerNodes | tr '\n' ' '`
    echo "Usage :  $0 [options] [optIssues]
	Options:
	-h	    Display this message
	-d	    dryRun
	-f	    dropCache	    [$freeMem]

	-t	    target dir	    [$tCfgDir]
	-s size     objSize	    [$objSize OR s1,s2,..]
	-o testOps  ops to test	    [$testOps OR op1,op2,.. OR rcb/rfio]

	-v num	    verbose level   [$verbose]
	-p path	    cosbench path   [$cbdir]
	-n nodeinfoFile	    nodeinfo file name [$nodeinfoFile]
	-m	    multi fio server [ $mpress ]
    "
    exit 0
}

function optParser() {
    while getopts ":hdct:s:o:v:p:n:m" opt;do
	case $opt in
	    h)
		usage
		;;
	    d)
		dryRun="True"
		;;
	    t)
		tCfgDir="$OPTARG"
		;;
	    s)
		objSize="$OPTARG"
		;;
	    o)
		testOps="$OPTARG"
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
	    m)
		multiRfio="True"
		pressNodesPwds="$pressNodesPwds $fServerNodesPwds"
		;;
	    n)
		nodeinfoFile="$OPTARG"
		;;
	    \?)
		echo "--Invalid args -$OPTARG"
		usage
		;;
	    :)
		echo "--Need arguement -$OPTARG"
		usage
		;;
	esac
    done
    shift $(($OPTIND-1))
    optIssues=$@
}

function cmdChose() {
    cmd=`basename $0`
    case ${cmd%.*} in
        rcb)
	    dorcb $@
	    rmNodeinfofile
	    ;;
	rfio)
	    dorfio $@
	    rmNodeinfofile
	    ;;
	clean)
	    testClean $@
	    ;;
	calc)
	    doCalcCmd $@
	    ;;
	monOps)
	    doMonDirect $@
	    ;;

	*)
	    echo "cmd error, none match exit 1"
	    exit 1
	    ;;
    esac
}

function main(){
    cfgFile="./conf.cfg"
    [ -s $cfgFile ] && source $cfgFile
    cmdChose $@

    echo "topdir:-----$topdir-----"
}

:<<EOF
    node to monitor
    192.168.100.100,IPS@jjfab2018
    192.168.100.101,IPS@jjfab2018
    192.168.100.102,IPS@jjfab2018
EOF
strNodesPwds=" "
pressNodesPwds="
    127.0.0.1,IPS@jjfab2018
"

:<<EOF
    nodes run with fio --server,plus localhost exec fio
    must contain in then nodesToMonPwds
    ref ./lib/testRfio.sh for usage
EOF
fServerNodes=""
fServerNodesPwds=""
fServerNodesIssueChange=""

finIssues=""
dryRun=""
optIssues=""
freeMem=""
verbose="0"

#ops name
objSize=""
testOps=""
tCfgDir=""

main $@
