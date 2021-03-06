#!/bin/bash
#to run this program, need to ensure
# -studyName, REGRESSOR correct
# -voxel dimensions correct for mask correct (use 3dinfo)

# set -x 

trap exit SIGHUP SIGINT SIGTERM

studyName=NeedleAsTask

programName=`basename $0`
#REGRESSOR=exp2_affect
ROOT=${MDD_ROOT:-/data/jain/preApril/}
SCRIPTS_DIR=${ROOT}/scripts

## if you want to analyze the needle data using only the first 8
## seconds of each stimulus viewing uncomment the following line. if
## you want to analyze the needle data using the the whole 30 second
## period of each stimulus viewing, comment out the following line
subanalysis=".8sec"
GROUP_RESULTS_DIR=${ROOT}/Group.results/${studyName}${subanalysis}

if [[ ! -d ${GROUP_RESULTS_DIR} ]] ; then
    mkdir -p ${GROUP_RESULTS_DIR}
fi

cd ${GROUP_RESULTS_DIR}

if [[ ! -f final_mask+tlrc.HEAD ]] ; then

    ## compute a mask of 70% overlap of all subjects' group masks
    ## the list of subjects should be the same as the list of subjects below in the 3dttest++ command
    [[ ! -f mask_overlap.7+tlrc.HEAD ]] && \
	3dmask_tool -input ../../CMIT_{01A,02A,04A,05A,07A,09A,11A,12A,13A,14A,15A,16A,17A,19A,25A}/afniNeedleAsTaskPreprocessed${subanalysis}.NL/mask_group+tlrc \
		    -prefix mask_overlap.7 \
		    -frac 0.7

    ## mask_overlap.7 will be at the resolution we need tthe final
    ## mask to be at. In this case it's 3x3x3
    [[ ! -f MNI_caez_N27_brain+tlrc.HEAD ]] && 3dSkullStrip -input /data/software/afni/MNI_caez_N27+tlrc. -prefix MNI_caez_N27_brain -push_to_edge -no_avoid_eyes
    [[ ! -f MNI_caez_N27_brain_3mm+tlrc.HEAD ]] && 3dresample -master mask_overlap.7+tlrc -prefix MNI_caez_N27_brain_3mm -inset MNI_caez_N27_brain+tlrc
    [[ ! -f rm_group_mask+tlrc.HEAD ]] && 3dcalc -a mask_overlap.7+tlrc -b MNI_caez_N27_brain_3mm+tlrc -expr "step(a)*step(b)" -prefix rm_group_mask

    ## now make the final mask
    3dmask_tool -dilate_input 5 -5 -fill_holes -input rm_group_mask+tlrc -prefix final_mask
    ## remove any unneeded files
    rm -f rm_*
fi

## Control the number of threads used by OMP enabled AFNI
## programs. Espacially useful to set to 1 when running multiple subjects
## in parallel on the same machine
export OMP_NUM_THREADS=10

for regLabel in NeedleAsTask.baseline ; do
    
    for gltLabel in handVsNeedle needleVsTouch handVsTouch ; do
	
	3dttest++ -mask final_mask+tlrc.HEAD													\
		  -prefix ${regLabel}.${gltLabel}.ttest.all											\
		  -Clustsim															\
		  -prefix_clustsim cc.${regLabel}.${gltLabel}											\
		  -setA CMIT															\
		  CMIT_01A $ROOT/CMIT_01A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_01A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_02A $ROOT/CMIT_02A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_02A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_04A $ROOT/CMIT_04A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_04A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_05A $ROOT/CMIT_05A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_05A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_07A $ROOT/CMIT_07A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_07A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_09A $ROOT/CMIT_09A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_09A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_11A $ROOT/CMIT_11A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_11A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_12A $ROOT/CMIT_12A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_12A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_13A $ROOT/CMIT_13A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_13A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_14A $ROOT/CMIT_14A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_14A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_15A $ROOT/CMIT_15A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_15A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_16A $ROOT/CMIT_16A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_16A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_17A $ROOT/CMIT_17A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_17A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_19A $ROOT/CMIT_19A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_19A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_25A $ROOT/CMIT_25A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_25A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]

	case $gltLabel in
	    handVsNeedle)
		stimuli=( hand needle )
	    ;;
	    needleVsTouch)
		stimuli=( needle touch )
	    ;;
	    handVsTouch)
		stimuli=( hand touch )		
	    ;;
	esac

	(
	    echo "Subj Stimulus InputFile"
	    for subject in 01A 02A 04A 05A 07A 09A 11A 12A 13A 14A 15A 16A 17A 19A 25A ; do
		for stimulus in ${stimuli[@]} ; do
		    echo "CMIT_${subject} ${stimulus} $ROOT/CMIT_${subject}/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_${subject}_REML+tlrc.HEAD[${stimulus}#0_Coef]"
		done
	    done
	) > dataTable.${regLabel}.${gltLabel}.stimuli.ttest.all.txt
	    
	cat <<EOF > dataTable.${regLabel}.${gltLabel}.glt.ttest.all.txt
Subj InputFile
CMIT_01A $ROOT/CMIT_01A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_01A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_02A $ROOT/CMIT_02A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_02A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_04A $ROOT/CMIT_04A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_04A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_05A $ROOT/CMIT_05A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_05A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_07A $ROOT/CMIT_07A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_07A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_09A $ROOT/CMIT_09A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_09A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_11A $ROOT/CMIT_11A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_11A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_12A $ROOT/CMIT_12A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_12A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_13A $ROOT/CMIT_13A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_13A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_14A $ROOT/CMIT_14A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_14A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_15A $ROOT/CMIT_15A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_15A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_16A $ROOT/CMIT_16A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_16A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_17A $ROOT/CMIT_17A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_17A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_19A $ROOT/CMIT_19A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_19A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_25A $ROOT/CMIT_25A/afniNeedleAsTaskPreprocessed${subanalysis}.NL/stats.CMIT_25A_REML+tlrc.HEAD[${gltLabel}#0_Coef]

EOF
	
    done
done
