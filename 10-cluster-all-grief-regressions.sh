#!/bin/bash

set -x

do_baseline_to_followup_change_regressions=0
do_baseline_only_regressions=1

export OMP_NUM_THREADS=40

####################################################################################################
### The following are the change from baseline to follow-up regressions
####################################################################################################

if [[ ${do_baseline_to_followup_change_regressions} -eq 1 ]] ; then
    
    ####################################################################################################
    ### relativeVsStanger
    ####################################################################################################

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
				      -x cc  -g relativeVsStanger -e delta.grief.scaled -i relativeVsStanger.analysis.one.delta.grief.scaled

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
				      -x cc  -g relativeVsStanger -e delta.grief.scaled -i relativeVsStanger.analysis.two.delta.grief.scaled.and.grief.delta.hamd

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
				      -x cc  -g relativeVsStanger -e delta.grief.scaled -i relativeVsStanger.analysis.three.delta.grief.scaled.and.age


    ####################################################################################################
    ### relativeGriefVsRelativeNeutral
    ####################################################################################################

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
				      -x cc  -g relativeGriefVsRelativeNeutral -e delta.grief.scaled -i relativeGriefVsRelativeNeutral.analysis.one.delta.grief.scaled

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
				      -x cc  -g relativeGriefVsRelativeNeutral -e delta.grief.scaled -i relativeGriefVsRelativeNeutral.analysis.two.delta.grief.scaled.and.grief.delta.hamd

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
				      -x cc  -g relativeGriefVsRelativeNeutral -e delta.grief.scaled -i relativeGriefVsRelativeNeutral.analysis.three.delta.grief.scaled.and.age


    ####################################################################################################
    ### relativeGriefVsStrangerGrief
    ####################################################################################################

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
				      -x cc  -g relativeGriefVsStrangerGrief -e delta.grief.scaled -i relativeGriefVsStrangerGrief.analysis.one.delta.grief.scaled

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
				      -x cc  -g relativeGriefVsStrangerGrief -e delta.grief.scaled -i relativeGriefVsStrangerGrief.analysis.two.delta.grief.scaled.and.grief.delta.hamd

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
				      -x cc  -g relativeGriefVsStrangerGrief -e delta.grief.scaled -i relativeGriefVsStrangerGrief.analysis.three.delta.grief.scaled.and.age


    ####################################################################################################
    ### rg and sg
    ####################################################################################################

    for ff in rg sg ; do

	./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
					  -x cc  -g ${ff} -e delta.grief.scaled -i ${ff}.analysis.one.delta.grief.scaled

	./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
 					  -x cc  -g ${ff} -e delta.grief.scaled -i ${ff}.analysis.two.delta.grief.scaled.and.grief.delta.hamd

	./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
 					  -x cc  -g ${ff} -e delta.grief.scaled -i ${ff}.analysis.three.delta.grief.scaled.and.age
    done
fi


####################################################################################################
### The following are the change from baseline only regressions
####################################################################################################

if [[ ${do_baseline_only_regressions} -eq 1 ]] ; then

####################################################################################################
    ### relativeVsStanger
    ####################################################################################################

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
				      -x cc  -g relativeVsStanger -e grief -i relativeVsStanger.baseline.analysis.one.grief

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
				      -x cc  -g relativeVsStanger -e grief -i relativeVsStanger.baseline.analysis.two.grief.and.hamd

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
				      -x cc  -g relativeVsStanger -e grief -i relativeVsStanger.baseline.analysis.three.grief.and.age


    ####################################################################################################
    ### relativeGriefVsRelativeNeutral
    ####################################################################################################

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
				      -x cc  -g relativeGriefVsRelativeNeutral -e grief -i relativeGriefVsRelativeNeutral.baseline.analysis.one.grief

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
				      -x cc  -g relativeGriefVsRelativeNeutral -e grief -i relativeGriefVsRelativeNeutral.baseline.analysis.two.grief.and.hamd

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
				      -x cc  -g relativeGriefVsRelativeNeutral -e grief -i relativeGriefVsRelativeNeutral.baseline.analysis.three.grief.and.age


    ####################################################################################################
    ### relativeGriefVsStrangerGrief
    ####################################################################################################

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
				      -x cc  -g relativeGriefVsStrangerGrief -e grief -i relativeGriefVsStrangerGrief.baseline.analysis.one.grief

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
				      -x cc  -g relativeGriefVsStrangerGrief -e grief -i relativeGriefVsStrangerGrief.baseline.analysis.two.grief.and.hamd

    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
				      -x cc  -g relativeGriefVsStrangerGrief -e grief -i relativeGriefVsStrangerGrief.baseline.analysis.three.grief.and.age

fi
