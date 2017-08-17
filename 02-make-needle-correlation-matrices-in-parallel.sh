#!/bin/bash

trap exit SIGHUP SIGINT SIGTERM

## set -x 
## currently optimized for server
## if wanted to run from mac... delete the echo and the quotes after execute to task file, and in the 1 == 1 line change so that not equivalent
## the window option allows to split the correlation matrices into windows and compute the correlations within the window and give 1 matrix per window
## note numeric values indicate TRs.  --window consecutive --width 10   OR --window overlap --width 10 --step 3

root=/data/jain/preApril

subjects=$( cd $root ; ls -1d CMIT* )
CREATE_NEEDLE_GRAPHS=1

[[ -d run ]] || mkdir run

taskFile="run/make-graphs-TaskFile.txt"
cat /dev/null > $taskFile
for subject in $subjects ; do

    ## 3dNetCorr partial correlation command line arg
    ## -part_corr
    ## 3dNetCorr fisher z command line arg    
    ## -fish_z
    ## \\\\-part_corr
    if [[ $CREATE_NEEDLE_GRAPHS -eq 1 ]] ; then 
	preprocessed_needle_file=../$subject/afniNeedlePreprocessed.NL/errts.${subject}.tproject+tlrc.HEAD 
	if [[ -f ${preprocessed_needle_file} ]] ; then
	    echo "./make.netcorr.commands.r					\
	    	--source ${preprocessed_needle_file}				\
	    	--destination ../${subject}/needleGraphs			\
	    	--prefix ${subject}errts.tproject.whole.ts			\
	    	--window none				                        \
		--extra \"\\\\-fish_z\"						\
	    	--rois ../standard/aal2_for_SPM12/aal2.nocerebellum.3mm.nii.gz	\
	    	--execute" >> $taskFile
	    #./make.netcorr.commands.r					\
	    # 	--source ${preprocessed_needle_file}				\
	    ## 	--destination ../${subject}/needleGraphs			\
	    # 	--prefix ${subject}errts.tproject.whole.ts			\
	    # 	--window none							\
	    #	--extra \"\\\\-fish_z\"						\
	    #   --rois ../standard/aal2_for_SPM12/aal2.nocerebellum.3mm.nii.gz	\
	    #  	--execute
	fi
    fi
done

# jobname
# $ -N makeGraphs

# queue
# $ -q all.q

# binary?
# $ -b y

# rerunnable?
# $ -r y

# merge stdout and stderr?
# $ -j y

# send no mail
# $ -m n

# execute from the current working directory
# $ -cwd

# use a shell to run the command
# $ -shell yes 
# set the shell
# $ -S /bin/bash

# preserve environment
# $ -V 

if [[ 1 == 1 ]] ; then
    nTasks=$( cat $taskFile | wc -l )

    sge_command="qsub -N makeGraphs -q all.q -j y -m n -V -wd $( pwd ) -o ../log/ -t 1-$nTasks" 
    #echo $sge_command
    echo "Queuing job... "
    ( exec $sge_command <<EOF
#!/bin/sh

#$ -S /bin/sh

command=\`sed -n -e "\${SGE_TASK_ID}p" $taskFile\`

exec /bin/sh -c "\$command"
EOF
)
    echo "Running qstat"
    qstat
    
fi
