#!/bin/bash
#$ -pwd

# script written by Lawrence Chen

VCFS=$(readlink -f "${1%/}")     # path_to_folder_with_vcfs
OUT_DIR=$(readlink -f "${2%/}")  # path_to_new_gens
OUT_FILE=$3                      # file_name_of_final_output_without_extension

### COMMAND DESCRIPTION IN FOR LOOP ###
# 1. remove header lines (with "#") using grep -v
# 2. remove unnecessary columns and reorder columns using awk
# 3. remove unnecessary sections of the genotyping data columns using sed
# 4. replace commas with spaces (found between posterior genotype probabilities) using sed
# 5. save output to file

for f in ${VCFS}/*.vcf; do
  filename=$(basename "$f")
  filestem="${filename%%.*}"
  grep -v "#" $f | awk -F'\t' '{$6=$7=$8=$9=""; t=$2; $2=$3; $3=t; print $0}' | sed -r 's/ *[[:digit:]]+\|[[:digit:]]+\:[[:digit:]]+\.?[[:digit:]]*,[[:digit:]]+\.?[[:digit:]]*:[[:digit:]]+\.?[[:digit:]]*:/ /g' | sed 's/\,/ /g' > ${OUT_DIR}/$filestem.gen
done

# concatenate gen files to a single gen
mkdir -p ${OUT_DIR}/COMPILED_GEN/
paste --delimiter=\\n --serial ${OUT_DIR}/*.gen > ${OUT_DIR}/COMPILED_GEN/${OUT_FILE}.gen

# create sample file
cat <(echo -e "ID_1 ID_2 missing\n0 0 0") <(grep "#CHROM" $(ls ${VCFS}/*.vcf | head -1) | cut -f10- --output-delimiter=$'\n' | awk '{print $0,$0,0}') > ${OUT_DIR}/COMPILED_GEN/${OUT_FILE}.sample
# Line below is meant for MAVAN, as Sanger binded Individual ID and Family ID from the sample ID in the VCF file
# sed -i 's/_[0-9]*_R[0-9]*C[0-9]*//g' ${OUT_DIR}/COMPILED_GEN/${OUT_FILE}.sample # specifically replace duplicated sentrix IDs per ID column with single sentrix IDs
