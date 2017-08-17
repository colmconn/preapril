#!/bin/bash

## set -x 

# if ctrl-c is typed exit immediatly
trap exit SIGHUP SIGINT SIGTERM

###NOTE only two instances of Grief need to be changed for repurposing!!!

# this is specific for 1 glt and variable
# note that this script is called by script 10, if any changes made specifically may invalidate script 10.
# this corrects multiple comparisons differently from the t-tests because it's a regression.  Takes average smoothness of individual subjects
# and provides those to 3dclustsim, then 3dclustsim runs simulations that it uses / provides data.  A bunch of command line arguments for t-test
#clustering are not applicable here

programName=`basename $0`

GETOPT=$( which getopt )
ROOT=${MDD_ROOT:-/data/jain/preApril/}
DATA=$ROOT/data
MDD_STANDARD=$ROOT/standard
MDD_TISSUEPRIORS=$ROOT/tissuepriors
SCRIPTS_DIR=${ROOT}/scripts

logDir=${DATA}/log
GETOPT_OPTIONS=$( $GETOPT  -o "g:on:p:c:s:d:r:x:e:i:" \
			   --longoptions "glts:,overwrite,nn:,pvalue:,cpvalue:,sided,data:,results:,prefix_clustsim:,regvar:,infix:" \
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
	-p|--pvalue)
	    pValue=$2;
	    shift 2 ;;
	-c|--cpvalue)
	    cPvalue=$2;
	    shift 2 ;;
	-n|--nn)
	    NN=$2; 
	    shift 2 ;;
	-s|--sided )
	    ss=$2
	    if [[ $ss == "1" ]] ; then 
		side="1"
	    elif [[ $ss == "2" ]] ; then 
		side="2"
	    elif [[ $ss == "bi" ]] ; then 
		side="bi"
	    else
		echo "Unknown argument provided to -s or --sided. Valid values are 1, 2, and bi. Defaulting to 1-sided"
		side="1"		
	    fi
	    shift 2 ;;	
	-o|--overwrite ) 
	    overwrite=1; 
	    shift ;;
	-d|--data)
	    GROUP_DATA=$2;
	    shift 2 ;;
	-r|--results)
	    GROUP_RESULTS=$2;
	    shift 2 ;;
	-g|--glts)
	    glts="$2";
	    shift 2 ;;
	-x|--prefix_clustsim)
	    csimprefix="$2";
	    shift 2 ;;
	-e|--regvar)
	    regressionVariable="$2";
	    shift 2 ;;
	-i|--infix)
	    infix="$2";
	    shift 2 ;;
	
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done


function pickLatestBucketFile {
    
    local prefix=$1
    local latest=$( ls -1t ${prefix}*+tlrc.HEAD | head -1 ) 

    if [ "x$latest" == "x" ] || [ ! -f $latest ] ; then
	exit
    fi
    echo $latest
}

function extractCoefBrikId {
    local rvName=$1
    local bucketFilename=$2
    
    label=$( 3dinfo -label $bucketFilename | tr "|" "\n" | grep "${rvName}.Value"  2> /dev/null )
    id=$( 3dinfo -label2index $label $bucketFilename 2> /dev/null )
    
    echo $id
}

function extractTStatpars {
    local rvName=$1
    local bucketFilename=$2

    a=$(3dAttribute BRICK_STATSYM $bucketFilename"[${rvName}.t.value]" )
    b=${a##*(}
    c=${b%%)*}

    echo $( echo $c | tr "," " " )
}

if [ "x$NN" == "x" ] ; then 
    ## nearest neighbour 1=touching at faces, 2=faces and edges 3=faces,
    ## edges and corners, just like in the afni clusterize window

    echo "No argument provided to -n or --nn. Defaulting to 1 (touching faces)."
    NN=1
fi

case $NN in
    1)
	rmm=1.01
	;;
    2)
	rmm=1.44
	;;
    3)
	rmm=1.75
	;;

    *) 
	echo "Unknown value ($NN) for NN. Exiting."
	exit 2 ;;
esac

if [[ "x$pValue" == "x" ]] ; then
    ## voxelwise pvalue
    pValue=0.05
    echo "*** Set voxelwise pvalue to $pValue (default)"
else
    echo "*** Set voxelwise pvalue to $pValue"
fi

if [[ "x$cPvalue" == "x" ]] ; then
    # clusterwise pvalue
    cPvalue=0.050
    echo "*** Set whole brain pvalue to $cPvalue (default)"	    
else
    useFirstColumn=1
    echo "*** Set whole brain pvalue to $cPvalue"    
fi

if [[ "x$side" == "x" ]] ; then
    echo "*** No value provided for side. Defaulting to 1sided"
    side="1"
else
    echo "*** Running a $side test"
fi

if [[ "x$glts" == "x" ]] ; then
    echo "*** No value provided for the GLTs. Cannot continue. Please rerun this script and provide the -g or --glts argument"
    exit 1
else
    echo "*** Clustering the following GLTs: ${glts}"
fi

if [[ "x$regressionVariable" == "x" ]] ; then
    echo "*** No value provided for the regressionVariable. Cannot continue. Please rerun this script and provide the -e or --regvar argument"
    exit 1
else
    echo "*** Clustering the following regression variable: ${regressionVariable}"
fi

if [[ "x$infix" == "x" ]] ; then
    echo "*** No value provided for the infix. Cannot continue. Please rerun this script and provide the -i or --infix argument"
    exit 1
else
    echo "*** Infix: ${infix}"
fi

if [[ "x$csimprefix" == "x" ]] ; then
    echo "*** No value provided for the csimprefix. Cannot continue. Please rerun this script and provide the -x or --prefix_clustsim argument"
    exit 1
else
    echo "*** 3dClustSim file prefix: ${csimprefix}"
fi


if [[ "x$GROUP_DATA" == "x" ]] ; then
    echo "*** No value provided for GROUP_DATA (-d or --data). Cannot continue."
    exit
fi

if [[ "x$GROUP_RESULTS" == "x" ]] ; then
    echo "*** No value provided for GROUP_RESULTS (-r or --results). Cannot continue."
    exit
fi

GROUP_DATA=$( readlink -f $GROUP_DATA )
if [[ ! -d "$GROUP_DATA" ]] ; then
    echo "*** No such directory: $GROUP_DATA"
    echo "Cannot continue."
    exit 1
fi

GROUP_RESULTS=$( readlink -f $GROUP_RESULTS )
if [[ ! -d "$GROUP_RESULTS" ]] ; then
    echo "*** No such directory: $GROUP_RESULTS"
    echo "Cannot continue."
    exit 1
fi

echo "*** Will use data          files in $GROUP_DATA"
echo "*** Will use group results files in $GROUP_RESULTS"

cd $GROUP_RESULTS

csvFile=parameters.csv

if [[ $overwrite -eq 1 ]] || [[ ! -f $csvFile ]] ; then 
    echo "regressionVariable,infix,coefficientBrikId,statBrikId,threshold,DoF,rmm,nVoxels,pValue,cPvalue,nClusters,rlmBucketFile" > $csvFile
fi

# infix="${gltLabel}.analysis.one.delta.grief.scaled"
# regressionVariable="delta.grief.scaled"
    
dataTableFilename=$GROUP_DATA/dataTable.${infix}.tab
echo "*** Data table file is: $dataTableFilename"

rlmBucketFilePrefix=stats.${infix}
rlmBucketFile=$( pickLatestBucketFile $rlmBucketFilePrefix )
echo "*** Robust regression bucket file is: $rlmBucketFile"    

coefBrikId=$( 3dinfo -label2index "${regressionVariable}.Value" $rlmBucketFile 2> /dev/null )    
statBrikId=$( 3dinfo -label2index "${regressionVariable}.t.value" $rlmBucketFile 2> /dev/null )

## now we need to estimate the average smoothing of the data to feed to 3dClustSim

# first up get the list of subjects in the analysis
if [[ ! -f $GROUP_RESULTS/blur.err_reml.1D ]] || [[ ! -s $GROUP_RESULTS/blur.err_reml.1D ]] ; then 
    cat /dev/null > $GROUP_RESULTS/blur.err_reml.1D
    subjects=$( cat ${dataTableFilename} | awk '{ print $1 }' | sed 1d )

    ## now get the ACF values for each subject (A and B (only for non-baseline analysis) timepoints) in the analysis
    ## ACF is the autocorrelation function, estimate of the averaged parameters across subjects. stored in last row.  that is tail -1, then saved to the 1D file then used later
    for subject in $subjects ; do
	tail -1 $( dirname $SCRIPTS_DIR )/${subject}A/afniGriefPreprocessed.NL/blur.err_reml.1D >> $GROUP_RESULTS/blur.err_reml.1D
	## if baseline is in the infix, then DO NOT include the B
	## timepoint subjects in the blur.err_reml.1D file
	if [[ ! ${infix} =~ "baseline" ]] ; then 
	    tail -1 $( dirname $SCRIPTS_DIR )/${subject}B/afniGriefPreprocessed.NL/blur.err_reml.1D >> $GROUP_RESULTS/blur.err_reml.1D
	fi
    done
else
    echo "*** Found pre-existing $GROUP_RESULTS/blur.err_reml.1D"
fi

## average each of the ACF values in each column in the $GROUP_RESULTS/blur.err_reml.1D
nColumns=$( head -1 $GROUP_RESULTS/blur.err_reml.1D | wc -w  )
declare -a avgAcf
for (( ind=0; ind < $nColumns; ind=ind+1 )) ; do
    ind2=$( expr $ind + 1 )
    avgAcf[${ind}]=$( cat $GROUP_RESULTS/blur.err_reml.1D | awk -v N=${ind2} '{ sum += $N } END { if (NR > 0) print sum / NR }' )
done

echo "*** Average ACF values = ${avgAcf[@]}"

## now we need to run 3dClustSim
## if [[ ! -f $GROUP_RESULTS/${csimprefix}.${infix}.NN${NN}_${side}sided.1D ]] ; then
if [[ ! -f $GROUP_RESULTS/${csimprefix}.NN${NN}_${side}sided.1D ]] ; then     
    ## 3dClustSim -nodec -LOTS -acf ${avgAcf[0]} ${avgAcf[1]} ${avgAcf[2]} -prefix ${csimprefix}.${infix} -mask final_mask+tlrc.HEAD
    ## same subjects in all regressions so we onlyneed to run this once not once per regression
    3dClustSim -nodec -LOTS -acf ${avgAcf[0]} ${avgAcf[1]} ${avgAcf[2]} -prefix ${csimprefix} -mask final_mask+tlrc.HEAD    
fi

## nVoxels=$( $SCRIPTS_DIR/get.minimum.voxel.count.r --nn $NN --alpha=$cPvalue --pthr=$pValue --side=$side --csimfile=$GROUP_RESULTS/${csimprefix}.${infix}.NN${NN}_${side}sided.1D )
nVoxels=$( $SCRIPTS_DIR/get.minimum.voxel.count.r --nn $NN --alpha=$cPvalue --pthr=$pValue --side=$side --csimfile=$GROUP_RESULTS/${csimprefix}.NN${NN}_${side}sided.1D )
if [[ "x$nVoxels" == "x" ]] ; then
    echo "*** Couldn't get the correct number of voxels to go with pvalue=$pValue and corrected pvalue=$cPvalue"
    echo "*** You may need to pad these values with zeros to ensure you match the correct row and column in $cstempPrefix.NN${NN}_${side}.1D"
    exit
fi
## this is useful if the t test is stored as such instead of a zscore
df=$( extractTStatpars $regressionVariable $rlmBucketFile )    

threshold=$( cdf -p2t fitt $pValue $df | sed 's/t = //' )
echo "*** coefBrikId = $coefBrikId"
echo "*** statBrikId = $statBrikId"
echo "*** threshold = $threshold"
echo "*** rmm = $rmm"
echo "*** nVoxels = $nVoxels"
echo "*** degrees of freedom = $df"
echo "*** voxelwise pValue = $pValue"
echo "*** corrected  pValue = $cPvalue"

3dmerge -session . -prefix clorder.$infix \
	-2thresh -$threshold $threshold \
	-1clust_order $rmm $nVoxels \
	-dxyz=1 \
	-1dindex $coefBrikId -1tindex $statBrikId  -nozero \
	$rlmBucketFile

if [[ -f clorder.$infix+tlrc.HEAD ]] ; then 
    3dclust -1Dformat -nosum -dxyz=1 $rmm $nVoxels clorder.$infix+tlrc.HEAD > clust.$infix.txt
    
    3dcalc -a clorder.${infix}+tlrc.HEAD -b ${rlmBucketFile}\[$statBrikId\] -expr "step(a)*b" -prefix clust.$infix
    
    nClusters=$( 3dBrickStat -max clorder.$infix+tlrc.HEAD 2> /dev/null | tr -d ' ' )
    
    columnNumber=$( head -1 $dataTableFilename | tr '[[:space:]]' '\n' | grep -n InputFile | cut -f1 -d':' )
    if [[ -z $columnNumber ]] ; then
	echo "Couldn't find a column named InputFile in $dataTableFilename"
	echo "*** Cannot continue"
	exit 1
    fi
    
    3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD $( tail -n +2 $dataTableFilename |     awk -v cn=$columnNumber '{ print $cn }' ) > roiStats.$infix.txt
    
    3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${rlmBucketFile}\[$coefBrikId\]      > roiStats.$infix.averageCoefficientValue.txt
    3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${rlmBucketFile}\[$statBrikId\]      > roiStats.$infix.averageTValue.txt
    
    echo "$df" > text.$infix.degreesOfFreedom.txt
    3drefit -cmap INT_CMAP clorder.$infix+tlrc.HEAD
    
else
    nClusters=0
    echo "*** WARNING No clusters found!"
fi
echo "$regressionVariable,$infix,$coefBrikId,$statBrikId,$threshold,$df,$rmm,$nVoxels,$pValue,$cPvalue,$nClusters,$rlmBucketFile" >> $csvFile

cd $SCRIPTS_DIR
##echo "*** Making cluster location tables using Maximum intensity"
##./cluster2Table.pl --space=mni --force -mi $GROUP_RESULTS

echo "*** Making cluster location tables using Center of Mass"
./cluster2Table.pl --space=mni $GROUP_RESULTS
