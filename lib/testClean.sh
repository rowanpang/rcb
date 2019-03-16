#!/bin/bash

function testClean(){
    optParser $@
    commInit

    infos=`ls $nodeinfoFile* 2>/dev/null`
    for f in $infos;do
	pr_debug "do clean for $f"
	nodeinfoFile=$infos
	doClean
	rmNodeinfofile
    done
}
