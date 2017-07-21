#!/bin/bash

## set -x 

trap exit SIGHUP SIGINT SIGTERM

studyName=Grief

GETOPT=$( which getopt )
programName=`basename $0`
#REGRESSOR=exp2_affect
ROOT=${MDD_ROOT:-/data/jain/preApril/}
DATA=$ROOT
SCRIPTS_DIR=${ROOT}/scripts
GROUP_RESULTS_DIR=${ROOT}/Group.results/$studyName/ppi

. ${SCRIPTS_DIR}/logger_functions.sh

GETOPT_OPTIONS=$( $GETOPT  -o "s:l:" --longoptions "seedlist:" -n ${programName} -- "$@" )
exitStatus=$?
if [ $exitStatus != 0 ] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi

# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-l|--seedlist)
	    seedList=$2; shift 2 ;;
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

if [ ! -f $seedList ] ; then
    echo "*** ERROR: The seed list file does not exit. Exiting"
    exit
else 
    seeds=$( eval echo $( cat $seedList ) )
    nseeds=$( cat $seedList | wc -l )
fi

info_message_ln "*** Performing t-tests for PPI analysis for the following seeds:"
info_message_ln "$seeds"

if [[ ! -d ${GROUP_RESULTS_DIR} ]] ; then
    mkdir -p ${GROUP_RESULTS_DIR}
fi

cd ${GROUP_RESULTS_DIR}

if [[ ! -f final_mask+tlrc.HEAD ]] ; then
    info_message_ln "Linking group mask from parent directory"
    for ff in ../final_mask+tlrc.* ; do
	ln -sf $ff ./
    done
fi

## Control the number of threads used by OMP enabled AFNI
## programs. Espacially useful to set to 1 when running multiple subjects
## in parallel on the same machine
export OMP_NUM_THREADS=40

## this is the prefix used in scripts/ppi/03-ppi-postprocess.sh it
## must exactly match that used in the just mentioned script
prefix_3dd=ppi.post.

(( seedCount=1 ))
for seed in $seeds ; do
    seedName=${seed##*/}
    if echo $seedName | grep -q "nii" ; then 
	seedName=${seedName%%.nii*}
    else 
	seedName=${seedName%%+*}
    fi

    gltLabel=${seedName%%_*}
	
    info_message_ln "#################################################################################################"
    countMsg=$( printf '%02d of %02d' $seedCount $nseeds )
    info_message_ln "Running PPI t-tests for $seedName from the ${gltLabel} GLT. ${countMsg}." 
    info_message_ln "#################################################################################################"

    baseBrikLabel=PPI.${gltLabel}
    brikLabel="${baseBrikLabel:0:32}#0_Coef"
    
    3dttest++ -mask final_mask+tlrc.HEAD												\
    	      -prefix ${seedName}.ttest.all												\
    	      -Clustsim															\
    	      -prefix_clustsim cc.${seedName}												\
    	      -setA CMIT														\
    	      CMIT_01A $ROOT/CMIT_01A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_01A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_02A $ROOT/CMIT_02A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_02A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_04A $ROOT/CMIT_04A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_04A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_05A $ROOT/CMIT_05A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_05A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_07A $ROOT/CMIT_07A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_07A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_09A $ROOT/CMIT_09A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_09A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_11A $ROOT/CMIT_11A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_11A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_12A $ROOT/CMIT_12A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_12A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_13A $ROOT/CMIT_13A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_13A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_14A $ROOT/CMIT_14A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_14A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_15A $ROOT/CMIT_15A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_15A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_16A $ROOT/CMIT_16A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_16A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_17A $ROOT/CMIT_17A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_17A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_19A $ROOT/CMIT_19A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_19A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_22A $ROOT/CMIT_22A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_22A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_23A $ROOT/CMIT_23A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_23A_REML+tlrc.HEAD\[${brikLabel}\]	\
    	      CMIT_25A $ROOT/CMIT_25A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_25A_REML+tlrc.HEAD\[${brikLabel}\]

    case $gltLabel in
	relativeVsStanger)
	    stimuli=( rg rn sg sn )
	    ;;
	griefVsNeutral)
	    stimuli=( rg rn sg sn )
	    ;;
	relativeGriefVsRelativeNeutral)
	    stimuli=( rg rn )		
	    ;;
	strangerGriefVsStrangerNeutral)
	    stimuli=( sg sn )				
	    ;;
	relativeGriefVsStrangerGrief)
	    stimuli=( rg sg )						
	    ;;
	relativeNeutralVsStrangerNeutral)
	    stimuli=( rn sn )						
	    ;;
    esac
    
    (
	echo "Subj Stimulus InputFile"
	for subject in 01A 02A 04A 05A 07A 09A 11A 12A 13A 14A 15A 16A 17A 19A 22A 23A 25A ; do
	    for stimulus in ${stimuli[@]} ; do
		echo "CMIT_${subject} ${stimulus} $ROOT/CMIT_${subject}/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_${subject}_REML+tlrc.HEAD[PPI.${stimulus}#0_Coef]"
	    done
	done
    ) > dataTable.${seedName}.stimuli.ttest.all.txt
    
    cat <<EOF > dataTable.${seedName}.glt.ttest.all.txt
Subj	 InputFile
CMIT_01A $ROOT/CMIT_01A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_01A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_02A $ROOT/CMIT_02A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_02A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_04A $ROOT/CMIT_04A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_04A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_05A $ROOT/CMIT_05A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_05A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_07A $ROOT/CMIT_07A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_07A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_09A $ROOT/CMIT_09A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_09A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_11A $ROOT/CMIT_11A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_11A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_12A $ROOT/CMIT_12A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_12A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_13A $ROOT/CMIT_13A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_13A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_14A $ROOT/CMIT_14A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_14A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_15A $ROOT/CMIT_15A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_15A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_16A $ROOT/CMIT_16A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_16A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_17A $ROOT/CMIT_17A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_17A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_19A $ROOT/CMIT_19A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_19A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_22A $ROOT/CMIT_22A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_22A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_23A $ROOT/CMIT_23A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_23A_REML+tlrc.HEAD[${brikLabel}]	
CMIT_25A $ROOT/CMIT_25A/afniGriefPreprocessed.NL/${prefix_3dd}${seedName}.stats.CMIT_25A_REML+tlrc.HEAD[${brikLabel}]

EOF
    (( seedCount=seedCount+1 ))	
done
