#!/usr/bin/bash
# -pwd

# Developer: Lawrence M. Chen

USAGE="$(basename "$0") is a program that removes ambiguous SNPs (also known as palindromic SNPs) from a GEN file.
\n
Specify the the name of the GEN file on the command line. This program will output a new GEN file with '_noambi' at the end of the name.
\n\n
Usage: $(basename "$0") [-h] <GENFILE>
\n
where:
\n\t    -h     \t\t show this help text
\n\t    GENFILE  \t input file name, including .gen file extension
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

GENFILE=$1

awk '{ if (($4=="T" && $5=="A")||($4=="A" && $5=="T")||($4=="C" && $5=="G")||($4=="G" && $5=="C")) print $0, "ambig" ; else print $0 ;}' $GENFILE | grep -v ambig > ${GENFILE%.gen}_noambi.gen

echo ${GENFILE%.gen}_noambi.gen is created.
