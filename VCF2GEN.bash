#!/bin/bash
#$ -pwd

# Developer: Lawrence M. Chen
# Version/date: 20191020
# Caution note: This is this script is made specifically to extract the genotype posterior probabilities (GP) from the VCF files that came from Sanger Imputation Service. It is not made universally for all VCF formats.

USAGE="
$(basename "$0") is a program made specifically to extract the genotype posterior probabilities (GP) from the VCF files that came from Sanger Imputation Service. It is not made universally for all VCF formats.
\n\n
Usage: ./$(basename "$0") <path_to_folder_with_vcfs> <path_to_new_gens> <final_output_name_without_extension> [-h]
\n
where:
\n\t    -h                           \t\t\t\t\t show this help text
\n\n
The three mandatory arguments must be specified in the indicated order:
\n\t    path_to_folder_with_vcfs           \t\t location of the input vcf files
\n\t    path_to_new_gens                 \t\t\t location of the output files
\n\t    final_output_name_without_extension  \t output file name for the concatenated gen file and sample file
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
OUT_DIR=$(readlink -f "${2%/}")  # path_to_new_gens
OUT_FILE=$3                      # final_output_name_without_extension

### COMMAND DESCRIPTION IN FOR LOOP ###
# 1. remove header lines (with "#") using grep -v
# 2. remove unnecessary columns and reorder columns using awk
# 3. remove unnecessary sections of the genotyping data columns using sed
# 4. replace commas with spaces (found between posterior genotype probabilities) using sed
# 5. save output to file


mkdir -p ${OUT_DIR}/pbs_jobs/logdir

JID=0 # job ID for PRS job name

for f in $(ls -v ${VCFS}/*.vcf); do

  let JID=(JID+1)

  pbs=${OUT_DIR}/pbs_jobs/VCF2GEN_${JID}.pbs
  filename=$(basename "$f")
  filestem="${filename%%.*}"

  cat > $pbs << EOT # write pbs script information for each chromosome
#!/bin/bash
#PBS -q batch
#PBS -N VCF2GEN_$JID
#PBS -o ${OUT_DIR}/pbs_jobs/logdir
#PBS -e ${OUT_DIR}/pbs_jobs/logdir
#PBS -l walltime=02:00:00
#PBS -l nodes=1:ppn=4

####### JOB CODE #######

cd ${OUT_DIR}

echo "Job submission date: $(date +%c)"
echo "path_to_folder_with_vcfs = ${VCFS}/"
echo "path_to_new_gens = ${OUT_DIR}/"
echo "filestem = $filestem"

echo "Converting $filename to $filestem.gen..."
grep -v "#" $f | awk -F'\t' '{\$6=\$7=\$8=\$9=""; t=\$2; \$2=\$3; \$3=t; print \$0}' | sed -r 's/ *[[:digit:]]+\|[[:digit:]]+\:[[:digit:]]+\.?[[:digit:]]*,[[:digit:]]+\.?[[:digit:]]*:[[:digit:]]+\.?[[:digit:]]*:/ /g' | sed 's/\,/ /g' > ${OUT_DIR}/$filestem.gen
echo "Done."

EOT
  chmod 754 $pbs
  jobid=$(qsub $pbs)
  echo $jobid
  jobs=$(echo $jobs:$jobid | sed 's/^://')
done

# concatenate gen files to a single gen and create sample file
pbs=${OUT_DIR}/pbs_jobs/VCF2GEN_compile_gen.pbs
cat > $pbs << EOT # write pbs script information
#!/bin/bash
#PBS -q batch
#PBS -N VCF2GEN_cat_gen
#PBS -o ${OUT_DIR}/pbs_jobs/logdir
#PBS -e ${OUT_DIR}/pbs_jobs/logdir
#PBS -l walltime=06:00:00
#PBS -l nodes=1:ppn=12

####### JOB CODE #######

cd ${OUT_DIR}

# concatenate gen files to a single gen
mkdir -p ${OUT_DIR}/CONCATENATED_GEN/
echo "Concatenating all GEN files in ${OUT_DIR}/ to a single GEN file named ${OUT_FILE}.gen..."
paste --delimiter=\\\n --serial ${OUT_DIR}/*.gen > ${OUT_DIR}/CONCATENATED_GEN/${OUT_FILE}.gen

# create sample file
echo "Creating ${OUT_FILE}.sample..."
cat <(echo -e "ID_1 ID_2 missing\n0 0 0") <(grep "#CHROM" $(ls ${VCFS}/*.vcf | head -1) | cut -f10- --output-delimiter=\$'\n' | awk '{print \$0,\$0,0}') > ${OUT_DIR}/CONCATENATED_GEN/${OUT_FILE}.sample

# completion note
echo "Process completed. The final GEN and SAMPLE files are located in ${OUT_DIR}/CONCATENATED_GEN/."

EOT
chmod 754 $pbs
qsub -W depend=afterok:$jobs $pbs
echo "qsub -W depend=afterok:$jobs $pbs"
