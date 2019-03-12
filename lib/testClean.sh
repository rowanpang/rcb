#!/bin/bash

function testClean(){
    optParser $@
    commInit
    doClean
}
