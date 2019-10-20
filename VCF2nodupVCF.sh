#!/bin/bash
#$ -pwd

# Developer: Lawrence M. Chen
# Example: ./VCF2nodupVCF.sh /share/projects/genodata/cohortA/post_imputation/info_filter/

########### SCRIPT INFO ###########

VERSION=1.2
USAGE="
$(basename "$0") is a program to remove duplicated SNP IDs from VCF files.
\n\n
Usage: ./$(basename "$0") <path_to_folder_with_vcfs> [-o output_path] [-l log_file_name] [-v] [-h]
\n
where:
\n\t    -o  \t set output path -- if path does not exist it, it will be created automatically (default is local folder)
\n\t    -l  \t set log file name (default is $(basename "${0%.*}")_$(date +%y%m%d).log)
\n\t    -v  \t show the version of this script
\n\t    -h  \t show this help text
\n\n
<path_to_folder_with_vcfs> is a mandatory argument.
\n\n
Optional arguments can be provided before or after mandatory arguments but do not separate them.
\n
"


######## OPTIONS PROCESSING ########
if [ $# == 0 ] ; then
    echo -e $USAGE
    exit 1;
fi

OUTPATH=. # default output path if "-o" argument is not specified
LOG=$(basename ${0%.*})_$(date +%y%m%d).log # default log file name if "-l" argument is not specified

while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  while getopts ":o:l:vh" optname
    do
      case "$optname" in
        "v")
          echo "Version $VERSION"
          exit 0;
          ;;
        "h")
          echo -e $USAGE
          exit 0;
          ;;
        "o")
          echo "-o $OPTARG"
          if [[ $OPTARG =~ ^- ]]; then
            echo "ERROR: $OPTARG is not a valid argument value for -o. Please provide a different output path that does not begin with '-' and try again."
            exit 0;
          fi
          echo "The output DuplicateSNPs.txt and log file will be stored in ${OPTARG%/}/"
          if [ ! -d "$OPTARG" ]; then
            echo "${OPTARG%/}/ does not exist. The directory path will be created."
            mkdir -p $OPTARG
          fi
          OUTPATH=$(readlink -f "${OPTARG%/}")
          ;;
        "l")
          echo "-l $OPTARG"
          if [[ $OPTARG =~ ^- ]]; then
            echo "ERROR: $OPTARG is not a valid argument value for -l. Please provide a different log file name that does not begin with '-' and try again."
            exit 0;
          fi
          echo "Log file name is $OPTARG"
          LOG=$OPTARG
          ;;
        "?")
          echo "Unknown option -$OPTARG"
          echo "Use -h for help"
          exit 0;
          ;;
        ":")
          echo "No argument value for option -$OPTARG"
          echo "Use -h for help"
          exit 0;
          ;;
        *)
          echo "Unknown error while processing options"
          exit 0;
          ;;
      esac
    done
  shift $(($OPTIND - 1))

  while [ $# -gt 0 ] && ! [[ "$1" =~ ^- ]]; do
    VCFS=$(readlink -f "${1%/}")     # path_to_folder_with_vcfs
    shift;shift
  done
done

if [ "$1" == "--" ]; then
  shift
fi

mkdir -p ${OUTPATH}/pbs_jobs/logdir

LOG=${OUTPATH}/$LOG # update log path
JID=0 # job ID for PBS job name

######## RECORD LOG ########

echo "####### RUN $(basename "$0") #######" | tee $LOG
echo "script version: $VERSION" | tee -a $LOG
echo "date: $(date +%c)" | tee -a $LOG
echo "path_to_folder_with_vcfs = ${VCFS}/" | tee -a $LOG
echo "output_path = ${OUTPATH}/" | tee -a $LOG
echo "log_file = ${LOG}" | tee -a $LOG

for f in ${VCFS}/*.vcf; do
  
  let JID=(JID+1)
  pbs=$(readlink -f "${OUTPATH}")/pbs_jobs/VCF2nodupVCF_${JID}.pbs
  
  cat > $pbs << EOT # write VCF2nodupVCF.sh job information for each job
#!/bin/bash
#PBS -q batch
#PBS -N VCF_nodup_$JID
#PBS -o ${OUTPATH}/pbs_jobs/logdir
#PBS -e ${OUTPATH}/pbs_jobs/logdir
#PBS -l walltime=02:00:00
#PBS -l nodes=1:ppn=4

####### JOB CODE #######

cd $(readlink -f "${OUTPATH}")

######## GENERATE TEXT FILE OF ALL SNP DUPLICATES IN THE INPUT VCF FILES ##############
grep -v "^#" $f | ### remove all comment lines of the original files
awk '{print \$3}' | ### $3 is the column of SNP ID, in this case is column 3 
sort | uniq -cd | awk -v OFS='\t' '{print \$2,\$1}' > $(readlink -f "${OUTPATH}")/$(basename "${f%.*}")_dup.list

awk -F' ' 'FNR==NR{a[\$1];next} !(\$3 in a)' $(readlink -f "${OUTPATH}")/$(basename "${f%.*}")_dup.list $f > $(readlink -f "${OUTPATH}")/$(basename "${f%.*}")_nodup.vcf

EOT
  chmod 754 $pbs
  qsub $pbs
done
