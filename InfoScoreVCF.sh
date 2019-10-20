#!/bin/bash
#$ -pwd

#version/date: 20170609
#example: ./InfoScoreVCF.sh /share/projects/genodata/cohortA/sanger_imputation/cohortA.vcfs/ /share/projects/genodata/cohortA/post_imputation/info_filter/ cohortA_20170627 0.8
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
\n\t    info_filter                  \t\t\t\t numeric value between 0 and 1 for the info score filter
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

for CHR in $(seq 1 22); do

  f=${VCFS}/${CHR}.vcf$(if [ -a ${VCFS}/${CHR}.vcf ]; then : ; else echo .gz ; fi)
  filename=$(basename "$f")
  filestem="${filename%%.*}"
  echo $filestem

  cat > ${OUT_DIR}/pbs_jobs/InfoScoreVCF_${CHR}.bash << EOT # log InfoScoreVCF.sh job information for each chromosome
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
  chmod 754 ${OUT_DIR}/pbs_jobs/InfoScoreVCF_${CHR}.bash
  qsub ${OUT_DIR}/pbs_jobs/InfoScoreVCF_${CHR}.bash
done | tee -a ${OUT_DIR}/${DAT}_$(basename "${0%.*}")_$(date +%y%m%d).log

bcftools --version | tee -a ${OUT_DIR}/${DAT}_$(basename "${0%.*}")_$(date +%y%m%d).log
smallestVCF=$(ls -rS ${VCFS}/*.vcf$(if [ -a ${VCFS}/1.vcf.gz ]; then echo .gz ; fi) | head -1 )
bcftools convert --tag GP --gensample ${OUT_DIR}/$DAT $smallestVCF | tee -a ${OUT_DIR}/${DAT}_$(basename "${0%.*}")_$(date +%y%m%d).log

echo "${DAT}.samples and ${DAT}.gen.gz have been generated." | tee -a ${OUT_DIR}/${DAT}_$(basename "${0%.*}")_$(date +%y%m%d).log
echo "${DAT}.samples will be used as the SAMPLE file for this project's imputed genotype data in GEN/SAMPLE format." | tee -a ${OUT_DIR}/${DAT}_$(basename "${0%.*}")_$(date +%y%m%d).log
echo "${DAT}.gen.gz will not be kept because the we found conversion errors using bcftools 1.3.1 to make the GEN file." | tee -a ${OUT_DIR}/${DAT}_$(basename "${0%.*}")_$(date +%y%m%d).log
rm ${OUT_DIR}/${DAT}.gen.gz
