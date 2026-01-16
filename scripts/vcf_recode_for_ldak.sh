#!/bin/bash
# This script is used to recode the vcf file for ldak. It will replace the ref and alt with X and Y if the length of ref or alt is greater than 1.
awk 'BEGIN{OFS="\t"} /^#/ {print; next} { ref=$4; alt=$5; if(length(ref)>1 || length(alt)>1){ $4="X"; $5="Y"} print}' $1
