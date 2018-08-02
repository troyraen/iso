#### This script copies history files from maindir/RUNS/.... to destdir
#   and generates the input file isocinput for Aaron's isochrone program
#
#   Script takes one argument: cboost number in [0..6]
###

##!/usr/local/bin/bash
#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "Must give script cboost argument in [0..6]"
    exit 1
fi

# create dir (optional)
# git clone git@github.com:dotbot2000/iso.git # https://github.com/aarondotter/iso
# cd iso
mkdir --parents data/eeps data/isochrones
for cb in {0..6}; do
    mkdir --parents data/tracks/c$cb
done
# chmod 744 *
# export ISO_DIR=/home/tjr63/iso
# ./clean
# ./mk

# copy all history files
declare -a hfiles # store names of history files for input.example
maindir="implicit_test2"
spin="SD"
cb=$1 # script input argument
destdir="data/tracks/c$cb"
isocinput="input.example"
isocoutput="isochrone_c$cb.dat"

for mr in {0..5}; do
    for mp in {0..9}; do
# for mr in {2..3}; do
#     for mp in {0..1}; do
        srchdat="/home/tjr63/histdat/${maindir}/RUNS/${spin}/c${cb}/m${mr}p${mp}/LOGS/history.data"
        if [ -e $srchdat ]; then
            cp ${srchdat} ${destdir}/m${mr}p${mp}.data
            hfiles=("${hfiles[@]}" "m${mr}p${mp}.data")
        fi
    done
done
len=$(echo ${#hfiles[@]})

# create input.example (overwrites existing)
echo "#version string, max 8 characters
example
#initial Y, initial Z, [Fe/H], [alpha/Fe], v/vcrit (space separated)
   0.2703 1.42857e-02   0.00        0.00     0.4
#data directories: 1) history files, 2) eeps, 3) isochrones
${destdir}
data/eeps
data/isochrones
#read history_columns
${MESA_DIR}/star/defaults/history_columns.list
#specify tracks
${len}" > $isocinput
printf "%s\n" "${hfiles[@]}" >> $isocinput
echo "#specify isochrones
${isocoutput}
min_max
log10
51
5.0
10.11" >> $isocinput


# run isochrone program
./make_eep $isocinput && ./make_iso $isocinput

