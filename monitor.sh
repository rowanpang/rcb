#!/bin/bash

pidfile="pid-bg.log"
if [ -s $pidfile ];then
    pids=`cat $pidfile`
    echo "----kill pids: $pids-----"
    kill $pids
    rm -rf $pidfile
    exit
fi

if [ $# -lt 1 ];then
    echo "--need identifier!!---"
    exit
fi

pids=""
if [ $1 == '-ui' ];then
    #upper identify
    dirName=$2
fi

if [ -z $dirName ];then
    nodeName="$HOSTNAME"
    identify=$1
    dirName=$nodeName-$identify
fi

echo "-----log dir:$dirName------"
if [ -d $dirName ];then
    rm -rf $dirName
fi
mkdir $dirName

command -v dstat >/dev/null 2>&1 || yum install dstat
command -v pidstat >/dev/null 2>&1 || yum install sysstat

#disk
iostat sda sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm 1 -m > $dirName/disk.log &
pids="$!"

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
echo "-----bg pids:$pids----------------"
