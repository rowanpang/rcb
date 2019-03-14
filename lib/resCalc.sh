#!/bin/bash

calcTgtDir="./"
resDirPfx="cbRes-"
strHosts="node1,node2,node3"
cliHosts="press2,press3,as13kp9"
objSizes="4k,16k,256k,1m"

function csvInit(){
    syslevelcsv="$calcTgtDir/levelResult.csv"
    syslevelcsvHeader="idt-cpu-disk-netRx-netTx"
    syslevelcsvHeaderHost="nodeX$syslevelcsvHeader-pressX${syslevelcsvHeader#*-}"

    if ! [ -s $syslevelcsv ];then
	pr_hint "[init] res csv file: $syslevelcsv"
	echo "${syslevelcsvHeaderHost//-/,}" > $syslevelcsv
	echo "${syslevelcsvHeader//-/,}" >> $syslevelcsv
    else
	pr_hint "[append] to res csv file: $syslevelcsv"
	echo "${syslevelcsvHeader//-/,}" >> $syslevelcsv
	echo "${syslevelcsvHeader//-/,}" >> $syslevelcsv
    fi
}

function csvAppend(){
    line=$@

    echo -en "\t$syslevelcsvHeader: "
    for res in $line;do
	echo -en "$res\t"
    done
    echo

    echo ${line// /,} >> $syslevelcsv
}

function hostIdentify(){
    parentDir=$1
    hosts=$2
    h=${hosts%%,*}

    hdir=`ls -d $parentDir/$h-* 2>/dev/null`

    pr_devErr "idt Host dir:$hdir"

    bName=`basename $hdir`

    echo ${bName#*-}
}

function hostsAvg(){
    parentDir=$1
    hosts=$2

    pr_devErr "--hosts: $hosts"
    i=0
    cpuSum=0
    diskSum=0
    netRxSum=0
    netTxSum=0

    for h in ${hosts//,/ };do
	((i++))
	hdir=`ls -d $parentDir/$h-* 2>/dev/null`
	pr_devErr "--hostdir $hdir"
	cpu=`cat $hdir/cpu.log | awk 'BEGIN{ i=0 } {sum+=$9;i++} END {print 100-sum/i}'`
	disk=`cat $hdir/disk.log.extra | awk 'BEGIN{ i=0 } {sum+=$14;i++} END {sum+=i;print  sum/i}'`
	netRx=`cat $hdir/dstat.log | awk 'BEGIN{FS="|"} {print $3}' | awk '{print $1}' |grep M | awk '{sum+=$1} END{NR+=1;print sum*8/NR/100;}'`
	netTx=`cat $hdir/dstat.log | awk 'BEGIN{FS="|"} {print $3}' | awk '{print $2}' |grep M | awk '{sum+=$1} END{NR+=1;print sum*8/NR/100;}'`

	pr_devErr "--varCpu: $cpu,$disk,$netRx,$netTx"

	cpuSum=`echo "scale=2;$cpuSum+$cpu" | bc`
	diskSum=`echo "scale=2;$diskSum+$disk" | bc`
	netRxSum=`echo "scale=2;$netRxSum+$netRx" | bc`
	netTxSum=`echo "scale=2;$netTxSum+$netTx" | bc`
    done

    [ $i -eq 0 ] && i=1

    pr_devErr "---sum:$i,$cpuSum,$diskSum,$netRxSum,$netTxSum"

    cpuAvg=`echo "scale=2;$cpuSum/$i" | bc `
    diskAvg=`echo "scale=2;$diskSum/$i" | bc `
    netRxAvg=`echo "scale=2;$netRxSum/$i" | bc `
    netTxAvg=`echo "scale=2;$netTxSum/$i" | bc `

    echo "$cpuAvg,$diskAvg,$netRxAvg,$netTxAvg"
}

function hostlevel(){
    pdir=$1	#parent dir

    idt=`hostIdentify $pdir $strHosts`
    strAvg=`hostsAvg $pdir $strHosts`
    cliAvg=`hostsAvg $pdir $cliHosts`

    csvAppend $idt,$strAvg,$cliAvg
}

function resDirslevel(){
    folds=""
    for s in ${objSizes//,/ };do
	dir=`ls -d $calcTgtDir/$resDirPfx$s-* 2>/dev/null`
	folds="$folds $dir"
    done

    for dir in $folds;do
	pr_debug "---calc for $dir----"
	hostlevel $dir
    done
}

function doSysCalc(){
    resDirPfx=$1
    strHosts=$2
    cliHosts=$3
    objSizes=$4

    [ X$topdir != X ] && calcTgtDir=$topdir

    csvInit
    resDirslevel
}

function testMain(){
    source ./lib/comm.sh
    csvInit
    resDirslevel
}

[ X`basename $0` == XresCalc.sh ] && testMain
