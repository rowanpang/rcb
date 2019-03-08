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
    command -v dstat >/dev/null 2>&1 || yum --assumeyes install dstat
    command -v pidstat >/dev/null 2>&1 || yum --assumeyes install sysstat
}

function doMon(){
    #disk
    iostat sda sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm 1 -m > $dirName/disk.log &
    pids="$!"

    #disk-extra
    iostat sda sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm 1 -m -x > $dirName/disk-extra.log &
    pids="$pids $!"

    #net
    sar -n DEV 1 > $dirName/net.log 	&
    pids="$pids $!"

    #cpu
    sar -u 1 > $dirName/cpu.log	&
    pids="$pids $!"

    sar -P ALL 1 > $dirName/cpuPer.log 	&
    pids="$pids $!"

    #mem
    free -c 3600 -s 1 -h > $dirName/mem.log &
    pids="$pids $!"

    #pidstat
    pidstat -l -t -d -u -C "fio|tgtd|icfs|ceph-osd|radosgw" 1 > $dirName/pidstat.log &
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

function main(){
    optParser $@
    checkKill
    doInit
    depCheck
    doMon
}

main $@
