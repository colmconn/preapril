#!/bin/bash

## set -x 

# if ctrl-c is typed exit immediatly
trap exit SIGHUP SIGINT SIGTERM

programName=`basename $0`

GETOPT=$( which getopt )
ROOT=${MDD_ROOT:-/data/jain/preApril/}
DATA=$ROOT/data
MDD_STANDARD=$ROOT/standard
MDD_TISSUEPRIORS=$ROOT/tissuepriors
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

logDir=${DATA}/log
GETOPT_OPTIONS=$( $GETOPT  -o "g:r:e:" \
			   --longoptions "glts:,results:,regLabel:" \
			   -n ${programName} -- "$@" )
exitStatus=$?
if [[ $exitStatus != 0 ]] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi


# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-r|--results)
	    GROUP_RESULTS=$2;
	    shift 2 ;;
	-g|--glts)
	    glts="$2";
	    shift 2 ;;
	-e|--regLabel)
	    regLabel="$2";
	    shift 2 ;;	
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

if [[ "x$glts" == "x" ]] ; then
    error_message_ln "No value provided for the GLTs. Cannot continue. Please rerun this script and provide the -g or --glts argument"
    exit 1
else
    info_message_ln "Clustering the following GLTs: ${glts}"
fi

if [[ "x$regLabel" == "x" ]] ; then
    error_message_ln "No value provided for the regLabel. Cannot continue. Please rerun this script and provide the -e or --regLabel argument"
    exit 1
else
    info_message_ln "Clustering the following regLabel: ${regLabel}"
fi

GROUP_RESULTS=$( readlink -f $GROUP_RESULTS )
if [[ ! -d "$GROUP_RESULTS" ]] ; then
    error_message_ln "No such directory: $GROUP_RESULTS"
    error_message_ln "Cannot continue."
    exit 1
fi

info_message_ln "Will use group results files in $GROUP_RESULTS"

cd $GROUP_RESULTS

[[ -d seeds ]] || mkdir seeds

for gltLabel in $glts ; do

    infix=${regLabel}.${gltLabel}
    
    clorderFile=clorder.$infix+tlrc.HEAD
    info_message_ln "Cluster order file is: $clorderFile"

    if [[ -f $clorderFile ]] ; then 
	nClusters=$( 3dBrickStat -max ${clorderFile} | awk '{print $1}' )
	
	if [[ $nClusters -gt 0 ]] ; then
	    info_message_ln  "There are ${nClusters} cluster for the ${gltLabel}"
	    
	    cat /dev/null > seeds/${gltLabel}_seedlist.txt
	    for (( ii=1; ii<=$nClusters; ii=ii+1 )) ; do
		seedFilePrefix="seeds/${gltLabel}_seed_$( printf "%02d" ${ii} )"
		3dcalc -a ${clorderFile} -expr "equals(a, $ii)" -prefix ${seedFilePrefix}
		echo "$GROUP_RESULTS/${seedFilePrefix}+tlrc.HEAD" >> seeds/${gltLabel}_seedlist.txt
	    done
	fi
    else
	warn_message_ln "No clusters found for ${gltLabel}"
    fi
    
done
