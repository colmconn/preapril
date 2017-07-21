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
scriptsDir=${ROOT}/scripts

logDir=${DATA}/log
GETOPT_OPTIONS=$( $GETOPT  -o "g:on:p:c:s:d:r:x:e:" \
			   --longoptions "glts:,overwrite,nn:,pvalue:,cpvalue:,sided,data:,results:,prefix_clustsim:,regLabel:" \
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

function extractTStatpars {
    local bucket="$1"
    local subbrikId="$2"

    a=$(3dAttribute BRICK_STATSYM $bucket"[$subbrikId]" )
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

if [[ "x$regLabel" == "x" ]] ; then
    echo "*** No value provided for the regLabel. Cannot continue. Please rerun this script and provide the -e or --regLabel argument"
    exit 1
else
    echo "*** Clustering the following regLabel: ${regLabel}"
fi

if [[ "x$csimprefix" == "x" ]] ; then
    echo "*** No value provided for the csimprefix. Cannot continue. Please rerun this script and provide the -x or --prefix_clustsim argument"
    exit 1
else
    echo "*** Clustering the following regLabel: ${regLabel}"
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
    echo "regLabel,gltLabel,contrastBrikId,statBrikId,threshold,rmm,nVoxels,pValue,cPvalue,nClusters,tTestFile" > $csvFile
fi

labelPrefix="CMIT"

for gltLabel in $glts ; do

    gltDataTableFilename=$GROUP_DATA/dataTable.${regLabel}.${gltLabel}.glt.ttest.all.txt
    echo "### GLT data table file is: $dataTableFilename"

    stimuliDataTableFilename=$GROUP_DATA/dataTable.${regLabel}.${gltLabel}.stimuli.ttest.all.txt
    echo "### Stimuli data table file is: $dataTableFilename"
    
    tTestFile=${regLabel}.${gltLabel}.ttest.all+tlrc
    echo "### T-test file is: $tTestFile"    
        
    statBrikId=$( 3dinfo -label2index "${labelPrefix}_Zscr" $tTestFile 2> /dev/null )
    contrastBrikId=$( 3dinfo -label2index "${labelPrefix}_mean" $tTestFile 2> /dev/null )    

    nVoxels=$( $scriptsDir/get.minimum.voxel.count.r --nn $NN --alpha=$cPvalue --pthr=$pValue --side=$side --session=$GROUP_RESULTS  --prefix ${csimprefix}.${regLabel}.${gltLabel} )
    if [[ "x$nVoxels" == "x" ]] ; then
	echo "*** Couldn't get the correct number of voxels to go with pvalue=$pValue and corrected pvalue=$cPvalue"
	echo "*** You may need to pad these values with zeros to ensure you match the correct row and column in $cstempPrefix.NN${NN}_${side}.1D"
	exit
    fi
    ## thsi is useful if the t test si stored as such instead of a zscore
    ## df=$( extractTStatpars "$tTestFile" "${tLabelPrefix}_Tstat" )
    
    threshold=$( cdf -p2t fizt $pValue | sed 's/t = //' )
    echo "### labelPrefix = $labelPrefix"
    echo "### contrastBrikId = $contrastBrikId"
    echo "### statBrikId = $statBrikId"
    echo "### threshold = $threshold"
    echo "### rmm = $rmm"
    echo "### nVoxels = $nVoxels"
    ## echo "### df = $df"
    echo "### voxelwise pValue = $pValue"
    echo "### corrected  pValue = $cPvalue"

    infix=${regLabel}.${gltLabel}

    ## -1erode 50 -1dilate \
    3dmerge -session . -prefix clorder.$infix \
	    -2thresh -$threshold $threshold \
	    -1clust_order $rmm $nVoxels \
	    -dxyz=1 \
	    -1dindex $contrastBrikId -1tindex $statBrikId  -nozero \
	    $tTestFile
    
    if [[ -f clorder.$infix+tlrc.HEAD ]] ; then 
	3dclust -1Dformat -nosum -dxyz=1 $rmm $nVoxels clorder.$infix+tlrc.HEAD > clust.$infix.txt

	3dcalc -a clorder.${infix}+tlrc.HEAD -b ${tTestFile}\[$statBrikId\] -expr "step(a)*b" -prefix clust.$infix
	
	nClusters=$( 3dBrickStat -max clorder.$infix+tlrc.HEAD 2> /dev/null | tr -d ' ' )

	columnNumber=$( head -1 $gltDataTableFilename | tr '[[:space:]]' '\n' | grep -n InputFile | cut -f1 -d':' )
	if [[ -z $columnNumber ]] ; then
	    echo "Couldn't find a column named InputFile in $dataTableFilename"
	    echo "*** Cannot continue"
	    exit 1
	fi
	
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD $( tail -n +2 $gltDataTableFilename |     awk -v cn=$columnNumber '{ print $cn }' ) > roiStats.$infix.glt.txt

	columnNumber=$( head -1 $stimuliDataTableFilename | tr '[[:space:]]' '\n' | grep -n InputFile | cut -f1 -d':' )
	if [[ -z $columnNumber ]] ; then
	    echo "Couldn't find a column named InputFile in $dataTableFilename"
	    echo "*** Cannot continue"
	    exit 1
	fi
	
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD $( tail -n +2 $stimuliDataTableFilename |     awk -v cn=$columnNumber '{ print $cn }' ) > roiStats.$infix.stimuli.txt
	
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${tTestFile}\[$contrastBrikId\]      > roiStats.$infix.averageContrastValue.txt
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${tTestFile}\[$statBrikId\]          > roiStats.$infix.averageZscore.txt

	echo "$df" > text.$suffix.degreesOfFreedom.txt
	3drefit -cmap INT_CMAP clorder.$infix+tlrc.HEAD
	
    else
	nClusters=0
	echo "*** WARNING No clusters found!"
    fi
    echo "$regLabel,${gltLabel},$contrastBrikId,$statBrikId,$threshold,$rmm,$nVoxels,$pValue,$cPvalue,$nClusters,$tTestFile" >> $csvFile

done

cd $scriptsDir
##echo "*** Making cluster location tables using Maximum intensity"
##./cluster2Table.pl --space=mni --force -mi $GROUP_RESULTS

echo "*** Making cluster location tables using Center of Mass"
./cluster2Table.pl --space=mni --force $GROUP_RESULTS
