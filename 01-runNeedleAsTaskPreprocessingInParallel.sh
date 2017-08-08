#!/bin/bash

## set -x 

programName=`basename $0`

trap exit SIGHUP SIGINT SIGTERM

GETOPT=$( which getopt )
ROOT=/data/jain/preApril
DATA=$ROOT
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

# function doZeropad {
#     local subject="$1"
#     if [[ $subject == "341_A" ]] ; then
# 	sup="-S 30"
#     fi
#     info_message_ln "Zeropadding anat and EPI for subject $subject"
#     if [[ -f $DATA/$subject/${subject}.anat_clp+orig.HEAD ]] ; then
# 	if [[ $force -eq 1 ]] || \
# 	   [[ ! -f $DATA/$subject/${subject}.anat.zp+orig.HEAD ]]  || \
# 	   [[ $DATA/$subject/${subject}.anat_clp+orig.HEAD -nt $DATA/$subject/${subject}.anat.zp+orig.HEAD ]] ; then
# 	    ( cd $DATA/$subject ; 3dZeropad -I 30 $sup -prefix ${subject}.anat.zp ${subject}.anat_clp+orig.HEAD )
# 	fi
#     else
# 	if [[ $force -eq 1 ]] || \
# 	   [[ ! -f $DATA/$subject/${subject}.anat.zp+orig.HEAD ]] || \
# 	   [[ $DATA/$subject/${subject}.anat+orig.HEAD -nt $DATA/$subject/${subject}.anat.zp+orig.HEAD ]]; then 
# 	    ( cd $DATA/$subject ; 3dZeropad -I 30 $sup -prefix ${subject}.anat.zp ${subject}.anat+orig.HEAD )
# 	fi
#     fi
#     if [[ $force -eq 1 ]] || [[ ! -f $DATA/$subject/${subject}.resting.zp+orig.HEAD ]] ; then 
# 	( cd $DATA/$subject ; 3dZeropad -I 30 $sup -prefix ${subject}.resting.zp ${subject}.resting+orig.HEAD )
#     fi
# }

GETOPT_OPTIONS=$( $GETOPT \
		      -o "e:m:o:h:b:t:nq" \
		      --longoptions "excessiveMotionThresholdFraction:,motionThreshold:,outlierThreshold:,threads:,blur:,tcat:,nonlinear,enqueue" \
		      -n ${programName} -- "$@" )
exitStatus=$?
if [ $exitStatus != 0 ] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi

## enqueue the job for execution
enqueue=0

# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-e|--excessiveMotionThresholdFraction)
	    excessiveMotionThresholdFraction=$2; shift 2 ;;	
	-m|--motionThreshold)
	    motionThreshold=$2; shift 2 ;;	
	-o|--outlierThreshold)
	    outlierThreshold=$2; shift 2 ;;	
	-h|--threads)
	    threads=$2; shift 2 ;;	
	-b|--blur)
	    blur=$2; shift 2 ;;	
	-t|--tcat)
	    tcat=$2; shift 2 ;;	
	-n|--nonlinear)
	    nonlinear=1; shift 1 ;;	
	-q|--enqueue)
	    enqueue=1; shift 1 ;;	
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

####################################################################################################
## Check that appropriate values are used to initialize arguments that
## control analysis if no values were provided on the command line

## The following values are used to exclude subjects based on the
## number of volumes censored during analysis
if [[ "x$excessiveMotionThresholdFraction" == "x" ]] ; then
    excessiveMotionThresholdFraction=0.2
    excessiveMotionThresholdPercentage=20
    warn_message_ln "No excessiveMotionThresholdFraction threshold was provided. Defaulting to $excessiveMotionThresholdFraction => ${excessiveMotionThresholdPercentage}%"
else
    excessiveMotionThresholdPercentage=$( echo "(($excessiveMotionThresholdFraction*100)+0.5)/1" | bc ) 

    info_message_ln "Using ${excessiveMotionThresholdFraction} as the subject exclusion motion cutoff fraction"
    info_message_ln "Using ${excessiveMotionThresholdPercentage}% as subject exclusion motion cutoff percentage"
    info_message_ln "Note that these values are used to exclude subjects based on the number of volumes censored during analysis"
fi


## motionThreshold and outlierThreshold are the values passed to
## afni_proc.py and are used when deciding to censor a volume or not
if [[ "x${motionThreshold}" == "x" ]] ; then
    motionThreshold=0.3
    warn_message_ln "No motionThreshold value was provided. Defaulting to $motionThreshold"
else
    info_message_ln "Using motionThreshold of ${motionThreshold}"
fi

if [[ "x${outlierThreshold}" == "x" ]] ; then
     outlierThreshold=0.2
     warn_message_ln "No outlierThreshold value was provided. Defaulting to $outlierThreshold"
else
    info_message_ln "Using outlierThreshold of ${outlierThreshold}"
fi

if [[ "x${threads}" == "x" ]] ; then
     threads=1
     warn_message_ln "No value for the number of parallel threads to use was provided. Defaulting to $threads"
else
    info_message_ln "Using threads value of ${threads}"
fi

if [[ "x${blur}" == "x" ]] ; then
     blur="8"
     warn_message_ln "No value for blur filter value to use was provided. Defaulting to $blur"
else
    info_message_ln "Using blur filter value of ${blur}"
fi

# if [[ "x${tcat}" == "x" ]] ; then
#      tcat="3"
#      warn_message_ln "No value for tcat, the number of TRs to censor from the start of each volume, was provided. Defaulting to $tcat"
# else
#     info_message_ln "Using tcat filter value of ${tcat}"
# fi

if [[ $nonlinear -eq 1 ]] ; then 
    info_message_ln "Using nonlinear alignment"
    scriptExt="NL"
else 
    info_message_ln "Using affine alignment only"
    scriptExt="aff"    
fi

####################################################################################################
if [[ "$#" -gt 0 ]] ; then
    subjects="$@"
else
    subjects=$( cd $DATA ; ls -1d CMIT* )
fi

[[ -d run ]] || mkdir run

for subject in $subjects ; do
    info_message_ln "#################################################################################################"
    info_message_ln "Generating script for subject $subject"

    if  [[ ! -f ${DATA}/$subject/NT.nii ]] ; then
	warn_message_ln "Can not find resting state EPI file for ${subject}. Skipping."
	continue
    else
	epiFile=${DATA}/$subject/NT.nii
    fi

    if  [[ ! -f ${DATA}/$subject/MPRAGE.nii ]] ; then
	warn_message_ln "Can not find anatomy file for subject ${subject}. Skipping."
	continue
    else
	anatFile=${DATA}/$subject/MPRAGE.nii
    fi

    if [[ $nonlinear -eq 1 ]] ; then 
	outputScriptName=run/run-afniNeedleAsTaskPreproc-${subject}.${scriptExt}.sh
    else
	outputScriptName=run/run-afniNeedleAsTaskPreproc-${subject}.${scriptExt}.sh	
    fi

    ## do non-linear warping? If so add the flag to the extra
    ## alignment args variable
    if [[ $nonlinear -eq 1 ]] ; then 
	extraAlignmentArgs="${extraAlignmentArgs} -tlrc_NL_warp"

	anat_base=$( basename $anatFile )
	anat_base=${anat_base%%[.+]*}
	info_message_ln "Looking for pre-existing non-linear warped T1w images in ${DATA}/${subject}/afniGriefPreprocessed.NL"
	if [[ -f ${DATA}/${subject}/afniGriefPreprocessed.NL/${anat_base}_al_keep+tlrc.HEAD ]] && \
	   [[ -f ${DATA}/${subject}/afniGriefPreprocessed.NL/anat.un.aff.Xat.1D ]] && \
	   [[ -f ${DATA}/${subject}/afniGriefPreprocessed.NL/anat.un.aff.qw_WARP.nii.gz ]] ; then
	    info_message_ln "Yay! Found them!!!"
	    info_message_ln "Supplying pre-existing nonlinear warped anatomy to afni_proc.py"
	    extraAlignmentArgs="${extraAlignmentArgs} \\
	     -tlrc_NL_warped_dsets ${DATA}/${subject}/afniGriefPreprocessed.NL/${anat_base}_al_keep+tlrc.HEAD \\
                                   ${DATA}/${subject}/afniGriefPreprocessed.NL/anat.un.aff.Xat.1D \\
                                   ${DATA}/${subject}/afniGriefPreprocessed.NL/anat.un.aff.qw_WARP.nii.gz"
	fi
    fi

    info_message_ln "Writing script: $outputScriptName"

    cat <<EOF > $outputScriptName
#!/bin/bash

set -x 

#$ -S /bin/bash

## disable compression of BRIKs/nii files
unset AFNI_COMPRESSOR

export PYTHONPATH=$AFNI_R_DIR

## use the newer faster despiking method. comment this out to get the
## old one back
export AFNI_3dDespike_NEW=YES

# turn off anoying colorization of info/warn/error messages since they
# only result in gobbledygook
export AFNI_MESSAGE_COLORIZE=NO

## only use a single thread since we're going to run so many subjects
## in parallel
export OMP_NUM_THREADS=${threads}

excessiveMotionThresholdFraction=$excessiveMotionThresholdFraction
excessiveMotionThresholdPercentage=$excessiveMotionThresholdPercentage

cd $DATA/$subject

preprocessingScript=${subject}.afniNeedleAsTaskPreprocess.8sec.$scriptExt.csh
rm -f \${preprocessingScript}

outputDir=afniNeedleAsTaskPreprocessed.8sec.$scriptExt
rm -fr \${outputDir}

motionThreshold=${motionThreshold}
outlierThreshold=${outlierThreshold}

## Convert the FSL formatted regressors to the stim_times format for
## use with AFNI

for reg_file in hand.txt needle.txt touch.txt ; do
    ## convert any mac line ending conventions to unix line ending conventions
    mac2unix \$reg_file

    ## find only lines ending in a 1,
    ##
    ## pass them to awk which then prints the first element of each
    ## line and the second element of each line separated by a :,
    ## 
    ## then convert the newlines to a space so that AFNI's stim_times
    ## convention of each row being a run are observed
    ## 
    ## save the results to the a file named after
    ## the inlut regressors except that it has stimtimes in the middle
    
    # grep  "1$" \${reg_file}  | \\
    # 	awk 'BEGIN {OFS=":"} {print \$1,\$2}' | \\
    # 	tr '\n'  ' ' > \${reg_file%%.txt}.stimtimes.txt

    ## the 8 in teh awk line here is in response to a suggestion by
    ## Felipe thet we look only at thhe first 8 seconds instead of teh
    ## whole 30 sec block
    grep  "1$" \${reg_file}  | \\
	awk 'BEGIN {OFS=":"} {print \$1,8}' | \\
	tr '\n'  ' ' > \${reg_file%%.txt}.stimtimes.8sec.txt
    
done

##	     -tcat_remove_first_trs ${tcat}					\\
## -tlrc_opts_at -init_xform AUTO_CENTER \\
## 	     -regress_censor_outliers \$outlierThreshold                 	\\

afni_proc.py -subj_id ${subject}										\\
             -script \${preprocessingScript}									\\
	     -out_dir \${outputDir}										\\
	     -blocks despike tshift align tlrc volreg blur mask	scale regress					\\
	     -copy_anat $anatFile										\\
	     -dsets $epiFile											\\
	     -tlrc_base MNI_caez_N27+tlrc									\\
	     -volreg_align_to first           									\\
	     -volreg_tlrc_warp	${extraAlignmentArgs}								\\
	     -blur_size ${blur}											\\
	     -blur_to_fwhm											\\
	     -blur_opts_B2FW "-ACF -rate 0.2 -temper"								\\
	     -mask_apply group											\\
	     -regress_reml_exec											\\
	     -regress_3dD_stop											\\
	     -regress_stim_times hand.stimtimes.8sec.txt needle.stimtimes.8sec.txt touch.stimtimes.8sec.txt			\\
	     -regress_stim_labels hand needle touch								\\
	     -regress_basis 'dmBLOCK'									\\
	     -regress_stim_types AM1 AM1 AM1                                                                \\
	     -regress_opts_3dD											\\
	     -gltsym    'SYM: hand -needle'							\\
	     -glt_label 1 handVsNeedle									\\
	     -gltsym    'SYM: needle -touch'							\\
	     -glt_label 2 needleVsTouch									\\
	     -gltsym    'SYM: hand -touch'										\\
	     -glt_label 3 handVsTouch							\\
	     -regress_apply_mot_types demean deriv								\\
             -regress_censor_motion \$motionThreshold								\\
	     -regress_censor_outliers \$outlierThreshold							\\
	     -regress_run_clustsim no										\\
	     -regress_est_blur_errts

if [[ -f \${preprocessingScript} ]] ; then 
   tcsh -xef \${preprocessingScript}

    cd \${outputDir}
    xmat_regress=X.xmat.1D 

    if [[ -f \$xmat_regress ]] ; then 

        fractionOfCensoredVolumes=\$( 1d_tool.py -infile \$xmat_regress -show_tr_run_counts frac_cen )
        numberOfCensoredVolumes=\$( 1d_tool.py -infile \$xmat_regress -show_tr_run_counts trs_cen )
        totalNumberOfVolumes=\$( 1d_tool.py -infile \$xmat_regress -show_tr_run_counts trs_no_cen )

        ## rounding method from http://www.alecjacobson.com/weblog/?p=256
        cutoff=\$( echo "((\$excessiveMotionThresholdFraction*\$totalNumberOfVolumes)+0.5)/1" | bc )
	if [[ \$numberOfCensoredVolumes -gt \$cutoff ]] ; then 

	    echo "*** A total of \$numberOfCensoredVolumes of
	    \$totalNumberOfVolumes volumes were censored which is
	    greater than \$excessiveMotionThresholdFraction
	    (n=\$cutoff) of all total volumes of this subject" > \\
		00_DO_NOT_ANALYSE_${subject}_\${excessiveMotionThresholdPercentage}percent.txt

	    echo "*** WARNING: $subject will not be analysed due to having more than \${excessiveMotionThresholdPercentage}% of their volumes censored."
	fi
	
	# make an image to check alignment
	$SCRIPTS_DIR/snapshot_volreg.sh anat_final.${subject}+tlrc pb03.${subject}.r01.volreg+tlrc ${subject}.alignment
    else
	touch 00_DO_NOT_ANALYSE_${subject}_\${excessiveMotionThresholdPercentage}percent.txt
    fi
    echo "Compressing BRIKs and nii files"
    find ./ \( -name "*.BRIK" -o -name "*.nii" \) -print0 | xargs -0 gzip
else
    echo "*** No such file \${preprocessingScript}"
    echo "*** Cannot continue"
    exit 1
fi	

EOF

    chmod +x $outputScriptName
    if [[ $enqueue -eq 1 ]] ; then
	info_message_ln "Submitting job for execution to queuing system"
	LOG_FILE=$DATA/$subject/$subject-needleAsTask-afniPreproc.${scriptExt}.log
	info_message_ln "To see progress run: tail -f $LOG_FILE"
	rm -f ${LOG_FILE}
	qsub -N needleAsTask-$subject -q all.q -j y -m n -V -wd $( pwd )  -o ${LOG_FILE} $outputScriptName
    else
	info_message_ln "Job *NOT* submitted for execution to queuing system"
	info_message_ln "Pass -q or --enqueue options to this script to do so"	
    fi

done

if [[ $enqueue -eq 1 ]] ; then 
    qstat
fi
