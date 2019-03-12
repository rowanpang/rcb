#!/bin/bash

function usage () {
    echo "Usage :  $0 [options] [optIssues]
        Options:
        -h		    Display this message
        -d  dirname	    log dirName
	-v  verbose level   loglevel [$verbose]
    "
    exit 0
}

function cmdChkInstall(){
    cmd=$1
    pkg=$cmd
    [ $# -ge 2 ] && pkg=$2

    [ $verbose -ge 1 ] && echo "do cmdChkInstall for $cmd, pkg:$pkg"

    command -v $cmd >/dev/null 2>&1

    if ! [ $? ];then
	[ $verbose -ge 1 ] && echo "cmd $cmd not found,do yum install $pkg"
	yum --assumeyes install  $pkg
    fi
}

function optParser(){
    while getopts ":hd:v:" opt;do
        case $opt in
            h)
                usage
                ;;
            d)
        	dirName="$OPTARG"
                ;;
	    v)
		verbose="$OPTARG"
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
    identify=$1
}

function depCheck(){
    [ $verbose -ge 1 ] && echo 'in func depCheck'
    cmdChkInstall dstat
    cmdChkInstall pidstat sysstat
    cmdChkInstall lshw
    cmdChkInstall lsscsi
    cmdChkInstall ip iproute
    [ $verbose -ge 1 ] && echo 'out func depCheck'
}

function doMon(){
    #disk
    iostat -m 1 sd{a..z} sda{a..z} > $dirName/disk.log &
    pids="$!"

    #disk-extra
    iostat -m -x 1 sd{a..z} sda{a..z} > $dirName/disk.extra.log &
    pids="$pids $!"

    #net
    sar -n DEV 1 > $dirName/net.log 	&
    pids="$pids $!"

    #cpu
    sar -u 1 > $dirName/cpu.log	&
    pids="$pids $!"

    sar -P ALL 1 > $dirName/cpu.per.log 	&
    pids="$pids $!"

    #mem
    free -c 3600 -s 1 -h > $dirName/mem.log &
    pids="$pids $!"

    #pidstat
    pidstat -l -t -d -u -C "fio|tgtd|icfs|ceph-osd|radosgw" 1 > $dirName/pidstat.log &
    pids="$pids $!"

:<<EOF
    top:
	-d: interval
	-b: batch mode
	-i: skip idle process
	-c: command show
	-w: wild show	#confilict with -o
	-o: sort by
EOF
    COLUMNS=167 top -d 1 -b -i -c -o RES > $dirName/top.log &
    pids="$pids $!"

    #dstat
    dstat --nocolor > $dirName/dstat.log &
    pids="$pids $!"

    echo $pids > $pidfile
    [ $verbose -ge 1 ] && echo "-----bg pids:$pids----------------"
}

verbose="1"
pids=""
pidfile="pid-bg.log"

function doInit() {
    if [ -z $dirName ];then
	if [ -z $identify ];then
	    echo "--need identifier!! exit 1---"
	    exit 1
	fi
	nodeName="$HOSTNAME"
	dirName=$nodeName-$identify
    fi

    if [ $verbose -ge 1 ];then
	echo "idt:$identify,dir:$dirName,verbose:$verbose"
	echo "-----log dir:$dirName------"
    fi

    [ -d $dirName ] && rm -rf $dirName
    mkdir $dirName
}

function checkKill() {
    if [ -s $pidfile ];then
	pids=`cat $pidfile`
	[ $verbose -ge 1 ] && echo "----kill pids: $pids-----"
	kill $pids
	rm -rf $pidfile
	exit
    fi
}

function gatherInfo(){
    lsscsi > $dirName/lsscsi.log
    df -h > $dirName/df.log

    cat /etc/os-release > $dirName/osInfo.log
    echo >> $dirName/osInfo.log
    uname -a >> $dirName/osInfo.log

    lshw > $dirName/lshw.log

    ip a > $dirName/ipA.log
}

function main(){
    optParser $@
    checkKill
    doInit
    depCheck
    gatherInfo
    doMon
}

main $@
