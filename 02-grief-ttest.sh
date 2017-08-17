#!/bin/bash
#to run this program, which will compute a 1 sample t-test on the coefficient from the glt (general linear test) of the NUM beta values in the glt, need to ensure
# -studyName, gltlabel correct, stimuli for each glt correct, subjects and pathways
# -voxel dimensions correct for mask correct (use 3dinfo)

# set -x 

trap exit SIGHUP SIGINT SIGTERM

studyName=Grief

programName=`basename $0`

ROOT=${MDD_ROOT:-/data/jain/preApril/}
SCRIPTS_DIR=${ROOT}/scripts
GROUP_RESULTS_DIR=${ROOT}/Group.results/$studyName

if [[ ! -d ${GROUP_RESULTS_DIR} ]] ; then
    mkdir -p ${GROUP_RESULTS_DIR}
fi

cd ${GROUP_RESULTS_DIR}

if [[ ! -f final_mask+tlrc.HEAD ]] ; then

    ## compute a mask of 70% overlap of all subjects' group masks
    ## the list of subjects should be the same as the list of subjects below in the 3dttest++ command
    ## Colm created a mask with at least 70% of the voxels for all subjects individual (anatomies that had been aligned to MNI brain in previous step), then masked that with the MNI brain.  
    ## So basically, a voxel was included if at least 7 out of 10 subjects had it in their aligned anatomies.  But the final mask was about the same as the MNI brain - didn't make much difference.
    [[ ! -f mask_overlap.7+tlrc.HEAD ]] && \
	3dmask_tool -input ../../CMIT_{01A,02A,04A,05A,07A,09A,11A,12A,13A,14A,15A,16A,17A,19A,22A,23A,25A}/afniGriefPreprocessed.NL/mask_group+tlrc \
		    -prefix mask_overlap.7 \
		    -frac 0.7

    ## mask_overlap.7 will be at the resolution we need tthe final
    ## mask to be at. In this case it's 3x3x3
    ## following is BASH shorthand if statement. for whole statement to evaluate to true.  both sides have to be true.  so if MNI file doesn't exist, then it "evaluates" the 3dSkullStrip, etc., which means it runs it
    ## -expr "step(a)*step(b)" this is a step function.  evaluates to 1 only if what feed in is greater than zero. step(a) takes the values from mask_veralp.7, converts to 1 if for example the info containes is a fraction
    ## and then multiples so that the rm_group_mask will only be a 1 or a zero and that is the mask used in the next step
    [[ ! -f MNI_caez_N27_brain+tlrc.HEAD ]] && 3dSkullStrip -input /data/software/afni/MNI_caez_N27+tlrc. -prefix MNI_caez_N27_brain -push_to_edge -no_avoid_eyes
    [[ ! -f MNI_caez_N27_brain_3mm+tlrc.HEAD ]] && 3dresample -master mask_overlap.7+tlrc -prefix MNI_caez_N27_brain_3mm -inset MNI_caez_N27_brain+tlrc
    [[ ! -f rm_group_mask+tlrc.HEAD ]] && 3dcalc -a mask_overlap.7+tlrc -b MNI_caez_N27_brain_3mm+tlrc -expr "step(a)*step(b)" -prefix rm_group_mask

    ## now make the final mask, because the rm_group_mask may contain holes, for example around the ventricles.  dilating out by 5 voxels, does the operation... and removes them... we think.  fills the zeros with 1s.  
    ## the wholes are internal, not on the surface
    ## could eliminate the following also if want to reduce the number of comparisons, e.g. not account for csf.  on the other hand, could just get a csf mask and subtract it using 3dcalc
    3dmask_tool -dilate_input 5 -5 -fill_holes -input rm_group_mask+tlrc -prefix final_mask
    ## remove any unneeded files
    rm -f rm_*
fi

## Control the number of threads used by OMP enabled AFNI
## programs. Espacially useful to set to 1 when running multiple t-tests
## in parallel on the same machine.  on mac, could set the number to 4 but anything else would be sluggish
export OMP_NUM_THREADS=10

for regLabel in Grief.baseline ; do
    
    for gltLabel in relativeVsStanger griefVsNeutral relativeGriefVsRelativeNeutral strangerGriefVsStrangerNeutral relativeGriefVsStrangerGrief relativeNeutralVsStrangerNeutral ; do
	
	3dttest++ -mask final_mask+tlrc.HEAD										\
		  -prefix ${regLabel}.${gltLabel}.ttest.all								\
		  -Clustsim												\
		  -prefix_clustsim cc.${regLabel}.${gltLabel}								\
		  -setA CMIT												\
		  CMIT_01A $ROOT/CMIT_01A/afniGriefPreprocessed.NL/stats.CMIT_01A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_02A $ROOT/CMIT_02A/afniGriefPreprocessed.NL/stats.CMIT_02A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_04A $ROOT/CMIT_04A/afniGriefPreprocessed.NL/stats.CMIT_04A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_05A $ROOT/CMIT_05A/afniGriefPreprocessed.NL/stats.CMIT_05A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_07A $ROOT/CMIT_07A/afniGriefPreprocessed.NL/stats.CMIT_07A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_09A $ROOT/CMIT_09A/afniGriefPreprocessed.NL/stats.CMIT_09A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_11A $ROOT/CMIT_11A/afniGriefPreprocessed.NL/stats.CMIT_11A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_12A $ROOT/CMIT_12A/afniGriefPreprocessed.NL/stats.CMIT_12A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_13A $ROOT/CMIT_13A/afniGriefPreprocessed.NL/stats.CMIT_13A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_14A $ROOT/CMIT_14A/afniGriefPreprocessed.NL/stats.CMIT_14A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_15A $ROOT/CMIT_15A/afniGriefPreprocessed.NL/stats.CMIT_15A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_16A $ROOT/CMIT_16A/afniGriefPreprocessed.NL/stats.CMIT_16A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_17A $ROOT/CMIT_17A/afniGriefPreprocessed.NL/stats.CMIT_17A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_19A $ROOT/CMIT_19A/afniGriefPreprocessed.NL/stats.CMIT_19A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_22A $ROOT/CMIT_22A/afniGriefPreprocessed.NL/stats.CMIT_22A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_23A $ROOT/CMIT_23A/afniGriefPreprocessed.NL/stats.CMIT_23A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]	\
		  CMIT_25A $ROOT/CMIT_25A/afniGriefPreprocessed.NL/stats.CMIT_25A_REML+tlrc.HEAD\[${gltLabel}#0_Coef\]

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

	## within each regLabel, creating a datatable of subjects used that has subject name, the contrasts and then the file name where the contrasts are located
	## this datatable of stimuli is used for graphing program
	(
	    echo "Subj Stimulus InputFile"
	    for subject in 01A 02A 04A 05A 07A 09A 11A 12A 13A 14A 15A 16A 17A 19A 22A 23A 25A ; do
		for stimulus in ${stimuli[@]} ; do
		    echo "CMIT_${subject} ${stimulus} $ROOT/CMIT_${subject}/afniGriefPreprocessed.NL/stats.CMIT_${subject}_REML+tlrc.HEAD[${stimulus}#0_Coef]"
		done
	    done
	) > dataTable.${regLabel}.${gltLabel}.stimuli.ttest.all.txt
	## this datatable of glt is unused currently... Colm made for the sake of completeness
	cat <<EOF > dataTable.${regLabel}.${gltLabel}.glt.ttest.all.txt
Subj InputFile
CMIT_01A $ROOT/CMIT_01A/afniGriefPreprocessed.NL/stats.CMIT_01A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_02A $ROOT/CMIT_02A/afniGriefPreprocessed.NL/stats.CMIT_02A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_04A $ROOT/CMIT_04A/afniGriefPreprocessed.NL/stats.CMIT_04A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_05A $ROOT/CMIT_05A/afniGriefPreprocessed.NL/stats.CMIT_05A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_07A $ROOT/CMIT_07A/afniGriefPreprocessed.NL/stats.CMIT_07A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_09A $ROOT/CMIT_09A/afniGriefPreprocessed.NL/stats.CMIT_09A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_11A $ROOT/CMIT_11A/afniGriefPreprocessed.NL/stats.CMIT_11A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_12A $ROOT/CMIT_12A/afniGriefPreprocessed.NL/stats.CMIT_12A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_13A $ROOT/CMIT_13A/afniGriefPreprocessed.NL/stats.CMIT_13A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_14A $ROOT/CMIT_14A/afniGriefPreprocessed.NL/stats.CMIT_14A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_15A $ROOT/CMIT_15A/afniGriefPreprocessed.NL/stats.CMIT_15A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_16A $ROOT/CMIT_16A/afniGriefPreprocessed.NL/stats.CMIT_16A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_17A $ROOT/CMIT_17A/afniGriefPreprocessed.NL/stats.CMIT_17A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_19A $ROOT/CMIT_19A/afniGriefPreprocessed.NL/stats.CMIT_19A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_22A $ROOT/CMIT_22A/afniGriefPreprocessed.NL/stats.CMIT_22A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_23A $ROOT/CMIT_23A/afniGriefPreprocessed.NL/stats.CMIT_23A_REML+tlrc.HEAD[${gltLabel}#0_Coef]	
CMIT_25A $ROOT/CMIT_25A/afniGriefPreprocessed.NL/stats.CMIT_25A_REML+tlrc.HEAD[${gltLabel}#0_Coef]

EOF
	
    done
done
