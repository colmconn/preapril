#!/bin/bash

trap exit SIGHUP SIGINT SIGTERM

set -x
#this script cycles through glt and variables of interest and certain model setups
#note that script 10 calls script 9!!!
do_baseline_to_followup_change_regressions=1
do_baseline_only_regressions=0

export OMP_NUM_THREADS=40

####################################################################################################
### The following are the change from baseline to follow-up regressions
####################################################################################################

if [[ ${do_baseline_to_followup_change_regressions} -eq 1 ]] ; then

    for variable in delta.grief.scaled delta.grief.a.scaled delta.grief.b.scaled delta.grief.c.scaled  ; do
	for glt in relativeVsStanger relativeGriefVsRelativeNeutral relativeGriefVsStrangerGrief ; do
	    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/followup.regressions/ \
					      -x cc  -g ${glt} -e ${variable} -i ${glt}.followup.analysis.one.${variable}

	    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/followup.regressions/ \
					      -x cc  -g ${glt} -e ${variable} -i ${glt}.followup.analysis.two.${variable}.and.delta.hamd.scaled
	    
	    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/followup.regressions/ \
					      -x cc  -g ${glt} -e ${variable} -i ${glt}.followup.analysis.three.${variable}.and.age
	done
	

    ####################################################################################################
    ### rg and sg
    ####################################################################################################

	# for ff in rg sg ; do
	
	# 	./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
	    # 					  -x cc  -g ${ff} -e -e ${variable} -i ${glt}.followup.analysis.one.${variable}
	
	# 	./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
	    # 					  -x cc  -g ${ff} -e ${variable} -i ${glt}.followup.analysis.two.${variable}.and.delta.hamd
	
	# 	./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/regressions/ \
	    # 					  -x cc  -g ${ff} -e ${variable} -i ${glt}.followup.analysis.three.${variable}.and.age
	# done
	
    done
fi


####################################################################################################
### The following are the change from baseline only regressions
####################################################################################################

if [[ ${do_baseline_only_regressions} -eq 1 ]] ; then

    for variable in grief grief.a grief.b grief.c iri_pt iri_ec ; do

	for glt in relativeVsStanger relativeGriefVsRelativeNeutral relativeGriefVsStrangerGrief ; do

	    echo "####################################################################################################"
	    echo "### Variable: ${variable} GLT: ${glt}"
	    echo "####################################################################################################"	    
	    
	    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
					      -x cc  -g ${glt} -e ${variable} -i ${glt}.baseline.analysis.one.${variable}

	    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
					      -x cc  -g ${glt} -e ${variable} -i ${glt}.baseline.analysis.two.${variable}.and.hamd
	    
	    ./09-cluster-grief-regressions.sh -p 0.01 -c 0.05 -n 1 -s 2  -d ../Group.data/ -r ../Group.results/Grief/baseline.regressions/ \
					      -x cc  -g ${glt} -e ${variable} -i ${glt}.baseline.analysis.three.${variable}.and.age
	done
    done
fi
