#!/bin/bash

## set -x 

# if ctrl-c is typed exit immediatly
trap exit SIGHUP SIGINT SIGTERM

programName=`basename $0`

GETOPT=$( which getopt )
ROOT=/data/jain/preApril
DATA=$ROOT
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

GETOPT_OPTIONS=$( $GETOPT  -o "ds:l:" --longoptions "demean,subject:,seedlist:" -n ${programName} -- "$@" )
exitStatus=$?
if [ $exitStatus != 0 ] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi

demean_psych=0    # usually 0 (for comparison, should not matter)

# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-d|--demean)
	    demean_psych=1; shift ;;
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

cd $DATA/$subject/afniGriefPreprocessed.NL

if  [[ ! -f pb05.${subject}.r01.scale+tlrc.HEAD ]] ; then
    error_message_ln "Can not find resting state EPI file for ${subject}"
    exit 1
else
    epiFile=pb05.${subject}.r01.scale+tlrc.HEAD
fi

if  [[ ! -f anat_final.${subject}+tlrc.HEAD  ]] ; then
    error_message_ln "Can not find anatomy file for subject ${subject}"
    exit 1
else
    anatFile=anat_final.${subject}+tlrc.HEAD
fi

## preprocErrtsFile=ppi.pre.errts.${subject}+tlrc.HEAD
preprocErrtsFile=ppi.pre.errts.${subject}_REML+tlrc.HEAD
if [[ ! -f ${preprocErrtsFile} ]] ; then
    error_message_ln "Can not find preprocessed errts file for ${subject}"
    exit 1
fi

stim_files=( stimuli/{rg,rn,sg,sn}.stimtimes.txt )
stim_labs=( rg rn sg sn )

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ##
## THIS HAS TO BE DONE IN A LOOP LATER @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ##
## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ##

basis=BLOCK                          ## matches basis type in main analysis

## basis=GAM

## tell AFNI to STFU about obliquity warnings
export AFNI_NO_OBLIQUE_WARNING=YES


for seed in $seeds ; do
    seedName=${seed##*/}
    if echo $seedName | grep -q "nii" ; then 
	seedName=${seedName%%.nii*}
    else 
	seedName=${seedName%%+*}
    fi
    
    info_message_ln "#################################################################################################"
    info_message_ln "Setting up regressors for the $seedName seed" 
    info_message_ln "#################################################################################################"
    
    info_message_ln "Setting up variables"

    plabel=$seedName


    NT=( $( 3dnvals    ${epiFile} ) )    ## num time points per run
    info_message_ln "Number of TRs in the runs: ${NT[*]}"

    TR=$( 3dinfo -tr ${epiFile} )        ## the TR
    info_message_ln "TR = $TR"
    TRnup=$( echo "(${TR}* 10)/1" | bc )  ## oversample rate 10 times the TR as an integer

    # compute some items
    # rcr - validate TRup (TR must be an integral multiple of TRup)
    TRup=0.1          # basically TR/TRnup

    nstim=${#stim_files[*]}
    info_message_ln "There are $nstim stimuli"
    ## run_lens=( 300 300 300 )  # run lengths, in seconds

    declare -a run_lens
    for (( rind=0; rind < ${#NT[*]}; rind=rind+1 )) ; do
	run_lens[$rind]=$( echo "${NT[$rind]} * $TR" | bc )
    done

    info_message_ln "Run(s) are of the following length(s) (seconds): ${run_lens[*]}"
    workdir=ppi.work.$plabel
    timingdir=timing.files

    # =================================================================
    info_message_ln "Creating work directory, copy inputs, extracting seed timeseries"

    if [[ -d $workdir ]] ; then
	rm -fr $workdir  
    fi

    # create output directories and copy inputs there
    mkdir -p $workdir/$timingdir

    cp -pv ${stim_files[@]} $workdir/$timingdir

    seedTimeseries=seed_${seedName}.ts.1D
    info_message_ln "*** Extracting timeseries from seed"
    3dmaskave -mask ${seed} -quiet ${preprocErrtsFile} > $workdir/${seedTimeseries}
    info_message_ln "Seed timeseries is in: $workdir/${seedTimeseries}"

    bind=0
    cd $workdir

    # =================================================================
    info_message_ln "Generating ideal IRF"

    #
    # This generates the impulse response function for the deconvolution
    # and recovolution steps.  It is the expected response to a ~zero
    # duration event.

    if [[ $basis == "GAM" ]] ;  then

	# number of time points = duration / upsampled TR
	## dur=12         # use a 12 second curve for GAM
	
	## set the duration to the average of the duration of all the events in the stimuli files
	dur=$( cat  $timingdir/* | tr ' ' '\n' | awk -F':' '{print $2}' | 3dTstat -prefix - 1D:stdin\' 2> /dev/null )
	nt_irf=$( ccalc -i "$dur/$TRup" )

	hrf_file=x.GAM.1D
	3dDeconvolve -nodata $nt_irf 0.1 -polort -1  \
                     -num_stimts 1                   \
                     -stim_times 1 1D:0 GAM          \
                     -x1D $hrf_file -x1D_stop

    elif [[ $basis == "BLOCK" ]] ; then

	## number of time points = duration / upsampled TR
	## dur=15         # use a 15 second curve for BLOCK

	## set the duration to the average of the duration of all the events in the stimuli files
	dur=$( cat  $timingdir/* | tr ' ' '\n' | awk -F':' '{print $2}' | 3dTstat -prefix - 1D:stdin\' 2> /dev/null )
	nt_irf=$( ccalc -i "$dur/$TRup" )
	
	hrf_file=x.BLOCK.1D
	3dDeconvolve -nodata $nt_irf 0.1 -polort -1    \
                     -num_stimts 1                     \
                     -stim_times 1 1D:0 "BLOCK(0.1,1)" \
                     -x1D $hrf_file -x1D_stop
    else
	echo "** invalid basis $basis, should be BLOCK or GAM (or SPMG1)"
	exit 1
    fi

    # =================================================================
    # create timing partition files
    info_message_ln "Create timing partition files"

    (( bind=bind+1 ))

    prefix=p$bind.$plabel
    timing_prefix=$prefix

    ## for sind in $( seq 1  $nstim ) ; do
    for (( sind=0; sind < $nstim; sind=sind+1 )) ; do
	sind2=$( printf '%02d' $( expr $sind + 1 ) )
	tfile=${stim_files[$sind]}
	tfile=${tfile##*/}
	tfile=$timingdir/$tfile
	label=${stim_labs[$sind]}

	if [[ ! -f $tfile ]] ; then
	    error_message_ln "Missing timing file $tfile"
	    exit 1
	fi
	
	info_message_ln "Converting stim_times format for the ${label} stimulus to binary"
	timing_tool.py -timing $tfile					\
		       -tr $TRup					\
		       -run_len ${run_lens[@]}				\
		       -min_frac 0.3					\
		       -timing_to_1D $timing_prefix.$sind2.$label	\
		       -per_run_file -show_timing 
	
	# optionally replace psychological variables with de-meaned versions
	if [[ $demean_psych -ne 0 ]] ; then
	    mean=$( cat $timing_prefix.$sind2.* | 3dTstat -prefix - 1D:stdin\' )
	    info_message_ln "Mean of the psychological timeseries '$label' files = $mean"
	    for ff in $timing_prefix.$sind2.$label*  ; do
		1deval -a $ff -expr "a-$mean" > rm.1D
		mv rm.1D $ff
	    done
	fi
    done


    # =================================================================
    info_message_ln "Upsampling seed"

    (( bind=bind+1 ))
    prefix=p$bind.$plabel

    # break into n runs

    rstart=$(( -${NT[0]} ))
    rend=$(( -1 ))
    for (( rind=1; rind <= ${#NT[*]}; rind=rind+1 )) ; do
	rstart=$(( rstart + ${NT[$rind - 1]} ))
	rend=$(( rend + ${NT[$rind - 1]} ))
	
	1dcat ${seedTimeseries}"{$rstart..$rend}" | \
	    1dUpsample $TRnup stdin: \
		       > $prefix.seed.$TRnup.r$rind.1D
    done

    seed_up=$prefix.seed.$TRnup.rall.1D
    cat $prefix.seed.$TRnup.r[0-9]*.1D > $seed_up

    # =================================================================
    info_message_ln "Deconvolving"

    pprev=$prefix
    (( bind=bind+1 ))
    prefix=p$bind.$plabel
    neuro_prefix=$prefix

    for rind in  $( seq 1 ${#NT[*]} ) ; do
	3dTfitter -RHS $pprev.seed.$TRnup.r$rind.1D                  \
		  -FALTUNG $hrf_file temp.1D 012 -2  \
		  -l2lasso -6
	1dtranspose temp.1D > $prefix.neuro.r$rind.1D
    done

    # ===========================================================================
    info_message_ln "Partitioning neuro seeds"

    pprev=$prefix
    (( bind=bind+1 ))
    prefix=p$bind.$plabel

    #for sind in $(seq 1 $nstim ) ; do
    #    sind2=$( printf '%02d' $sind )
    for (( sind=0; sind < $nstim; sind=sind+1 )) ; do
	sind2=$( printf '%02d' $( expr $sind + 1 ) )
	slab=$sind2.${stim_labs[$sind]}

	for rind in $( seq 1 ${#NT[*]} ) ; do
	    info_message_ln "Computing partitioning for stimulus ($sind) ${stim_labs[$sind]} in run $rind"
	    neuro_seed=$neuro_prefix.neuro.r$rind.1D
	    rind2=$( printf '%02d' $rind )
	    (( nt = ${NT[$rind - 1]} * $TRnup ))
	    
	    # note partition files: 1 input, 2 outputs
	    stim_part=$timing_prefix.${slab}_r$rind2.1D
	    neuro_part=$prefix.a.$slab.r$rind.neuro_part.1D
	    recon_part=$prefix.b.$slab.r$rind.reBOLD.1D
	    
	    1deval -a $neuro_seed -b $stim_part -expr 'a*b' > $neuro_part
	    
	    waver -FILE $TRup $hrf_file -input $neuro_part -numout $nt > $recon_part
	done

	# and generate upsampled seeds that span runs
	cat $prefix.b.$slab.r*.reBOLD.1D > $prefix.d.$slab.rall.reBOLD.1D
    done

    # and generate corresponding (reBOLD) seed time series
    for rind in $( seq 1 ${#NT[*]} ) ; do
	neuro_seed=$neuro_prefix.neuro.r$rind.1D
	waver -FILE $TRup $hrf_file -input $neuro_seed -numout $nt \
              > $prefix.c.seed.r$rind.reBOLD.1D
    done

    # to compare with $seed_up
    3dMean -sum -prefix - $prefix.d.[0-9]*.1D > $prefix.d.task.rall.reBOLD.1D
    cat $prefix.c.seed.r*.reBOLD.1D > $prefix.d.seed.rall.reBOLD.1D
    info_message_ln "You can compare upsampled seeds: $seed_up $prefix.d.{seed,task}.rall.reBOLD.1D"
    seed_rebold_up=$prefix.d.seed.rall.reBOLD.1D

    # ===========================================================================
    info_message_ln "Downsampling"

    pprev=$prefix
    (( bind=bind+1 ))
    prefix=p$bind.$plabel

    for rind in $( seq 1 ${#NT[*]} ) ; do
	neuro_seed=$neuro_prefix.neuro.r$rind.1D
	(( nt = ${NT[$rind - 1]} * $TRnup ))

	for (( sind=0; sind < $nstim; sind=sind+1 )) ; do
	    sind2=$( printf '%02d' $( expr $sind + 1 ) )
	    
	    recon_part=$pprev.b.$sind2.${stim_labs[$sind]}.r$rind.reBOLD.1D
	    recon_down=$prefix.$sind2.${stim_labs[$sind]}.r$rind.PPIdown.1D

	    1dcat $recon_part'{0..$('$TRnup')}' > $recon_down
	done

	# and downsample filtered seed time series
	1dcat $seed_rebold_up'{0..$('$TRnup')}' > ${seedTimeseries%%.ts.1D}.reBOLD.1D
    done

    # ===========================================================================
    info_message_ln "Catentating across runs: final PPI regressors"

    pprev=$prefix
    (( bind=bind+1 ))

    prefix=p$bind.$plabel

    #for sind in $(seq 1 $nstim ) ; do
    #    sind2=$( printf '%02d' $sind )
    for (( sind=0; sind < $nstim; sind=sind+1 )) ; do
	sind2=$( printf '%02d' $( expr $sind + 1 ) )    
	slab=$sind2.${stim_labs[$sind]}

	cat $pprev.$slab.r*.PPIdown.1D > $prefix.$slab.rall.PPI.1D
    done

    # =================================================================
    # make a final comparison time series

    pprev=$prefix
    (( bind=bind + 1 ))
    prefix=p$bind.$plabel

    3dMean -sum -prefix - $pprev.* > $prefix.sum.PPI.1D

    info_message_ln "== You can compare original seed to sum of PPI regressors:"
    info_message_ln "   1dplot -one $seedTimeseries $prefix.sum.PPI.1D"

    1dplot -ps -one $seedTimeseries $prefix.sum.PPI.1D | gs -r300 -dORIENT1=false -sDEVICE=pdfwrite -sOutputFile=$prefix.sum.PPI.pdf -q -dBATCH -
    
    info_message_ln ""
    info_message_ln "== Final PPI regressors for this seed:  $seedTimeseries $( ls $pprev.* | tr '\n' ' ' )"

    info_message_ln "Copying final PPI regressors to parent stimuli directory)"
    cp -v $seedTimeseries $pprev.* ../stimuli

    cd ../
done
