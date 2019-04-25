#!/bin/bash

#script to recursively travel a dir of n levels

function traverse() {

local depth=$(($2 + 1))

#echo "$1 $depth"

if [ "$depth" -eq 3 ] ; then
	/usr/bin/find "$1"/ -type d -name lsssExportDb -printf "%T@,%h,%f\n" -o -type f -name *.lsss -printf "%T@,%h,%f\n" | sort -t "," -k1rn 
	#-type d -name lsssExportDb -o -type f -name *.lsss -printf "%T@,%h,%f\n" | sort -t "," -k1rn
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
