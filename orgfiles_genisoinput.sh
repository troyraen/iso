#### This script copies history files from maindir/RUNS_c0_for_isochrones/.... to destdir (data/tracks/cb)
#   and generates the input file isocinput for Aaron's isochrone program
#   can run ./make_eep and ./make_iso at end
#
#   Assumes duplicate models (from backups and restarts) have
#   been removed from history files
#
#   Script takes one argument: cboost number in [0..6]
###

##!/usr/local/bin/bash
#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "*********** Must supply script with cboost argument in [0..6] ***********"
    exit 1
fi

export ISO_DIR=$(pwd)
# for cb in {0..6}; do
#     mkdir --parents data/tracks/c$cb
# done

cb=$1 # script input argument
destdir="data/tracks/c$cb"
rm -r data/*
mkdir --parents $destdir
mkdir --parents data/eeps data/isochrones

maindir="mesaruns"
spin="SD"
isocinput="input.example"
isocoutput="isochrone_c$cb.dat"
# termout="makeeepiso.out"

echo
echo "Copying history.data files from $maindir/RUNS_c0_for_isochrones/.../LOGS to $destdir"
echo
declare -a hfiles # store names of history files for input.example
for mr in {0..5}; do
    for mp in {0..9}; do
# for mr in {2..3}; do
#     for mp in {0..1}; do
        srchdat="/home/tjr63/${maindir}/RUNS_c0_for_isochrones/${spin}/c${cb}/m${mr}p${mp}/LOGS/history.data"
        if [ -e $srchdat ]; then
            hdat=${destdir}/m${mr}p${mp}.data
            cp ${srchdat} ${hdat}tmp
            awk '{for(i=1;i<59;i++) {print $i} { print ${62} }}' < ${hdat}tmp >> ${hdat} #remove the integer and extra columns
            rm ${hdat}tmp
            hfiles=("${hfiles[@]}" "m${mr}p${mp}.data")
        fi
    done
done
len=$(echo ${#hfiles[@]})
# cp /home/tjr63/mesaruns/history_columns.list .

echo
echo "generating $isocinput"
echo
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
history_columns.list
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

echo
echo "./clean && ./mk"
echo
# run isochrone program
./clean
./mk
echo
echo "running make_eep and make_iso."
echo
./make_eep $isocinput && ./make_iso $isocinput
# output redirecting to $termout.
# file will open when complete."
# (./make_eep $isocinput && ./make_iso $isocinput) &> $termout
# less $termout
