#!/bin/bash

set -x 

# if ctrl-c is typed exit immediatly
trap exit SIGHUP SIGINT SIGTERM

programName=`basename $0`

GETOPT=$( which getopt )
ROOT=/data/jain/preApril
DATA=$ROOT
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

GETOPT_OPTIONS=$( $GETOPT  -o "s:" --longoptions "subject:" -n ${programName} -- "$@" )
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

preprocessingScript=01-ppi-preprocess-${subject}.csh
rm -f ${preprocessingScript}

extraAlignmentArgs="${extraAlignmentArgs} -tlrc_NL_warp"
blur="8"

#this afni_proc should be similar to the main group analysis except for the write_3d .. commands and exclusion of censoring
deconPrefix=ppi.pre.
afni_proc.py										\
    -subj_id ${subject}									\
    -write_3dD_script ${preprocessingScript}						\
    -write_3dD_prefix ${deconPrefix}							\
    -blocks despike tshift align tlrc volreg blur mask	scale regress			\
    -copy_anat $anatFile								\
    -dsets $epiFile									\
    -tlrc_base MNI_caez_N27+tlrc							\
    -volreg_align_to first								\
    -volreg_tlrc_warp	${extraAlignmentArgs}						\
    -blur_size ${blur}									\
    -blur_to_fwhm									\
    -blur_opts_B2FW "-ACF -rate 0.2 -temper"						\
    -mask_apply group									\
    -regress_reml_exec									\
    -regress_stim_times  								\
	../rg.stimtimes.txt ../rn.stimtimes.txt ../sg.stimtimes.txt ../sn.stimtimes.txt	\
    -regress_stim_labels rg rn sg sn							\
    -regress_basis 'dmBLOCK'								\
    -regress_stim_types AM1 AM1 AM1 AM1							\
    -regress_opts_3dD									\
    -gltsym    'SYM: 0.5*rg +0.5*rn -0.5*sg -0.5*sn'					\
    -glt_label 1 relativeVsStanger							\
    -gltsym    'SYM: 0.5*rg +0.5*sg -0.5*rn -0.5*sn'					\
    -glt_label 2 griefVsNeutral								\
    -gltsym    'SYM: rg -rn'								\
    -glt_label 3 relativeGriefVsRelativeNeutral						\
    -gltsym    'SYM: sg -sn'								\
    -glt_label 4 strangerGriefVsStrangerNeutral						\
    -gltsym    'SYM: rg -sg'								\
    -glt_label 5 relativeGriefVsStrangerGrief						\
    -gltsym    'SYM: rn -sn'								\
    -glt_label 6 relativeNeutralVsStrangerNeutral					\
    -regress_apply_mot_types demean deriv						\
    -regress_est_blur_epits								\
    -regress_est_blur_errts								\
    -regress_run_clustsim no

if [[ -f ${preprocessingScript} ]] ; then
    ## now execute the new 3dDeconvolve script
    tcsh -xef ${preprocessingScript}

    mv  -f ppi.REML_cmd ${deconPrefix}REML_cmd
    chmod +x ${deconPrefix}REML_cmd
    ./${deconPrefix}REML_cmd
fi
