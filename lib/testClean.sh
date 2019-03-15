#!/bin/bash

function testClean(){
    optParser $@
    commInit

    infos=`ls $nodeinfoFile.* 2>/dev/null`
    for f in $infos;do
	nodeinfoFile=$infos
	doClean
	rmNodeinfofile
    done
}
