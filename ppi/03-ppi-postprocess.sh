#!/bin/bash

## set -x 

# if ctrl-c is typed exit immediatly
trap exit SIGHUP SIGINT SIGTERM
#This script does the PPI analysis. Note a lot to change in file pathways and afniproc if repurposing
programName=`basename $0`

GETOPT=$( which getopt )
ROOT=/data/jain/preApril
DATA=$ROOT
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

GETOPT_OPTIONS=$( $GETOPT  -o "s:l:" --longoptions "subject:,seedlist:" -n ${programName} -- "$@" )
exitStatus=$?
if [ $exitStatus != 0 ] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi

# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-s|--subject)
	    subject=$2; shift 2 ;;
	-l|--seedlist)
	    seedList=$2; shift 2 ;;
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

if [ -z $subject ] ; then 
    echo "*** ERROR: The subject ID was not provided. Exiting"
    exit
fi

if [ ! -f $seedList ] ; then
    echo "*** ERROR: The seed list file does not exit. Exiting"
    exit
else 
    seeds=$( eval echo $( cat $seedList ) )
fi

echo "*** Computing PPI regressors for the following seeds:"
echo $seeds

if  [[ ! -f ${DATA}/$subject/Grief.nii ]] ; then
    error_message_ln "Can not find resting state EPI file for ${subject}. Skipping."
    exit 1
else
    epiFile=${DATA}/$subject/Grief.nii
fi

if  [[ ! -f ${DATA}/$subject/MPRAGE.nii ]] ; then
    error_message_ln "Can not find anatomy file for subject ${subject}. Skipping."
    exit 1
else
    anatFile=${DATA}/$subject/MPRAGE.nii
fi

cd $DATA/$subject/afniGriefPreprocessed.NL

## note that these variables should be the same as in the
## 01-runGriefPreprocessingInParalle.sh script
extraAlignmentArgs="${extraAlignmentArgs} -tlrc_NL_warp"
blur="8"
motionThreshold=0.3
outlierThreshold=0.2

for seed in $seeds ; do
    seedName=${seed##*/}
    if echo $seedName | grep -q "nii" ; then 
	seedName=${seedName%%.nii*}
    else 
	seedName=${seedName%%+*}
    fi
    
    info_message_ln "#################################################################################################"
    info_message_ln "Creating PPI post-processing scripts for the $seedName seed" 
    info_message_ln "#################################################################################################"

    ppiPostprocessingScript=03-ppi-postproc-${subject}-${seedName}.csh
    deconPrefix=ppi.post.${seedName}.
    afni_proc.py										\
	-subj_id ${subject}									\
	-write_3dD_script ${ppiPostprocessingScript}						\
	-write_3dD_prefix ${deconPrefix}							\
	-script ppi.post.proc.${subject}.${sedName} -scr_overwrite				\
	-blocks despike tshift align tlrc volreg blur mask scale regress			\
	-copy_anat $anatFile									\
	-dsets $epiFile										\
	-tlrc_base MNI_caez_N27+tlrc								\
	-volreg_align_to first									\
	-volreg_tlrc_warp	${extraAlignmentArgs}						\
	-blur_size ${blur}									\
	-blur_to_fwhm										\
	-blur_opts_B2FW "-ACF -rate 0.2 -temper"						\
	-mask_apply group									\
	-regress_reml_exec									\
	-regress_stim_times									\
		../rg.stimtimes.txt ../rn.stimtimes.txt ../sg.stimtimes.txt ../sn.stimtimes.txt	\
	-regress_stim_labels rg rn sg sn							\
	-regress_basis 'dmBLOCK'								\
	-regress_stim_types AM1 AM1 AM1 AM1							\
	-regress_extra_stim_files								\
    		stimuli/p6.${seedName}.01.rg.rall.PPI.1D					\
		stimuli/p6.${seedName}.02.rn.rall.PPI.1D					\
    		stimuli/p6.${seedName}.03.sg.rall.PPI.1D					\
    		stimuli/p6.${seedName}.04.sn.rall.PPI.1D					\
    		stimuli/seed_${seedName}.ts.1D							\
	-regress_extra_stim_labels PPI.rg PPI.rn PPI.sg PPI.sn PPI.seed				\
	-regress_opts_3dD									\
	-num_glt 12										\
	-gltsym    'SYM: 0.5*rg +0.5*rn -0.5*sg -0.5*sn'					\
	-glt_label 1 relativeVsStanger								\
	-gltsym    'SYM: 0.5*rg +0.5*sg -0.5*rn -0.5*sn'					\
	-glt_label 2 griefVsNeutral								\
	-gltsym    'SYM: rg -rn'								\
	-glt_label 3 relativeGriefVsRelativeNeutral						\
	-gltsym    'SYM: sg -sn'								\
	-glt_label 4 strangerGriefVsStrangerNeutral						\
	-gltsym    'SYM: rg -sg'								\
	-glt_label 5 relativeGriefVsStrangerGrief						\
	-gltsym    'SYM: rn -sn'								\
	-glt_label 6 relativeNeutralVsStrangerNeutral						\
	-gltsym    'SYM: 0.5*PPI.rg +0.5*PPI.rn -0.5*PPI.sg -0.5*PPI.sn'			\
	-glt_label 7 PPI.relativeVsStanger							\
	-gltsym    'SYM: 0.5*PPI.rg +0.5*PPI.sg -0.5*PPI.rn -0.5*PPI.sn'			\
	-glt_label 8 PPI.griefVsNeutral								\
	-gltsym    'SYM: PPI.rg -PPI.rn'							\
	-glt_label 9 PPI.relativeGriefVsRelativeNeutral						\
	-gltsym    'SYM: PPI.sg -PPI.sn'							\
	-glt_label 10 PPI.strangerGriefVsStrangerNeutral					\
	-gltsym    'SYM: PPI.rg -PPI.sg'							\
	-glt_label 11 PPI.relativeGriefVsStrangerGrief						\
	-gltsym    'SYM: PPI.rn -PPI.sn'							\
	-glt_label 12 PPI.relativeNeutralVsStrangerNeutral					\
	-regress_apply_mot_types demean deriv							\
	-regress_censor_motion $motionThreshold							\
	-regress_censor_outliers $outlierThreshold						\
	-regress_compute_fitts									\
	-regress_make_ideal_sum ${deconPrefix}sum_ideal.1D					\
	-regress_est_blur_epits									\
	-regress_est_blur_errts									\
	-regress_run_clustsim no								\

    if [[ -f ${ppiPostprocessingScript} ]] ; then
	## now execute the new 3dDeconvolve script
	tcsh -xef ${ppiPostprocessingScript}

	mv  -f ppi.REML_cmd ${deconPrefix}REML_cmd
	chmod +x ${deconPrefix}REML_cmd
	./${deconPrefix}REML_cmd
    fi
done
