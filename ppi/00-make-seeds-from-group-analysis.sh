#!/bin/bash

## set -x

trap exit SIGHUP SIGINT SIGTERM
. ./logger_functions.sh

cd ../Group.results/Grief

[[ -d seeds ]] || mkdir seeds

for ff in clorder.Grief.baseline.*+tlrc.HEAD ; do

    contrast=$( echo $ff | awk 'BEGIN { FS="[.+]" } { print $4}' )
    info_message_ln "Extracting ROIs from the $contrast cluster ordered file"

    cat /dev/null > ${contrast}_seedlist.txt
    seedCount=$( 3dBrickStat -max $ff )
    if [[ $seedCount -gt 0 ]] ; then 
	for cluster in $( seq 1  1 $seedCount ) ; do
	    3dcalc -a $ff -expr "equals(a, $cluster)" -prefix seeds/${contrast}_seed_$(printf "%02d" $cluster)
	    echo "\$DATA/Group.results/Grief/seeds/${contrast}_seed_$(printf "%02d" $cluster)+tlrc.HEAD" >> seeds/${contrast}_seedlist.txt
	done
    else
	info_message_ln "No seeds for $contrast"
    fi
done
