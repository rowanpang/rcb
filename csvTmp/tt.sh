#!/bin/bash


function csvParser(){
    csvFile="./w428-demo.csv"
    csvFile="./w171-4m-read.csv"
    csvFile="./w570-s3-1m.csv"
    csvFile=$1

    hitHeader=""
    lstage=""
    verbose="0"
    i="0"

    while read line ;do
	if ! [ $hitHeader ];then
	    hitHeader=`echo $line | grep -c '^Stage,Op-Name,'`
	    [ $verbose -ge 1 ] && echo "hit header: $hitHeader"
	    continue
	fi

	stage=`echo $line | awk 'BEGIN {FS=","} { print $1}'`
	opName=`echo $line | awk 'BEGIN {FS=","} { print $2}'`
	opType=`echo $line | awk 'BEGIN {FS=","} { print $3}'`
	res=`echo $line | awk 'BEGIN {FS=","} { print $6}'`
	iops=`echo $line | awk 'BEGIN {FS=","} { print $14}'`
	stage="$stage($opName)"


	[ $verbose -ge 1 ] && echo "$stage $res $iops $opType --"

	if ! [ X$opType == Xread -o X$opType == Xwrite ] ;then
	    [ $verbose -ge 3 ] && echo -n "not read/write, skip? "
	    if [ $i -eq 0 ];then
		[ $verbose -ge 3 ] && echo 'yes'
		continue
	    fi
	    postCont="True"
	    [ $verbose -ge 3 ] && echo 'no,need do resAvg .eg'
	fi

	if [ X$stage == X$lstage ];then
	    ((i++));
	    iopsSum=`echo "scale=2;$iopsSum+$iops" | bc`
	    resSum=`echo "scale=2;$resSum+$res" | bc`
	else
	    if [ X$lstage != X ];then
		resAvg=`echo "scale=2;$resSum/$i"| bc`
		echo -e "stage-iops-res: $lstage\t $iopsSum\t $resAvg"
		[ $verbose -gt 1 ] && echo "  new Stage: $stage "
		if [ X$postCont != X ];then
		    i=0
		    postCont=""
		    continue
		fi
	    else
		[ $verbose -ge 1 ] && echo "first Stage: $stage "
	    fi
	    i=1
	    iopsSum=$iops
	    resSum=$res
	    lstage=$stage
	fi
	[ $verbose -ge 2 ] && echo "cur iopsSum:$iopsSum resSum:$resSum"
    done < $csvFile

    if [ $i -ge 1 ];then
	resAvg=`echo "scale=2;$resSum/$i"| bc`
	echo -e "stage-iops-res: $lstage\t $iopsSum\t $resAvg"
    fi

}

csvParser $@
