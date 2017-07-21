#!/bin/bash

## set -x 

programName=`basename $0`

trap exit SIGHUP SIGINT SIGTERM

GETOPT=$( which getopt )
ROOT=/data/jain/preApril
DATA=$ROOT
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

GETOPT_OPTIONS=$( $GETOPT \
		      -o "h:q" \
		      --longoptions "threads:,enqueue" \
		      -n ${programName} -- "$@" )
exitStatus=$?
if [ $exitStatus != 0 ] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi

## 1 = force creation of zero padded files
force=0

## enqueue the job for execution
enqueue=0

# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-h|--threads)
	    threads=$2; shift 2 ;;	
	-q|--enqueue)
	    enqueue=1; shift 1 ;;	
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

if [[ "x${threads}" == "x" ]] ; then
     threads=1
     warn_message_ln "No value for the number of parallel threads to use was provided. Defaulting to $threads"
else
    info_message_ln "Using threads value of ${threads}"
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

    if  [[ ! -f ${DATA}/$subject/Grief.nii ]] ; then
	warn_message_ln "Can not find resting state EPI file for ${subject}. Skipping."
	continue
    else
	epiFile=${DATA}/$subject/Grief.nii
    fi

    if  [[ ! -f ${DATA}/$subject/MPRAGE.nii ]] ; then
	warn_message_ln "Can not find anatomy file for subject ${subject}. Skipping."
	continue
    else
	anatFile=${DATA}/$subject/MPRAGE.nii
    fi

    if [[ -d $DATA/$subject/afniGriefPreprocessed.NL ]] ; then 
	outputScriptName=run/run-afni-grief-ppi-${subject}.sh	

	cat <<EOF > $outputScriptName
#!/bin/bash

set -x 

#$ -S /bin/bash    

export OMP_NUM_THREADS=${threads}

./ppi/01-ppi-preprocess.sh      -s ${subject}

for seedList in \$( ls $DATA/Group.results/Grief/seeds/*_seedlist.txt ) ; do
	./ppi/02-ppi-make-regressors.sh -s ${subject} -l \${seedList}   -d
	./ppi/03-ppi-postprocess.sh     -s ${subject} -l \${seedList} 
done
EOF

	chmod +x $outputScriptName
	if [[ $enqueue -eq 1 ]] ; then
	    info_message_ln "Submitting job for execution to queuing system"
	    LOG_FILE=$DATA/$subject/$subject-afni-grief-ppi.log
	    info_message_ln "To see progress run: tail -f $LOG_FILE"
	    rm -f ${LOG_FILE}
	    qsub -N grief-$subject -q all.q -j y -m n -V -wd $( pwd )  -o ${LOG_FILE} $outputScriptName
	else
	    info_message_ln "Job *NOT* submitted for execution to queuing system"
	    info_message_ln "Pass -q or --enqueue options to this script to do so"	
	fi
    else
	warn_message_ln "No such directory: $DATA/$subject/afniGriefPreprocessed.NL"
	warn_message_ln "Skipping subject"
    fi
done

if [[ $enqueue -eq 1 ]] ; then 
    qstat
fi
