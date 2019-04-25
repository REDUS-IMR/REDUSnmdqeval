#!/bin/bash

#script to recursively travel a dir of n levels

function traverse() {

local depth=$(($2 + 1))

#echo "$1 $depth"

if [ "$depth" -eq 3 ] ; then
	/usr/bin/find "$1"/ -type f -iname "ListUserFile05.F03*" -printf "%T@,%h,%f," -exec bash -c 'grep -o -e R10 -e R01 -e R50 -e R05 <<< $0' "{}" ";" | sort -t "," -k 4
else
	for file in "$1"/*
	    do
    		if [ -d "${file}" ] ; then
        	traverse "${file}" $depth
    	    fi
	done
fi
}

function main() {
 traverse "/ces/cruise_data" 0
}

main
