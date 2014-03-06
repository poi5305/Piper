![LOGO](https://dl.dropboxusercontent.com/u/5238651/pipipe%20logo.jpg "RTI UMASSMED HHMI")
pipipe
=====

Integrated pipeline collections developed in the [Zamore Lab](http://www.umassmed.edu/zamore) and [ZLab](http://zlab.umassmed.edu/zlab) to analyze piRNA/transposon for different Next Generation Sequencing (*small RNA-Seq, RNA-Seq, Genomic-Seq, ChIP-Seq, CAGE-Seq and Degradome-Seq*). **pipipe** provides generic interface for different organisms/genomes with a particular optimization for fruit-fly and mouse, which were the main focus in our labs as well as the piRNA field.

For *small RNA-Seq*, *RNA-Seq* and *ChIP-Seq* pipelines, **pipipe** provides two modes in `single library mode` and `dual library mode`, to analyze single library and pair-wise comparision between two samples respectively.     

##INSTALL   
**pipipe** is written in Bash, C++, Perl, Python and R. It currently only works under Linux environment.

**pipipe** uses the following public tools:

1. For alignment, **pipipe** uses [Bowtie](http://bowtie-bio.sourceforge.net/index.shtml), [Bowtie2](http://bowtie-bio.sourceforge.net/bowtie2/index.shtml), [BWA](http://bio-bwa.sourceforge.net/),  [STAR](https://code.google.com/p/rna-star/) and [mrFast](http://mrfast.sourceforge.net/) for different purposes.		

2. For transcripts/transposons quantification, **pipipe** uses [Cufflinks](http://cufflinks.cbcb.umd.edu/), [HTSeq](http://www-huber.embl.de/users/anders/HTSeq/) and [eXpress](http://bio.math.berkeley.edu/eXpress) under different circumstances. 	

3. For transposon mobilization discovery, **pipipe** uses [RetroSeq](https://github.com/tk2/RetroSeq) and [VariationHunter](http://compbio.cs.sfu.ca/software-variation-hunter).    

4. For peaks calling for ChIP-Seq, **pipipe** uses [MACS2](https://github.com/taoliu/MACS).    
 
5. Additionally, **pipipe** uses many tools from the [Kent Tools](http://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64.v287/), like `faSize`, `bedGraphToBigWig`.   

6. To wrap bash scripts for multi-threading, **pipipe** utilizes `ParaFly` from [Trinity](http://trinityrnaseq.sourceforge.net/). **pipipe** also learns the `touch` trick for job resuming from [Trinity](http://trinityrnaseq.sourceforge.net/).	    

7. To determine the version of FastQ, **pipipe** uses a modified version of `SolexaQA.pl` from [SolexaQA](http://solexaqa.sourceforge.net/).		

8. **pipipe** uses [BEDtools](https://github.com/bowhan/bedtools.git) with slight modification on `intersectBed.cpp` to accomodate a special BED format used in the pipeline. It ships with the modified source code, as well as statically compiled binary renamed as `bedtools_pipipe` to avoid confusion with the real one.		

***
### C/C++
**pipipe ships with statically compiled linux x86_64 binaries for its own C++ codes and all the other tools that need compiling. Ideally, the users don't need to do any compiling. If compiling needs to be done, please makes it available in the `$PATH`. For bedtools, please compile the one in the `third_party` directory and rename it as `bedtools_pipipe` in the `bin` directory of `pipipe`** For your convinience, the source codes of all C/C++ tools have been included as tarball. Some of pipipe C++ codes utilizes *C++11* features and *Boost* libraries. It is recommended to install relatively new [GCC](http://gcc.gnu.org/) and [Boost](http://www.boost.org/users/download/) if compiling needs to be done.		 
***
### Python/Cython
**For MACS[8] and HTSeq-count[13], the users will need to install them and make them available in the `$PATH`.**        
*We cannot find a good way to ship the ready-to-use Cython code. Without `htseq-count`, `pipipe rna/deg/cage` won't be able to make transcripts/transposon counting using genomic coordinates. But it will still perform other functions of the pipeline as well as quantification using Cufflinks and eXpress. Without `macs2`, `pipipe chip/chip2` won't work at all*
***
### R
For R packages that are unavailable in the user's system, the installation is performed in the `pipipe install` process. They will be installed in the same directory as the pipeline in case the user doesn't have write permission in the R installation directory.
***

### Genome Annotation
Due to the limitation on the size of the files on github, the genome sequence, annotation files are to be downloaded from somewhere else and reformatted to accomodate the pipeline. **pipipe** uses [iGenome](http://support.illumina.com/sequencing/sequencing_software/igenome.ilmn) and provides `pipipe install` to download iGenome genomes and organize the files to be used by the pipeline (see below).		
***

##USAGE
The pipeline find almost everything under its own directory so please do not move the `zpipe` script. Use `ln  -s  $PATH_TO_PIPIPE/pipipe  $HOME/bin/pipipe` to create symbol link in your `$HOME/bin`; Or add `$PATH_TO_PIPIPE` to your `$PATH`. 

Call different pipelines using:		

```Bash
# genome installation pipeline
 # 1. to install genome and R packages in one step
$PATH_TO_PIPIPE/pipipe	install -g dm3|mm9|hg19... 
 # 2. to only download the genome and install R packages (if the node is not appropriate to be used for building indexes); then run (1).
$PATH_TO_PIPIPE/pipipe	install -g dm3|mm9|hg19 -D
 # 3. to only download the iGenome that pipipe doesn't know (yet)
$PATH_TO_PIPIPE/pipipe	install -g hg18 -l ftp://igenome:G3nom3s4u@ussd-ftp.illumina.com/Homo_sapiens/UCSC/hg18/Homo_sapiens_UCSC_hg18.tar.gz

# to run small RNA pipeline in single library mode; input fastq can be gzipped
$PATH_TO_PIPIPE/pipipe	small -i input.trimmed.fq[.gz] -g dm3 -c 24

# to run small RNA pipeline in dual library mode (need single library mode been ran for each sample first)
$PATH_TO_PIPIPE/pipipe	small2 -a directory_A -b directory_B -g dm3 -c 24
# to run small RNA pipeline in dual library mode, normalized to miRNA 
$PATH_TO_PIPIPE/pipipe	small2 -a directory_A -b directory_B -g mm9 -c 24 -N miRNA
# to run small RNA pipeline in dual library mode, normalized to siRNA (structural loci and cis-NATs), for oxidation sample of -fruitfly only-
$PATH_TO_PIPIPE/pipipe	small2 -a directory_A -b directory_B -g dm3 -c 24 -N siRNA

# to run RNASeq pipeline in single library mode, dUTP based method
$PATH_TO_PIPIPE/pipipe	rnaseq -l left.fq -r right.fq -g mm9 -c 8 -o output_dir

# to run RNASeq pipeline in single library mode, ligation based method
$PATH_TO_PIPIPE/pipipe	rnaseq -l left.fq -r right.fq -g mm9 -c 8 -o output_dir -L

# to run RNASeq pipeline in dual library mode (need single library mode been ran for each sample first)
$PATH_TO_PIPIPE/pipipe	rnaseq2 -a directory_A -b directory_B -g mm9 -c 8 -o output_dir -A w1 -B piwi

# to run Degradome/RACE/CAGE-Seq library 
$PATH_TO_PIPIPE/pipipe	deg -l left.fq -r right.fq -g dm3 -c 12 -o output_dir

# to run ChIP Seq library in single library mode, for narrow peak, like transcriptional factor
$PATH_TO_PIPIPE/pipipe	chip -l left.IP.fq -r right.IP.fq -L left.INPUT.fq -R right.INPUT.fq -g mm9 -c 8 -o output_dir

# to run ChIP Seq library in single library mode, for broad peak, like H3K9me3
$PATH_TO_PIPIPE/pipipe	chip -l left.IP.fq -r right.IP.fq -L left.INPUT.fq -R right.INPUT.fq -g mm9 -c 8 -o output_dir -B

# to run ChIP Seq library in single library mode, only use unique mappers (otherwise Bowtie2 randomly choose one best alignment for each read)
$PATH_TO_PIPIPE/pipipe	chip -l left.IP.fq -r right.IP.fq -L left.INPUT.fq -R right.INPUT.fq -g mm9 -c 8 -o output_dir -Q 10

# to run ChIP Seq library in dual library mode (need single library mode been ran for each sample first)
$PATH_TO_PIPIPE/pipipe	chip2 -a directory_A -b directory_B -g mm9 -c 8 -o output_dir

# to run ChIP Seq library in dual library mode, extend up/down stream 5000 bp for TSS/TES/meta analysis (by bwtool)
$PATH_TO_PIPIPE/pipipe	chip2 -a directory_A -b directory_B -g mm9 -c 8 -o output_dir -x 5000

# to run Genome Seq library
$PATH_TO_PIPIPE/pipipe	dna -l left.fq -r right.fq -g dm3 -c 24 -D 100
```
Find more detailed information on [Wiki](https://github.com/bowhan/pipipe/wiki)

###*install*: to install genome assembly
Due to the limitation on the size of file by github, pipipe doesn't ship with the 
genome sequences and annotation. Alternatively, we provide this scrips 
to download genome assemly files from iGenome project of illumina. Please make 
sure internet is available during this process.  **pipipe** provide an option to separate downloading from other process, in case the machine/node with internet access is not appropriate for building index and other works.     
Except for the genome, this pipeline will also install unavailable R packages 
under the pipeline directory. The downloading and installation can be separated using -D option, in case the head node is not supposed to be used for heavy computational work, like building indexes.      

A more detailed explanation can be found [here](https://github.com/bowhan/pipipe/wiki/installation).  

###*small*: small RNA pipeline
small RNA library typically clones 18–40nt small RNAs, including miRNA, siRNA and 
piRNA. This pipeline maps those reads to rRNA, microRNA hairpin, genome, repbase 
annotated  transposons, piRNA clusters with bowtie and uses bedtools to assign 
them to different annotations. For each feature, length distrition, nucleotide percentage, 
ping-pong score, et al,.  are calculated and graphed. Some microRNA analysis is also included. 
In the dual library mode, pair-wise comparision of miRNA and piRNAs will be done. We invented this balloon-plot to efficienty compare the heterogeneity of miRNA between two samples. piRNA for different transposon family is also compared. 

A more detailed explanation can be found [here](https://github.com/bowhan/pipipe/wiki/smallRNA).

###*rnaseq*: RNASeq pipeline
RNASeq pipeline can be used for both dUTR or ligation based RNASeq. 
It uses bowtie2 to align paired-end reads to rRNA and STAR[4] to align the unmapped reads 
to genome; Then it uses Cufflinks for quantification of transcripts from the genomic coordinates. It
also use HTSeq-count to quantify genomic features using coordinates. It also directly align reads to 
transcriptome, repbase annotated transposon, piRNA clusters using Bowtie2. Quantification 
was done using eXpress. Library is normalized by gene transcriptome compatible reads, given by Cufflinks. Basic statistics and graphs will be given. 

A more detailed explanation can be found [here](https://github.com/bowhan/pipipe/wiki/RNASeq).  

###*cage/deg*: CAGE & Degradome pipeline
Both types of libraries are designed to gather the information of the 5' end of RNAs 
CAGE clones RNAs with Cap and Degradome clones RNAs with 5' monophosphate. 
The pipeline will aligns reads to rRNA with bowtie2, genome using STAR. 
Different from RNASeq, this pipeline emphasizes on the accuracy of the 5' ends. Nucleotide
composition surrounding the 5' end of the reads are given, like in small RNA library.

A more detailed explanation can be found [here](https://github.com/bowhan/pipipe/wiki/DegradomeSeq).

###*chip*: ChIP-Seq pipeline
ChIP Seq pipeline aligns both input and ChIP data to genome with Bowtie2. Peak calling was done
using MASC2. Signal is normalized in three different methods (ppois, FE and logLR). TSS/TES/meta plots are drawn using bwtool. In the dual library mode, peak calling is redone for each sample without inter-library normalization, by differential peak calling algorithm of MACS2 directly. TSS/TES/meta plots are drawn for those loci using the normalized signal. 

A more detailed explanation can be found [here](https://github.com/bowhan/pipipe/wiki/ChIPSeq). 

###*dna*: Genomic Seq pipeline
Genomic Seq pipelines aligns the paired-end reads to genome with Bowtie2, BWA-MEM and mrFast. Variatoins
were called using different algorithms. 

A more detailed explanation can be found [here](https://github.com/bowhan/pipipe/wiki/GenomeSeq).


##Citing
* in preparation

##Contact
    Wei Wang (wei.wang2 `at` umassmed.edu)
    Bo W Han (bo.han `at` umassmed.edu, bowhan `at` me.com)
    
##References
```
[1] Li H and Durbin R. 2009. Fast and accurate short read alignment with Burrows-Wheeler transform. Bioinformatics 25: 1754-1760.  
[2] Langmead B, Trapnell C, Pop M and Salzberg SL. 2009. Ultrafast and memory-efficient alignment of short DNA sequences to the human genome. Genome Biol 10: R25.  
[3] Langmead B and Salzberg SL. 2012. Fast gapped-read alignment with Bowtie 2. Nat Methods 9: 357-359.    
[4] Dobin A, Davis CA, Schlesinger F, Drenkow J, Zaleski C, Jha S, Batut P, Chaisson M and Gingeras TR. 2013. STAR: ultrafast universal RNA-seq aligner. Bioinformatics 29: 15-21.    
[5] Trapnell C, Williams BA, Pertea G, Mortazavi A, Kwan G, van Baren MJ, Salzberg SL, Wold BJ and Pachter L. 2010.     
[6] Transcript assembly and quantification by RNA-Seq reveals unannotated transcripts and isoform switching during cell differentiation. Nat Biotechnol 28: 511-515. 
[7] Kent WJ, Zweig AS, Barber G, Hinrichs AS and Karolchik D. 2010. BigWig and BigBed: enabling browsing of large distributed datasets. Bioinformatics 26: 2204-2207.     
[8] Zhang Y et al. 2008. Model-based analysis of ChIP-Seq (MACS). Genome Biol 9: R137.  
[9] Roberts A and Pachter L. 2013. Streaming fragment assignment for real-time analysis of sequencing experiments. Nat Methods 10: 71-73.  
[10] Grabherr MG et al. 2011. Full-length transcriptome assembly from RNA-Seq data without a reference genome. Nat Biotechnol 29: 644-652.     
[11] Karolchik D, Hinrichs AS, Furey TS, Roskin KM, Sugnet CW, Haussler D and Kent WJ. 2004. The UCSC Table Browser data retrieval tool. Nucleic Acids Res 32: D493-D496.		
[12] Cox MP, Peterson DA and Biggs PJ. 2010. SolexaQA: At-a-glance quality assessment of Illumina second-generation sequencing data. BMC Bioinformatics 11: 485.	
[13] HTSeq: Analysing high-throughput sequencing data with Python. [http://www-huber.embl.de/users/anders/HTSeq/]  
[14] Keane TM, Wong K and Adams DJ. 2013. RetroSeq: transposable element discovery from next-generation sequencing data. Bioinformatics 29: 389-390.    
[15] Hormozdiari F, Hajirasouliha I, Dao P, Hach F, Yorukoglu D, Alkan C, Eichler EE and Sahinalp SC. 2010. Next-generation VariationHunter: combinatorial algorithms for transposon insertion discovery. Bioinformatics 26: i350-i357.    
```
