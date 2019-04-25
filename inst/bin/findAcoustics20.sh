#!/bin/bash

#script to recursively travel a dir of n levels

function traverse() {

local depth=$(($2 + 1))

#echo "$1 $depth"

if [ "$depth" -eq 3 ] ; then
	/usr/bin/find "$1"/ -type f -iname "listuserfile20*" -type f -printf "%T@,%h,%f\n" | sort -t "," -k1rn
        #/usr/bin/find "$1"/ -type f -printf "%T@ %h %f\n" | sort -k3b,3 -k1rn,1  | uniq -f 2
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
