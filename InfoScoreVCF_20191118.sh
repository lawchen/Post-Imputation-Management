#!/bin/bash
#$ -pwd

# Developer: Lawrence M. Chen
# Version/date: 20191118
# Example: ./InfoScoreVCF_20191118.sh /share/projects/NEURON/STEP4-POST_IMPUTATION/NEURONimpute20Jun2017.vcfs/ /share/projects/NEURON/STEP4-POST_IMPUTATION/STEP1_INFO08/STEP1_INFO08_27Jun17/ NEURON_170627 0.8

USAGE="$(basename "$0") is a program to filter out genetic variants in the human autosomes that fail to meet the INFO score criterion from VCF files.
\n
Access to Portable Batch System (PBS) job scheduler and bcftools is required to run this program.
\n\n
Usage: $(basename "$0") [-h] <path_to_folder_with_vcfs> <path_to_new_vcfs> <root_name_of_output_dataset> <info_filter>
\n
where:
\n\t    -h                         \t\t\t\t\t show this help text
\n\n
The four mandatory arguments must be specified in the indicated order:
\n\t    path_to_folder_with_vcfs         \t\t location of the input vcf files
\n\t    path_to_new_vcfs               \t\t\t location of the output files
\n\t    root_name_of_output_dataset      \t\t part of the output file names to help identify the output files (e.g., cohort name and date)
\n\t    info_filter                  \t\t\t\t numeric value between 0 and 1 for the info score filter;
\n\t                               \t\t\t\t\t genetic variants with info score greater than the specified numeric value will be retained;
\n\t                               \t\t\t\t\t however, if value is 1, then only genetic variants with info score equal to 1 will be retained
\n
"

while getopts ":h" optname; do
  case "$optname" in
    "h")
      echo -e $USAGE
      exit 0;
      ;;
  esac
done

VCFS=$(readlink -f "${1%/}")     # path_to_folder_with_vcfs
OUT_DIR=$(readlink -f "${2%/}")  # path_to_new_vcfs
DAT=$3                           # root_name_of_output_dataset
INFO=$4                          # info_filter (e.g., 0.8)


mkdir -p ${OUT_DIR}/pbs_jobs/logdir

if (( $(bc <<<"$INFO == 1") )); then
  echo "INFO = 1 will be retained."

  for CHR in $(seq 1 22); do

    pbs=${OUT_DIR}/pbs_jobs/InfoScoreVCF_info1_${CHR}.pbs
    f=${VCFS}/${CHR}.vcf$(if [ -a ${VCFS}/${CHR}.vcf ]; then : ; else echo .gz ; fi)
    filename=$(basename "$f")
    filestem="${filename%%.*}"
    echo $filestem

    cat > $pbs << EOT # write pbs script information for each chromosome
#!/bin/bash
#PBS -q batch
#PBS -N VCF_info1_$CHR
#PBS -o ${OUT_DIR}/pbs_jobs/logdir
#PBS -e ${OUT_DIR}/pbs_jobs/logdir
#PBS -l walltime=02:00:00
#PBS -l nodes=1:ppn=4

####### JOB CODE #######

cd ${OUT_DIR}

echo "Job submission date: $(date +%c)"
echo "path_to_folder_with_vcfs = ${VCFS}/"
echo "path_to_new_vcfs = ${OUT_DIR}/"
echo "root_name_of_output_dataset = $DAT"
echo "filestem = $filestem"
echo "INFO = 1"

bcftools --version
bcftools view -Ou -i 'INFO=1' $f -o ${OUT_DIR}/${DAT}_info1_chr${filestem}.vcf -O v
EOT
    chmod 754 $pbs
    qsub $pbs
  done | tee -a ${OUT_DIR}/${DAT}_$(basename "${0%.*}")_$(date +%Y%m%d).log

else
  echo "INFO > $INFO will be retained."

  for CHR in $(seq 1 22); do

    pbs=${OUT_DIR}/pbs_jobs/InfoScoreVCF_info0${INFO#*.}_${CHR}.pbs
    f=${VCFS}/${CHR}.vcf$(if [ -a ${VCFS}/${CHR}.vcf ]; then : ; else echo .gz ; fi)
    filename=$(basename "$f")
    filestem="${filename%%.*}"
    echo $filestem

    cat > $pbs << EOT # write pbs script information for each chromosome
#!/bin/bash
#PBS -q batch
#PBS -N VCF_info0${INFO#*.}_$CHR
#PBS -o ${OUT_DIR}/pbs_jobs/logdir
#PBS -e ${OUT_DIR}/pbs_jobs/logdir
#PBS -l walltime=02:00:00
#PBS -l nodes=1:ppn=4

####### JOB CODE #######

cd ${OUT_DIR}

echo "Job submission date: $(date +%c)"
echo "path_to_folder_with_vcfs = ${VCFS}/"
echo "path_to_new_vcfs = ${OUT_DIR}/"
echo "root_name_of_output_dataset = $DAT"
echo "filestem = $filestem"
echo "INFO > ${INFO}"

bcftools --version
bcftools view -Ou -i 'INFO>${INFO}' $f -o ${OUT_DIR}/${DAT}_info0${INFO#*.}_chr${filestem}.vcf -O v
EOT
    chmod 754 $pbs
    qsub $pbs
  done | tee -a ${OUT_DIR}/${DAT}_$(basename "${0%.*}")_$(date +%Y%m%d).log

fi

echo "Wait for the PBS jobs to be complete before moving to the next step."
