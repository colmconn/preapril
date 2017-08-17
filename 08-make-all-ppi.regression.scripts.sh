#!/bin/bash

for ff in griefVsNeutral relativeGriefVsRelativeNeutral relativeGriefVsStrangerGrief relativeVsStranger ; do
## for ff in relativeGriefVsRelativeNeutral ; do
## for ff in relativeVsStranger ; do    
    ## this gg stuff would not be necessary if I could spell properly :roll:. note that this was in the afni preproc
    gg=$ff
    if [[ $ff == "relativeVsStranger" ]] ; then
	gg="relativeVsStanger"
    fi
    ./08-make.ppi.robust.regression.scripts.r -d -t "PPI.${gg}" -s ../Group.results/Grief/seeds/${gg}_seedlist.txt 
done
