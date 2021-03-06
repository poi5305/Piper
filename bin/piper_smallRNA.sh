
# piper, a pipeline collection for PIWI-interacting RNA (piRNA) and transposon analysis
# Copyright (C) 2014  Bo Han, Wei Wang, Phillip Zamore, Zhiping Weng
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


##########
# Config #
##########
export SMALLRNA_VERSION=1.0.0

#########
# USAGE #
#########
usage () {
cat << EOF

small RNA Seq pipeline single library mode v$SMALLRNA_VERSION from the $BOLD$PACKAGE_NAME$RESET
$SMALLRNA_INTRO${RESET}
Please email $CONTACT_EMAILS for any questions or bugs. 
Thank you for using it. 

${UNDERLINE}usage${RESET}:
	piper small \ 
		-i input.fq[.gz] \ 
		-g dm3 \ 
		-N uniqueXmiRNA [unique] \ 
		-o output_directory [current working directory] \ 
		-c cpu [8] 
	
OPTIONS:
	-h      Show this message
	-v      Print out the version
${REQUIRED}[ required ]
	-i      Input file in fastq or gzipped fastq format; Needs adaptor and barcode removed
		 Since this small RNA pipeline does not consider quality, we strongly recommend a quality filtering step.
	-g      Genome assembly name, like mm9 or dm3
		 Check "$PIPELINE_DIRECTORY/common/genome_supported.txt" for genome assemblies currently installed; 
		 Use "install" to install new genome
${OPTIONAL}[ optional ]
	-N      Normalization method, choose from " input | rRNA | unique | uniqueXmiRNA | all | allXmiRNA | miRNA "
	 	 unique:	use non-rRNA genomic unique mappers <default>.
	 	 input:	use the number of reads input to the pipeline, this will include genome unmappers. But might be useful when you have additional sequence in the genome, like a transgene.
	 	 rRNA:	use the number of reads mapped to rRNA.
	 	 uniqueXmiRNA:	use non-rRNA genomic unique mappers excluding microRNAs <for oxidized library for piRNA mutant>.
	 	 all:	use non-rRNA genomic all mappers including microRNAs.
	 	 allXmiRNA:	use non-rRNA genomic all mappers excluding microRNAs. 
	 	 miRNA:	use microRNAs. normalized to: reads per millions of miRNA <for unoxidized library for piRNA mutant>.
		 *Different normalization methods, including "siRNA", are available in the dual library mode.
		 *You are able to run the same library multiple times with different normalization method. They will not collapse.
	-c      Number of CPUs to use, default: 8
	-o      Output directory, default: current directory $PWD
EOF
echo -e "${COLOR_END}"
}

#############################
# ARGS reading and checking #
#############################
while getopts "hi:c:o:g:vN:" OPTION; do
	case $OPTION in
		h)	usage && exit 0 ;;
		i)	INPUT_FASTQ=`readlink -f $OPTARG` ;;
		o)	OUTDIR=`readlink -f $OPTARG` ;;
		c)	CPU=$OPTARG ;;
		v)	echo2 "SMALLRNA_VERSION: v$SMALLRNA_VERSION" && exit 0 ;;
		g)	export GENOME=`echo ${OPTARG} | tr '[A-Z]' '[a-z]'` ;;
		N)	export NORMMETHOD=`echo ${OPTARG} | tr '[A-Z]' '[a-z]'` ;;
		*)	usage && exit 1 ;;
	esac
done
# if INPUT_FASTQ or GENOME is undefined, print out usage and exit
[[ -z "$INPUT_FASTQ" ]] && usage && echo2 "Missing option -i for input fastq file " "error" 
[[ -z "$GENOME" ]]  && usage && echo2 "Missing option -g for specifying which genome assembly to use" "error" 
# check whether the this genome is supported or not
check_genome $GENOME
[ ! -f $INPUT_FASTQ ] && echo2 "Cannot find input file $INPUT_FASTQ" "error"
FQ_NAME=`basename $INPUT_FASTQ` && export PREFIX=${FQ_NAME%.f[qa]*}
[[ -z $NORMMETHOD ]] && export NORMMETHOD="unique";
[ ! -z "${CPU##*[!0-9]*}" ] || CPU=8
[ ! -z "$OUTDIR" ] || OUTDIR=$PWD # if -o is not specified, use current directory
[ "$OUTDIR" != `readlink -f $PWD` ] && (mkdir -p "${OUTDIR}" || echo2 "Cannot create directory ${OUTDIR}" "warning")
cd ${OUTDIR} || (echo2 "Cannot access directory ${OUTDIR}... Exiting..." "error")
touch .writting_permission && rm -rf .writting_permission || (echo2 "Cannot write in directory ${OUTDIR}... Exiting..." "error")

#################################
# creating output files/folders #
#################################
TABLE=${PREFIX}.basic_stats
export PDF_DIR=$OUTDIR/pdfs && mkdir -p $PDF_DIR
READS_DIR=input_read_files && mkdir -p $READS_DIR 
rRNA_DIR=rRNA_mapping && mkdir -p $rRNA_DIR
MIRNA_DIR=hairpins_mapping && mkdir -p $MIRNA_DIR
CUSTOM_MAPPING_DIR=custom_mapping && mkdir -p $CUSTOM_MAPPING_DIR
GENOMIC_MAPPING_DIR=genome_mapping && mkdir -p $GENOMIC_MAPPING_DIR
INTERSECT_DIR=intersect_genomic_features && mkdir -p $INTERSECT_DIR
SUMMARY_DIR=summaries && mkdir -p $SUMMARY_DIR
BW_OUTDIR=bigWig_normalized_by_$NORMMETHOD && mkdir -p $BW_OUTDIR
TRN_OUTDIR=transposon_piRNAcluster_mapping_normalized_by_$NORMMETHOD && mkdir -p $TRN_OUTDIR
EXPRESS_DIR=eXpress_quantification_no_normalization && mkdir -p $EXPRESS_DIR

########################
# running binary check #
########################
checkBin "sort" 
checkBin "md5sum"
checkBin "awk"
checkBin "grep"
checkBin "python" 
checkBin "samtools"
checkBin "gs"
checkBin "Rscript"
checkBin "bowtie"
checkBin "ParaFly"
checkBin "bedtools_piper"
checkBin "bedGraphToBigWig"
checkBin "piper_fastq_to_insert"
checkBin "piper_insertBed_to_bed2"

#############
# Variables #
#############
# step counter
STEP=1
# job uid
JOBUID=`echo ${INPUT_FASTQ} | md5sum | cut -d" " -f1`
# directories storing the common files for this organism
export COMMON_FOLDER=$PIPELINE_DIRECTORY/common/$GENOME
# assign different values to the generalized variables (same name for different GENOMEs) according to which GENOME fed
. $COMMON_FOLDER/variables
# fasta file for the genome
export GENOME_FA=$COMMON_FOLDER/${GENOME}.fa && [ ! -s $GENOME_FA ] && echo2 "Cannot detect fasta file for the genome" "error"
# chrom information of this GENOME
CHROM=$COMMON_FOLDER/${GENOME}.ChromInfo.txt && [ ! -s $CHROM ] && echo2 "Cannot detect chrom size file file for the genome" "error"
# bowtie index directory
export BOWTIE_INDEXES=$COMMON_FOLDER/BowtieIndex

##############################
# beginning running pipeline #
##############################
echo2 "---------------------------------------------------------------------------------"
echo2 "Beginning running [${PACKAGE_NAME}] small RNA pipeline single library mode version $SMALLRNA_VERSION" 

########################################
## Pre Processing before any Mapping ###
########################################
# convering fastq to insert; quality information will be lost
echo2 "Converting fastq format into insert format" 
INSERT=$READS_DIR/${PREFIX}.insert # insert file, a format with two fields delimited by a tab. Sequence and number of times it was read, used to save time/space; quality information is lost
[ ! -f .${JOBUID}.status.${STEP}.fq2insert ] && \
	piper_fastq_to_insert ${INPUT_FASTQ} ${INSERT} && \
	touch .${JOBUID}.status.${STEP}.fq2insert
[ ! -f .${JOBUID}.status.${STEP}.fq2insert ] && echo2 "fq2insert failed" "error"
STEP=$((STEP+1))

#####################################
# Pre Processing before any Mapping #
#####################################
# getting rid of sequences mapping to rRNA, we use -k 1 option for speed purpose
echo2 "Mapping to rRNA, with $rRNA_MM mismatch(es) allowed"
rRNA_BED_LOG=$rRNA_DIR/${PREFIX}.rRNA.log
x_rRNA_INSERT=$READS_DIR/${PREFIX}.x_rRNA.insert
[ ! -f .${JOBUID}.status.${STEP}.rRNA_mapping ] && \
	totalReads=`awk '{a+=$2}END{printf "%d", a}' ${INSERT}` && echo $totalReads > .${JOBUID}.totalReads && \
	bowtie -r -S -v $rRNA_MM -k 1 -p $CPU \
		--un $x_rRNA_INSERT \
		rRNA \
		${INSERT} \
		1> /dev/null \
		2> $rRNA_BED_LOG && \
	nonrRNAReads=`awk '{a+=$2}END{printf "%d", a}' ${x_rRNA_INSERT}` && echo $nonrRNAReads > .${JOBUID}.nonrRNAReads && \
	rRNAReads=$((totalReads-nonrRNAReads)) && \
	echo $rRNAReads > .${JOBUID}.rRNAReads && \
    touch .${JOBUID}.status.${STEP}.rRNA_mapping
[ ! -f .${JOBUID}.status.${STEP}.rRNA_mapping ] && echo2 "mapping to rRNA failed" "error"
STEP=$((STEP+1))
# reading values from file, this is for resuming the job, which won't run the previous step
totalReads=`cat .${JOBUID}.totalReads`
rRNAReads=`cat .${JOBUID}.rRNAReads`
nonrRNAReads=`cat .${JOBUID}.nonrRNAReads`
 
#########################
# miRNA hairpin Mapping #
#########################
echo2 "Mapping to microRNA Hairpin, with $hairpin_MM mismatch(es) allowed; only keep unique mappers"
x_rRNA_HAIRPIN_INSERT=$READS_DIR/${PREFIX}.x_rRNA.hairpin.insert # insert file storing reads that nonmappable to rRNA and mappable to hairpin
x_rRNA_x_hairpin_INSERT=$READS_DIR/${PREFIX}.x_rRNA.x_hairpin.insert # reads that nonmappable to rRNA or hairpin
x_rRNA_HAIRPIN_BED2=$MIRNA_DIR/${PREFIX}.x_rRNA.hairpin.v${hairpin_MM}m1.bed2 # bed2 format with hairpin mapper, with the hairpin as reference
x_rRNA_HAIRPIN_BED2_LENDIS=$MIRNA_DIR/${PREFIX}.x_rRNA.hairpin.v${hairpin_MM}m1.lendis # length distribution for hairpin mapper
x_rRNA_HAIRPIN_GENOME_BED2=$GENOMIC_MAPPING_DIR/${PREFIX}.x_rRNA.hairpin.${GENOME}v${genome_MM}a.bed2 # bed2 format with hairpin mapper, with genome as reference
x_rRNA_HAIRPIN_GENOME_LOG=$GENOMIC_MAPPING_DIR/${PREFIX}.x_rRNA.hairpin.${GENOME}v${genome_MM}a.log # log file for hairpin mapping
[ ! -f .${JOBUID}.status.${STEP}.hairpin_mapping ] && \
	bowtie -r -v $hairpin_MM -m 1 --best --strata -p $CPU -S \
		--al $x_rRNA_HAIRPIN_INSERT \
		--un $x_rRNA_x_hairpin_INSERT \
		hairpin \
		$x_rRNA_INSERT \
		2> /dev/null  | \
	samtools view -bSF 0x4 - 2>/dev/null | \
	bedtools_piper bamtobed -i - | awk '$6=="+"' > ${PREFIX}.x_rRNA.hairpin.v${hairpin_MM}m1.bed && \
	piper_insertBed_to_bed2 $x_rRNA_INSERT ${PREFIX}.x_rRNA.hairpin.v${hairpin_MM}m1.bed > $x_rRNA_HAIRPIN_BED2 && \
	rm -rf ${PREFIX}.x_rRNA.hairpin.v${hairpin_MM}m1.bed && \
	bed2lendis $x_rRNA_HAIRPIN_BED2 > $x_rRNA_HAIRPIN_BED2_LENDIS && \
	bowtie -r -v $genome_MM -a --best --strata -p $CPU \
		-S \
		genome \
		$x_rRNA_HAIRPIN_INSERT \
		2> $x_rRNA_HAIRPIN_GENOME_LOG | \
	samtools view -uS -F0x4 - 2>/dev/null | \
	bedtools_piper bamtobed -i - > ${PREFIX}.x_rRNA.hairpin.${GENOME}v${genome_MM}a.bed && \
	piper_insertBed_to_bed2 $x_rRNA_HAIRPIN_INSERT ${PREFIX}.x_rRNA.hairpin.${GENOME}v${genome_MM}a.bed > $x_rRNA_HAIRPIN_GENOME_BED2 && \
	rm -rf ${PREFIX}.x_rRNA.hairpin.${GENOME}v${genome_MM}a.bed && \
	hairpinReads=`bedwc $x_rRNA_HAIRPIN_BED2` && echo $hairpinReads > .${JOBUID}.hairpinReads
	touch .${JOBUID}.status.${STEP}.hairpin_mapping
STEP=$((STEP+1))
hairpinReads=`cat .${JOBUID}.hairpinReads`

# run miRNA heterogeneity analysis
echo2 "Calculate microRNA heterogeneity"
[ ! -f .${JOBUID}.status.${STEP}.miRNA_pipeline ] && \
	piper_calculate_miRNA_heterogeneity $COMMON_FOLDER/mature2hairpin.uniq.bed  ${x_rRNA_HAIRPIN_BED2} 1> ${x_rRNA_HAIRPIN_BED2%.bed*}.sum 2> ${x_rRNA_HAIRPIN_BED2%.bed*}.hetergeneity.log
	touch .${JOBUID}.status.${STEP}.miRNA_pipeline
STEP=$((STEP+1))

##################
# custom mapping #
##################
# Begin of custumer variables
# PreMappingList stores an array of variable names. those variables names store the address of bowtie indexes. 
# this pipeline will map input reads (fater rRNA and miRNA mapping) to each one of those bowite indexes sequentially
# mapped reads will be excluded from mapping to next index and the GENOME mapping
# candidates: virus/primer contamination
declare -a PreMappingList=() 
declare -a PreMappingMM=()	
#----------example----------
#virus=$COMMON_FOLDER/dmel_virus
#PreMappingList=("${PreMappingList[@]}" "virus")
#PreMappingMM=("${PreMappingMM[@]}" "2")
#----------end of example----------
# count how many indexed need to map
COUNTER=0
INPUT=$x_rRNA_x_hairpin_INSERT
# if there are any indexes need to be run
[[ ${#PreMappingList[@]} > 0 ]] && \
for COUNTER in `seq 0 $((${#PreMappingList[@]}-1))`; do \
	TARGET=${PreMappingList[$COUNTER]} && \
	OUTDIR1=$CUSTOM_MAPPING_DIR/${TARGET} && mkdir -p $OUTDIR1 && \
	PREFIX1=`basename $INPUT` && PREFIX1=${OUTDIR1}/${PREFIX1%.insert} && \
	MM=${PreMappingMM[$COUNTER]} && \
	echo2 "Mapping to ${TARGET}, with $MM mismatch(es) allowed" && \
	[ ! -f .${JOBUID}.status.${STEP}.${TARGET}_mapping ] && \
		bowtie -r -v $MM -a --best --strata -p $CPU -S \
			${BOWTIE_PHRED_OPTION} \
			--un ${INPUT%.insert}.x_${TARGET}.insert \
			${!TARGET} \
			$INPUT \
			2> ${PREFIX1}.log | \
		samtools view -bSF 0x4 - 2>/dev/null | bedtools_piper bamtobed -i - > ${PREFIX1}.${TARGET}.v${MM}a.bed && \
		piper_insertBed_to_bed2 $INPUT ${PREFIX1}.${TARGET}.v${MM}a.bed > ${PREFIX1}.${TARGET}.v${MM}a.bed2 && \
		rm -rf ${PREFIX1}.${TARGET}.v${MM}a.bed && \
		touch .${JOBUID}.status.${STEP}.${TARGET}_mapping
	STEP=$((STEP+1))
	INPUT=${INPUT%.insert}.x_${TARGET}.insert
done

##################
# GENOME Mapping #
##################
# take the OUTPUT of last step as INPUT
INSERT=`basename ${INPUT}`
# bed2 format storing all mappers for genomic mapping
GENOME_ALLMAP_BED2=$GENOMIC_MAPPING_DIR/${INSERT%.insert}.${GENOME}v${genome_MM}.all.bed2 # all mapper in bed2 format
GENOME_ALLMAP_LOG=$GENOMIC_MAPPING_DIR/${INSERT%.insert}.${GENOME}v${genome_MM}.all.log # log file
# bed2 format storing unique mappers for genomic mapping
GENOME_UNIQUEMAP_BED2=$GENOMIC_MAPPING_DIR/${INSERT%.insert}.${GENOME}v${genome_MM}.unique.bed2
# bed2 format storing unique mappers for genomic mapping and miRNA hairpin mapper
GENOME_UNIQUEMAP_HAIRPIN_BED2=$GENOMIC_MAPPING_DIR/${INSERT%.insert}.${GENOME}v${genome_MM}.unique.+hairpin.bed2
# mapping insert file to genome
echo2 "Mapping to genome, with ${genome_MM} mismatch(es) allowed"
[ ! -f .${JOBUID}.status.${STEP}.genome_mapping ] && \
	bowtie -r -v $genome_MM -a --best --strata -p $CPU \
		--al  ${INPUT%.insert}.${GENOME}v${genome_MM}a.al.insert \
		--un  ${INPUT%.insert}.${GENOME}v${genome_MM}a.un.insert \
		-S \
		genome \
		${INPUT} \
		2> $GENOME_ALLMAP_LOG | \
	samtools view -uS -F0x4 - 2>/dev/null | \
	bedtools_piper bamtobed -i - > ${INSERT%.insert}.${GENOME}v${genome_MM}a.insert.bed && \
	piper_insertBed_to_bed2 $INPUT ${INSERT%.insert}.${GENOME}v${genome_MM}a.insert.bed > ${GENOME_ALLMAP_BED2} && \
	rm -rf ${INSERT%.insert}.${GENOME}v${genome_MM}a.insert.bed && \
	touch .${JOBUID}.status.${STEP}.genome_mapping
[ ! -f .${JOBUID}.status.${STEP}.genome_mapping ] && echo2 "Genome mapping failed" "error"
STEP=$((STEP+1))

# separating unique and multiple mappers
echo2 "Separating unique and multiple mappers"
[ ! -f .${JOBUID}.status.${STEP}.separate_unique_and_multiple ] && \
	awk 'BEGIN{OFS="\t"}{if ($5==1) print $0}' ${GENOME_ALLMAP_BED2} \
	1> ${GENOME_UNIQUEMAP_BED2}	&& \
	totalMapCount=`bedwc ${GENOME_ALLMAP_BED2}` && echo $totalMapCount > .${JOBUID}.totalMapCount && \
	uniqueMapCount=`bedwc ${GENOME_UNIQUEMAP_BED2}` && echo $uniqueMapCount > .${JOBUID}.uniqueMapCount && \
	multipMapCount=$((totalMapCount-uniqueMapCount)) && echo $multipMapCount > .${JOBUID}.multipMapCount && \
	cat $x_rRNA_HAIRPIN_GENOME_BED2 ${GENOME_UNIQUEMAP_BED2} > $GENOME_UNIQUEMAP_HAIRPIN_BED2 && \
	touch .${JOBUID}.status.${STEP}.separate_unique_and_multiple
STEP=$((STEP+1))
totalMapCount=`cat .${JOBUID}.totalMapCount`
uniqueMapCount=`cat .${JOBUID}.uniqueMapCount`
multipMapCount=`cat .${JOBUID}.multipMapCount`

#####################
# Length Separation #
#####################
echo2 "Separating siRNA, piRNA based on length"
[ -z "$siRNA_bot" -o -z "$siRNA_top" ]  && echo2 "length for siRNA is not defined! please check the \"variable\" file under common\$GENOME" "error"
[ -z "$piRNA_bot" -o -z "$piRNA_top" ]  && echo2 "lengt for piRNA is not defined! please check the \"variable\" file under common\$GENOME" "error"
[ ! -f .${JOBUID}.status.${STEP}.sep_length ] && \
	para_file=${RANDOM}${RANDOM}.para && \
	echo "awk '\$3-\$2>=$siRNA_bot && \$3-\$2<$siRNA_top' ${GENOME_ALLMAP_BED2} > ${GENOME_ALLMAP_BED2%bed2}siRNA.bed2" > $para_file && \
	echo "awk '\$3-\$2>=$piRNA_bot && \$3-\$2<$piRNA_top' ${GENOME_ALLMAP_BED2} > ${GENOME_ALLMAP_BED2%bed2}piRNA.bed2" >> $para_file && \
	ParaFly -c $para_file -CPU $CPU -failed_cmds ${para_file}.failedCommands 1>&2 && \
	rm -rf ${para_file}* && \
	touch  .${JOBUID}.status.${STEP}.sep_length
[ ! -f .${JOBUID}.status.${STEP}.sep_length ] && "separating siRNA, piRNA failed"
STEP=$((STEP+1))

# plotting length distribution
echo2 "Plotting length distribution"
[ ! -f .${JOBUID}.status.${STEP}.plotting_length_dis ] && \
	awk '{a[$7]=$4}END{m=0; for (b in a){c[length(b)]+=a[b]; if (length(b)>m) m=length(b)} for (d=1;d<=m;++d) {print d"\t"(c[d]?c[d]:0)}}' ${GENOME_ALLMAP_BED2}  | sort -k1,1n > ${GENOME_ALLMAP_BED2}.lendis && \
	awk '{a[$7]=$4}END{m=0; for (b in a){c[length(b)]+=a[b]; if (length(b)>m) m=length(b)} for (d=1;d<=m;++d) {print d"\t"(c[d]?c[d]:0)}}' ${GENOME_UNIQUEMAP_BED2}  | sort -k1,1n > ${GENOME_UNIQUEMAP_BED2}.lendis && \
	Rscript --slave ${PIPELINE_DIRECTORY}/bin/piper_draw_lendis.R ${GENOME_ALLMAP_BED2}.lendis $PDF_DIR/`basename ${GENOME_ALLMAP_BED2}`.x_hairpin 1>&2 && \
	Rscript --slave ${PIPELINE_DIRECTORY}/bin/piper_draw_lendis.R ${GENOME_UNIQUEMAP_BED2}.lendis $PDF_DIR/`basename ${GENOME_UNIQUEMAP_BED2}`.x_hairpin 1>&2 && \
	awk '{ct[$1]+=$2}END{for (l in ct) {print l"\t"ct[l]}}' ${GENOME_ALLMAP_BED2}.lendis $x_rRNA_HAIRPIN_BED2_LENDIS | sort -k1,1n > ${GENOME_ALLMAP_BED2}.+hairpin.lendis && \
	awk '{ct[$1]+=$2}END{for (l in ct) {print l"\t"ct[l]}}' ${GENOME_UNIQUEMAP_BED2}.lendis $x_rRNA_HAIRPIN_BED2_LENDIS | sort -k1,1n > ${GENOME_UNIQUEMAP_BED2}.+hairpin.lendis && \
	Rscript --slave ${PIPELINE_DIRECTORY}/bin/piper_draw_lendis.R ${GENOME_ALLMAP_BED2}.+hairpin.lendis $PDF_DIR/`basename ${GENOME_ALLMAP_BED2}`.+hairpin 1>&2 && \
	Rscript --slave ${PIPELINE_DIRECTORY}/bin/piper_draw_lendis.R ${GENOME_UNIQUEMAP_BED2}.+hairpin.lendis $PDF_DIR/`basename ${GENOME_UNIQUEMAP_BED2}`.+hairpin 1>&2 && \
	touch .${JOBUID}.status.${STEP}.plotting_length_dis
STEP=$((STEP+1))

##################
# Print to table #
##################
# change dual library mode normalization method if change here
echo -e "total reads as input of the pipeline\t${totalReads}" > $TABLE && \
echo -e "rRNA reads with ${rRNA_MM} mismatches\t${rRNAReads}" >> $TABLE && \
echo -e "miRNA hairpin reads\t${hairpinReads}" >> $TABLE && \
echo -e "genome mapping reads (-rRNA; +miRNA_hairpin)\t$((totalMapCount+hairpinReads))" >> $TABLE && \
echo -e "genome mapping reads (-rRNA; -miRNA_hairpin)\t${totalMapCount}" >> $TABLE && \
echo -e "genome unique mapping reads (-rRNA; +miRNA_hairpin)\t$((uniqueMapCount+hairpinReads))" >> $TABLE && \
echo -e "genome unique mapping reads (-rRNA; -miRNA_hairpin)\t${uniqueMapCount}" >> $TABLE && \
echo -e "genome multiple mapping reads (-rRNA; -miRNA_hairpin)\t${multipMapCount}" >> $TABLE && \

# normalization method
# input | rRNA | unique | uniqueXmiRNA | all | allXmiRNA | miRNA
case "$NORMMETHOD" in
input)
	NormScale=`head -1 $TABLE | tail -1 | cut -f2 | awk '{print 1000000/$0}'`
;;
rrna)
	NormScale=`head -2 $TABLE | tail -1 | cut -f2 | awk '{print 1000000/$0}'`
;;
mirna)
	NormScale=`head -3 $TABLE | tail -1 | cut -f2 | awk '{print 1000000/$0}'`
;;
all)
	NormScale=`head -4 $TABLE | tail -1 | cut -f2 | awk '{print 1000000/$0}'`
;;
allxmirna)
	NormScale=`head -5 $TABLE | tail -1 | cut -f2 | awk '{print 1000000/$0}'`
;;
unique)
	NormScale=`head -6 $TABLE | tail -1 | cut -f2 | awk '{print 1000000/$0}'`
;;
uniquexmirna)
	NormScale=`head -7 $TABLE | tail -1 | cut -f2 | awk '{print 1000000/$0}'`
;;
*)
	echo2 "unrecognized normalization option: $NORMMETHOD; using the default method" "warning"
	NormScale=`head -6 $TABLE | tail -1 | cut -f2 | awk '{print 1000000/$0}'`
;;
esac
echo $NormScale > .depth

####################################
# Intersecting with GENOME Feature #
####################################
echo2 "Intersecting with genomic features with bedtools"
[ ! -f .${JOBUID}.status.${STEP}.intersect_with_genomic_features ] && \
bash $DEBUG piper_intersect_smallRNA_with_genomic_features.sh \
	${GENOME_ALLMAP_BED2} \
	$SUMMARY_DIR/`basename ${GENOME_ALLMAP_BED2%.bed2}` \
	$CPU \
	$INTERSECT_DIR \
	1>&2 && \
	touch .${JOBUID}.status.${STEP}.intersect_with_genomic_features
STEP=$((STEP+1))

#######################
# Making BigWig Files #
#######################
# make BW files
echo2 "Making bigWig files for genome browser"
[ ! -f .${JOBUID}.status.${STEP}.make_bigWig_normalized_by_$NORMMETHOD ] && \
	bash $DEBUG piper_smallRNA_bed2_to_bw.sh \
		${GENOME_UNIQUEMAP_HAIRPIN_BED2} \
		${CHROM} \
		${NormScale} \
		$CPU \
		$BW_OUTDIR && \
	touch .${JOBUID}.status.${STEP}.make_bigWig_normalized_by_$NORMMETHOD
STEP=$((STEP+1))

##############################################
# Direct mapping to transposon/piRNA cluster #
##############################################
echo2 "Direct mapping to transposon and piRNA cluster"
. $COMMON_FOLDER/genomic_features
INSERT=`basename $INPUT`
[ ! -f .${JOBUID}.status.${STEP}.direct_mapping_normalized_by_$NORMMETHOD ] && \
for t in "${DIRECT_MAPPING[@]}"; do \
	bowtie -r -v ${transposon_MM} -a --best --strata -p $CPU \
		-S \
		${t} \
		${INPUT} \
		2> ${TRN_OUTDIR}/${t}.log | \
	samtools view -uS -F0x4 - 2>/dev/null | \
	samtools sort -o -@ $CPU - foo | \
	bedtools_piper bamtobed -i - > $TRN_OUTDIR/${INSERT%.insert}.${t}.a${transposon_MM}.insert.bed && \
	piper_insertBed_to_bed2 $INPUT $TRN_OUTDIR/${INSERT%.insert}.${t}.a${transposon_MM}.insert.bed > $TRN_OUTDIR/${INSERT%.insert}.${t}.a${transposon_MM}.insert.bed2 && \
	piper_bed2Summary -5 -i $TRN_OUTDIR/${INSERT%.insert}.${t}.a${transposon_MM}.insert.bed2 -c $COMMON_FOLDER/BowtieIndex/${t}.sizes -o $TRN_OUTDIR/${INSERT%.insert}.${t}.a${transposon_MM}.summary && \
	Rscript --slave ${PIPELINE_DIRECTORY}/bin/piper_draw_summary.R $TRN_OUTDIR/${INSERT%.insert}.${t}.a${transposon_MM}.summary $TRN_OUTDIR/${INSERT%.insert}.${t}.a${transposon_MM}.normalized_by_$NORMMETHOD $CPU $NormScale 1>&2 && \
	PDFs=$TRN_OUTDIR/${INSERT%.insert}.${t}.a${transposon_MM}.normalized_by_${NORMMETHOD}*pdf && \
	gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$PDF_DIR/${INSERT%.insert}.${t}.pdf ${PDFs} && \
	rm -rf $PDFs && \
	rm -rf $TRN_OUTDIR/${INSERT%.insert}.${t}.a${transposon_MM}.insert.bed
done && \
touch .${JOBUID}.status.${STEP}.direct_mapping_normalized_by_$NORMMETHOD
STEP=$((STEP+1))

#####################################################
# Direct mapping to and quantification with eXpress #
#####################################################
# for accurate quantification, we map to the index of gene+cluster+repBase. 
echo2 "Quantification by direct mapping and eXpress"
[ ! -f .${JOBUID}.status.${STEP}.direct_mapping_no_normalization ] && \
awk '{for (j=0;j<$2;++j) print $1}' $x_rRNA_x_hairpin_INSERT | \
bowtie \
	-r \
	-v ${transposon_MM} \
	-a --best --strata \
	-p $CPU \
	-S \
	gene+cluster+repBase \
	- 2> $EXPRESS_DIR/${PREFIX}.bowtie.gene+cluster+repBase.bowtie.log | \
	samtools view -bS - > \
	$EXPRESS_DIR/${PREFIX}.bowtie.gene+cluster+repBase.bam && \
touch .${JOBUID}.status.${STEP}.direct_mapping_no_normalization
STEP=$((STEP+1))

[ ! -f .${JOBUID}.status.${STEP}.quantification_by_eXpress ] && \
express \
	-B 21 \
	-m $(( (siRNA + piRNA_top)/2 )) \
	-s $(( (piRNA_top - 18)/2 )) \
	--output-align-prob \
	-o $EXPRESS_DIR \
	--no-update-check \
	--calc-covar \
	$COMMON_FOLDER/${GENOME}.gene+cluster+repBase.fa \
	$EXPRESS_DIR/${PREFIX}.bowtie.gene+cluster+repBase.bam \
	1>&2 2> $EXPRESS_DIR/${PREFIX}.eXpress.log && \
touch .${JOBUID}.status.${STEP}.quantification_by_eXpress
STEP=$((STEP+1))

################
# Joining Pdfs #
################
echo2 "Merging pdfs"
[ ! -f .${JOBUID}.status.${STEP}.merge_pdfs ] && \
	gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$PDF_DIR/${PREFIX}.${PACKAGE_NAME}.small_RNA_pipeline.${SMALLRNA_VERSION}.pdf \
		$PDF_DIR/`basename ${GENOME_UNIQUEMAP_BED2}`.+hairpin.lendis.pdf \
		$PDF_DIR/`basename ${GENOME_ALLMAP_BED2}`.+hairpin.lendis.pdf \
		$PDF_DIR/`basename ${GENOME_UNIQUEMAP_BED2}`.x_hairpin.lendis.pdf \
		$PDF_DIR/`basename ${GENOME_ALLMAP_BED2}`.x_hairpin.lendis.pdf  \
		$PDF_DIR/${PREFIX}.features.pdf  && \
	touch  .${JOBUID}.status.${STEP}.merge_pdfs
STEP=$((STEP+1))

#############
# finishing #
#############
echo2 "Finished running ${PACKAGE_NAME} small RNA pipeline version $SMALLRNA_VERSION"
echo2 "---------------------------------------------------------------------------------"
touch .${GENOME}.SMALLRNA_VERSION.${SMALLRNA_VERSION}





