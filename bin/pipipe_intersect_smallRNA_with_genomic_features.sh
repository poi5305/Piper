
# small RNA pipeline from pipipe: https://github.com/bowhan/pipipe.git
# pipipe: https://github.com/bowhan/pipipe.git
# An integrated pipeline for small RNA analysis 
# from small RNA Seq, RNASeq, CAGE/Degradome, ChIP-Seq and Genomic-Seq
# Wei Wang (wei.wang2@umassmed.edu)
# Bo W Han (bo.han@umassmed.edu, bowhan@me.com)
# the Zamore lab and the Weng lab
# University of Massachusetts Medical School

#####################
#function declartion#
#####################
function print_header {
	echo -ne "feature\t" > $1
	echo -ne "total_lib_all_mapper_reads\ttotal_feature_all_mapper_reads\tfeature_all_mapper_percentage\tfeature_sense_all_mapper_reads\tfeature_antisense_all_mapper_reads\tfeature_all_mapper_sense_fraction\t" >> $1
	echo -ne "total_lib_unique_mapper_reads\ttotal_feature_unique_mapper_reads\tfeature_unique_mapper_percentage\tfeature_sense_unique_mapper_reads\tfeature_antisense_unique_mapper_reads\tfeature_unique_mapper_sense_fraction\t" >> $1
	echo -ne "total_lib_unique_mapper_species\ttotal_feature_unique_mapper_species\tfeature_unique_mapper_percentage\tfeature_sense_unique_mapper_species\tfeature_antisense_unique_mapper_species\tfeature_unique_mapper_sense_fraction\n" >> $1
}
###############
#configuration#
###############
GENOME_ALLMAP_BED2=$1 # genome wide alignment of all mappers, in bed2 format
SUMMARY_PREFIX=$2 # prefix to store the summary file
smRNA_SUM=${SUMMARY_PREFIX}.smRNA.sum # summary for total small RNA
siRNA_SUM=${SUMMARY_PREFIX}.siRNA.sum # summary for siRNA
piRNA_SUM=${SUMMARY_PREFIX}.piRNA.sum # summary for piRNA
CPU=$3 # CPU to use
INTERSECT_OUTDIR=$4 # output directory to store files
SEED=${RANDOM}${RANDOM}${RANDOM}${RANDOM} # random name
[ ! -s $COMMON_FOLDER/genomic_features ] && echo2 "Missing or empty $COMMON_FOLDER/genomic_features file, cannot proceed with genomic struture intersecting..." "error"
. $COMMON_FOLDER/genomic_features # reading the information to intersect with, as well as some other annotation files
ALL_BED=`basename ${GENOME_ALLMAP_BED2%bed2}x_rpmk_rtRNA.bed2` # names for the file genernated here
# get rid of tRNA, rRNA, snoRNA...
[ -z $rtRNA ] && echo2 "undefined \$rtRNA, please add the annotation of rRNA+tRNA+snoRNA and edit the $COMMON_FOLDER/genomic_features file. Exiting current function" "error"
[ ! -s $rtRNA ] && echo2 "file $rtRNA not found. Exiting current function" "error"
bedtools_pipipe intersect -v -wa -a $GENOME_ALLMAP_BED2 -b $rtRNA | tee $INTERSECT_OUTDIR/${ALL_BED} | awk '{total[$7]=$4; if ($5==1) {unique_reads+=$4; ++unique_species}}END{for (seq in total) {all_reads+=total[seq]; ++all_species}; printf "%d\t%d\t%d\t%d\t", unique_reads, all_reads, unique_species, all_species}' > $INTERSECT_OUTDIR/.stats
[ "$?" != "0" ] && echo2 "Failed to remove rRNA, tRNA, snoRNA..." "error" 
print_header $smRNA_SUM
print_header $siRNA_SUM
print_header $piRNA_SUM

# doing intersecting and counting
para_file=$INTERSECT_OUTDIR/${SEED}.intersect.para
for t in ${TARGETS[@]}
do \
	echo "bash $DEBUG pipipe_smallRNA_intersect.sh $INTERSECT_OUTDIR/${ALL_BED}  ${t} ${!t} $INTERSECT_OUTDIR/.stats" >> $para_file
done
ParaFly -c $para_file -CPU $CPU -failed_cmds ${para_file}.failedCommands 1>&2 && \
rm -rf ${para_file}*

PDFs=""
for t in ${TARGETS[@]}
do \
	[ -s $INTERSECT_OUTDIR/${ALL_BED}.intersect_with_${t}.pdf ] && PDFs=${PDFs}" "$INTERSECT_OUTDIR/${ALL_BED}.intersect_with_${t}.pdf
	echo -ne "${t}\t" >> $smRNA_SUM
	cat $INTERSECT_OUTDIR/.stats.${t}.smRNA >> $smRNA_SUM
	echo -ne "${t}\t" >> $siRNA_SUM
	cat $INTERSECT_OUTDIR/.stats.${t}.siRNA >> $siRNA_SUM
	echo -ne "${t}\t" >> $piRNA_SUM
	cat $INTERSECT_OUTDIR/.stats.${t}.piRNA >> $piRNA_SUM
done

( gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$PDF_DIR/${PREFIX}.features.pdf ${PDFs} && rm -rf ${PDFs} ) || \
echo2 "Failed to merge pdf from features intersecting... check gs... Or use your favorarite pdf merge tool by editing line$LINENO in $0" "warning"


