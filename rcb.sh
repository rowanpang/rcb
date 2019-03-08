#!/bin/bash

source ./comm.sh
source ./mon.sh
source ./testRcb.sh
source ./testRfio.sh

:<<EOF
    node to monitor
    192.168.100.100,IPS@jjfab2018
    192.168.100.101,IPS@jjfab2018
    192.168.100.102,IPS@jjfab2018
EOF

nodes=""
nodesPwds="
    127.0.0.1,IPS@jjfab2018
"

SSHPSCP="sshpass -p \$(gotNodePwd \$node) scp"
SSHPSSH="sshpass -p \$(gotNodePwd \$node) ssh"

function usage () {
    echo "Usage :  $0 [options] [optIssues]
	Options:
	-h	    Display this message
	-d	    dryRun
	-f	    dropCache	    [$freeMem]

	-t	    test dir	    [$tCfgDir]
	-s size     objSize	    [$objSize,or size1,size2,..]

	-v num	    verbose level   [$verbose]
	-p path	    cosbench path   [$cbdir]
	-n nodeinfoFile	    nodeinfo file name [$nodeinfoFile]
    "
    exit 0
}

function optParser() {
    while getopts ":hdct:s:v:p:n:" opt;do
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
	    f)
		freeMem="True"
		;;
	    v)
		verbose="$OPTARG"
		;;
	    p)
		cbdir="$OPTARG"
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
	    ;;
	rfio)
	    dorfio $@
	    ;;
	clean)
	    doClean
	    ;;
	*)
	    echo "cmd error exit 1"
	    exit 1
	    ;;
    esac
}

function main(){
    cmdChose $@

    rmNodeinfofile
}

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
