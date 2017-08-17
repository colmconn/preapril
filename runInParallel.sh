#!/bin/bash

## set -x

studyName=preApril

programName=`basename $0`

GETOPT=$( which getopt )
ROOT=${MDD_ROOT:-/data/jain/$studyName}
DATA=$ROOT/data
PROCESSED_DATA=$DATA/processed
RAW_DATA=$DATA/raw
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

# if [[ $# -gt 0 ]] ; then
#     subjects="$*"
# else
#     ## subjects="$( cat ../data/config/control.subjectList.txt ../data/config/mdd.nat.txt )"

#     subjects=$( cd ../data/raw ; find ./ -maxdepth 1 -type d -a -name 'bc[0-9][0-9][0-9][abc]' -printf "%f\n" )

# fi
#echo $subjects
## subjectCount=$( echo $subjects | wc -w )
#exit

taskName=rr

taskFile=$SCRIPTS_DIR/run/${taskName}-TaskFile.$BASHPID
info_message_ln "List of tasks to be executed is stored in $taskFile"

## cat /dev/null > $taskFile

## ls -1 run/*baseline.analysis* > ${taskFile}
ls -1 run/*followup.analysis* > ${taskFile}


## jobname
#$ -N $taskName

## queue
#$ -q all.q

## binary? 
#$ -b y

## rerunnable?
#$ -r y

## merge stdout and stderr?
#$ -j y

## send no mail
#$ -m n

## execute from the current working directory
#$ -cwd

## use a shell to run the command
#$ -shell yes 

## set the shell
#$ -S /bin/bash

## preserve environment
#$ -V 

[[ ! -d $LOG_DIR ]] && mkdir $LOG_DIR

nTasks=$( cat $taskFile | wc -l )
sge_command="qsub -N $taskName -q all.q -j y -m n -V -wd $( pwd ) -o $LOG_DIR -t 1-$nTasks" 
echo $sge_command
( exec $sge_command <<EOF
#!/bin/sh

#$ -S /bin/sh

command=\`sed -n -e "\${SGE_TASK_ID}p" $taskFile\`

exec /bin/sh -c "\$command"
EOF
)

echo "Running qstat"
qstat
