#!/bin/bash

## set -x 

# if ctrl-c is typed exit immediatly
#pValue is 
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
# Need to make sure have gnu getopt installed from macports or homebrew to run on mac
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

# this gets the degrees of freedom for ttests in each voxel.  converts p-value to critical t value, which forms a threshold
# defining local variable specific to extractTStatpars
# this next function is not eventually used in this script / may be useful if remove the clustsim argument to 3dttest++ in the previous script
function extractTStatpars {
    local bucket="$1"
    local subbrikId="$2"

#3dAttribute gets attribute that stores the degrees of freedom, next two lines gobble up the useless text
    a=$(3dAttribute BRICK_STATSYM $bucket"[$subbrikId]" )
    b=${a##*(}
    c=${b%%)*}

    echo $( echo $c | tr "," " " )
}
# end of function not utilized


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
    echo "### GLT data table file is: $gltDataTableFilename"

    stimuliDataTableFilename=$GROUP_DATA/dataTable.${regLabel}.${gltLabel}.stimuli.ttest.all.txt
    echo "### Stimuli data table file is: $stimuliDataTableFilename"
    
    tTestFile=${regLabel}.${gltLabel}.ttest.all+tlrc
    echo "### T-test file is: $tTestFile"    
        
#label2index takes a descriptive text level, give me numeric id of BRIK that matches this label // a holdover from the past mostly
#sends this to error . information prints to standard output is good, redirect the verbose stuff we don't want to the trash
# 2> means send standard error to the great big bit heap in the sky. convention is 0 for standard input; 1 for standard output; 2 for error output

    statBrikId=$( 3dinfo -label2index "${labelPrefix}_Zscr" $tTestFile 2> /dev/null )
    contrastBrikId=$( 3dinfo -label2index "${labelPrefix}_mean" $tTestFile 2> /dev/null )    

#get.minimum.voxel.count: An R script to find the minimum cluster size
    nVoxels=$( $scriptsDir/get.minimum.voxel.count.r --nn $NN --alpha=$cPvalue --pthr=$pValue --side=$side -c ${csimprefix}.${regLabel}.${gltLabel}.CSim.NN${NN}_${side}sided.1D )
    if [[ "x$nVoxels" == "x" ]] ; then
	echo "*** Couldn't get the correct number of voxels to go with pvalue=$pValue and corrected pvalue=$cPvalue"
	echo "*** You may need to pad these values with zeros to ensure you match the correct row and column in $cstempPrefix.NN${NN}_${side}.1D"
	exit
    fi
    ## thsi is useful if the t test is stored as such instead of a zscore
    ## df=$( extractTStatpars "$tTestFile" "${tLabelPrefix}_Tstat" )
    
#cdf is cumulative density function; an afni program that translates a p-value into the critical statistical value at which thresholding should be done.
# if say want to threshold at p = .05, but have z scores, need to turn p value into a z value.  only voxels with a z score of X will be retained
#cdf produces "t = X", and we want only the number back.  s is for substitute, forward slash separates components of command, what comes after are bits you don't want
# two forward slashes together: the first closes the text to substitute, the second one is not followed by anything to substitute so nothing to substitute and so only gets the text that follows
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
#these are arguments to 3dmerge, sometimes when cluster have a one voxel isthmus... erode and dilate means look for small isthmuses connecting large blobs and erode them
#put this line back if see clusters that look bad....
    ## -1erode 50 -1dilate \

#3dmerge performs the thresholding and clustering
    3dmerge -session . -prefix clorder.$infix \
	    -2thresh -$threshold $threshold \
	    -1clust_order $rmm $nVoxels \
	    -dxyz=1 \
	    -1dindex $contrastBrikId -1tindex $statBrikId  -nozero \
	    $tTestFile
    
#3dclust gives the tables of centers of mass
    if [[ -f clorder.$infix+tlrc.HEAD ]] ; then 
	3dclust -1Dformat -nosum -dxyz=1 $rmm $nVoxels clorder.$infix+tlrc.HEAD > clust.$infix.txt

#next line gives new file that has non-zero voxels only in parts of brain that survive clustering. value in there is the z scores.  gives the clust. files
	3dcalc -a clorder.${infix}+tlrc.HEAD -b ${tTestFile}\[$statBrikId\] -expr "step(a)*b" -prefix clust.$infix
	
#gives the nClusters in the clorder file
	nClusters=$( 3dBrickStat -max clorder.$infix+tlrc.HEAD 2> /dev/null | tr -d ' ' )

#datatable file has a subject and an inputfile in its columns.  3dttest can provide covariates in between Subj and Inputfile
#this takes datatable, looks at first line and counts number of words.  accounting for fact that datatables could have more than 2 values (for example if have covariates)
#head is a program that in this case will return first line, could use another (for example the first 10 rows).  translates spaces into a new line.  then greps the line number on which it finds inputFile
#cut says take in some text, d is delimiter, -f1 says want first field without the colon

	columnNumber=$( head -1 $gltDataTableFilename | tr '[[:space:]]' '\n' | grep -n InputFile | cut -f1 -d':' )
	if [[ -z $columnNumber ]] ; then
	    echo "Couldn't find a column named InputFile in $dataTableFilename"
	    echo "*** Cannot continue"
	    exit 1
	fi
	
#this line says, take tail , print all but the top line, so start at the second line of datatable, use awk to print out the columnNumber and will give inputfiles for all the subjects.  
#3droistats computes average glt within each cluster within each subject.  will have as many columns as there are clusters.  so in this case the mean
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD $( tail -n +2 $gltDataTableFilename |     awk -v cn=$columnNumber '{ print $cn }' ) > roiStats.$infix.glt.txt

#this is repeating the above with the stimuli datatable, because stimuliDataTable.  this is for use in the next graphing function.  relativeVsStranger is rg rn  sg sn.  have 4 bars in graph for glt. 
#need average data values for each one

	columnNumber=$( head -1 $stimuliDataTableFilename | tr '[[:space:]]' '\n' | grep -n InputFile | cut -f1 -d':' )
	if [[ -z $columnNumber ]] ; then
	    echo "Couldn't find a column named InputFile in $dataTableFilename"
	    echo "*** Cannot continue"
	    exit 1
	fi
	
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD $( tail -n +2 $stimuliDataTableFilename |     awk -v cn=$columnNumber '{ print $cn }' ) > roiStats.$infix.stimuli.txt

#this is for the publication tables.  need volume and center of mask, average contrastValue, zScore.  all of this is put into the tables	
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${tTestFile}\[$contrastBrikId\]      > roiStats.$infix.averageContrastValue.txt
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${tTestFile}\[$statBrikId\]          > roiStats.$infix.averageZscore.txt

#this line unnecessary because no degrees of freedom with z scores
##	echo "$df" > text.$suffix.degreesOfFreedom.txt

#take clorder file and use integer colormap for loading it in so that each cluster gets a different color
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

#this command is a pearl that scripts takes the outputs from 3dclust, which has the centers of max and can read columns for center of mass and turn the three numbers into
#labels like left frontal gyrus, occipital gyrus, etc.  gives a tailarach label.

echo "*** Making cluster location tables using Center of Mass"
./cluster2Table.pl --space=mni --force $GROUP_RESULTS
