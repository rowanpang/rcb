#!/bin/bash

calcTgtDir="./"
resDirPfx="cbRes-"
strHosts="node1,node2,node3"
cliHosts="press2,press3,as13kp9"
objSizes="4k,16k,256k,1m"

function csvInit(){
    syslevelcsv="$calcTgtDir/levelResult.csv"
    syslevelcsvHeader="idt-cpu-ssd-hdd-netRx-netTx"
    syslevelcsvHeaderHost="nodeX$syslevelcsvHeader-pressX${syslevelcsvHeader#*-}"

    if ! [ -s $syslevelcsv ];then
	pr_hint "level csv [init] : $syslevelcsv"
	echo "${syslevelcsvHeaderHost//-/,}" > $syslevelcsv
	echo "${syslevelcsvHeader//-/,}" >> $syslevelcsv
    else
	pr_hint "level csv [append]: $syslevelcsv"
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
    h=${hosts%%,*}  #use the first host to get the $size-$op as idt

    hdir=`ls -d $parentDir/$h-* 2>/dev/null`
    [ X"$hdir" == X ] && pr_err  "hostIdentify,hdir under $parentDir not exist"
    pr_devErr "idt Host dir:$hdir"

    bName=`basename $hdir`

    echo ${bName#*-}
}

function diskCalc(){
    #out put ssdAvg,hddAvg
    pdir=$1

    file="$pdir/disk.log.extra"
    lsscsi=`ls $pdir/*lsscsi.log 2>/dev/null`

    [ X"$lsscsi" == X ] && pr_err "pdir:$pdir,lsscsi not exist"

    ssds=`grep 'INTEL SSD\|Micron_' $lsscsi | awk -F '/' '{printf $3}'`
    ssdsReg=${ssds// /|}
    ssdsReg=${ssdsReg%|}

    [ X$ssdsReg == X ] && ssdsReg="###"		#for NONE ssd case

    pr_devErr "ssdsReg: $ssdsReg"

    cat $file | grep "^sd" | awk -v ssdReg="$ssdsReg" ' BEGIN{
	    hddIdx=1
	    hddSum=0
	    ssdIdx=1
	    ssdSum=0
	} {
	    dev=$1
	    util=$NF
	    #there are more record for sysstat version 11.7.3 than 10.1.5
	    #Device	r/s     w/s     rMB/s     wMB/s   rrqm/s   wrqm/s %rrqm  %wrqm r_await w_await aqu-sz rareq-sz wareq-sz  svctm  %util
	    #Device:	rrqm/s   wrqm/s     r/s     w/s    rMB/s wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm %util
	    if(match(dev,ssdReg) != 0){
		#printf("%s match\n",dev)
		#for not used disk for system disk
		if( util > 10){
		    ssdSum+=util
		    ssdIdx++
		}
	    }else{
		#printf("%s not match\n",dev)
		#for not used disk for system disk
		if( util > 10){
		    hddSum+=util
		    hddIdx++
		}
	    }
	} END {
	    hddSum+=hddIdx-1
	    ssdSum+=ssdIdx-1

	    printf("%.2f,%.2f\n",ssdSum/ssdIdx,hddSum/hddIdx)
	}'
}

function hostsAvg(){
    parentDir=$1
    hosts=$2

    pr_devErr "--hosts: $hosts"
    i=0
    cpuSum=0
    netRxSum=0
    netTxSum=0
    diskSSDSum=0
    diskHDDSum=0

    for h in ${hosts//,/ };do
	((i++))
	hdir=`ls -d $parentDir/$h-* 2>/dev/null`
	[ X$hdir == X ] && pr_err "host dir error under $parentDir"
	pr_devErr "--hostdir $hdir"

	disk=`diskCalc $hdir`
	[ $? ] || pr_err "diskCalc error for $parentDir"
	diskSSD=${disk%,*}
	diskHDD=${disk#*,}

	cpu=`cat $hdir/cpu.log | awk 'BEGIN{ i=1 } {sum+=$9;i++} END {print 100-sum/i}'`
	netRx=`cat $hdir/dstat.log | awk 'BEGIN{FS="|"} {print $3}' | awk '{print $1}' |grep M | awk '{sum+=$1} END{NR+=1;print sum*8/NR/100;}'`
	netTx=`cat $hdir/dstat.log | awk 'BEGIN{FS="|"} {print $3}' | awk '{print $2}' |grep M | awk '{sum+=$1} END{NR+=1;print sum*8/NR/100;}'`

	pr_devErr "--hostVal: $cpu,$diskSSD,$diskHDD,$netRx,$netTx"

	cpuSum=`echo "scale=2;$cpuSum+$cpu" | bc`
	diskSSDSum=`echo "scale=2;$diskSSDSum+$diskSSD" | bc`
	diskHDDSum=`echo "scale=2;$diskHDDSum+$diskHDD" | bc`
	netRxSum=`echo "scale=2;$netRxSum+$netRx" | bc`
	netTxSum=`echo "scale=2;$netTxSum+$netTx" | bc`
    done

    [ $i -eq 0 ] && i=1

    pr_devErr "---hdir count $i:$cpuSum,$diskSSDSum,$diskHDDSum,$netRxSum,$netTxSum"

    cpuAvg=`echo "scale=2;$cpuSum/$i" | bc `
    diskSSDAvg=`echo "scale=2;$diskSSDSum/$i" | bc `
    diskHDDAvg=`echo "scale=2;$diskHDDSum/$i" | bc `
    netRxAvg=`echo "scale=2;$netRxSum/$i" | bc `
    netTxAvg=`echo "scale=2;$netTxSum/$i" | bc `

    echo "$cpuAvg,$diskSSDAvg,$diskHDDAvg,$netRxAvg,$netTxAvg"
}

function hostlevel(){
    pdir=$1	#parent dir

    idt=`hostIdentify $pdir $strHosts`
    [ $? ] || pr_err "hostIdentify exec error"
    strAvg=`hostsAvg $pdir $strHosts`
    [ $? ] || pr_err "hostavg exec error"
    cliAvg=`hostsAvg $pdir $cliHosts`

    csvAppend $idt,$strAvg,$cliAvg
}

function resDirslevel(){
    folds=""
    for s in ${objSizes//,/ };do
	dir=`ls -d $calcTgtDir/$resDirPfx$s-* 2>/dev/null`
	[ X"$dir" == X ] && pr_debug "cacl host dir: '$calcTgtDir/$resDirPfx$s-*' not exist,skip"
	folds="$folds $dir"
    done

    [ X"$folds" == X ] && pr_err "calc host dirs Empty"

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

    pr_debug "calc resDirPfx: $resDirPfx"
    pr_debug "calc strHosts: $strHosts"
    pr_debug "calc cliHosts: $cliHosts"
    pr_debug "calc objSizes: $objSizes"
    pr_debug "calc calcTgtDir: $calcTgtDir"

    csvInit
    resDirslevel
}

function testMain(){
    source ./lib/comm.sh
    csvInit
    resDirslevel
}

[ X`basename $0` == XresCalc.sh ] && testMain
