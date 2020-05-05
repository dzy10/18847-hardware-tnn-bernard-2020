#!/bin/bash

# script for converting MNIST image file to memory file used with systemverilog's readmemh

if [ -z "$1" ]; then
    echo "usage: ./convert.sh <filename>"
    exit 0
fi

od -An -j16 -v -w28 -tx1 $1 > "$1.mem"
