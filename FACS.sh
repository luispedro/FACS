#!/usr/bin/env bash

############################################################################################################################
############################## FACS pipeline - Fast AMP Clustering and Screening        ####################################
############################################################################################################################
############################## Authors: Célio Dias Santos Júnior, Luis Pedro Coelho     ####################################
############################################################################################################################
############################## Institute > ISTBI - FUDAN University / Shanghai - China  ####################################
############################################################################################################################
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#

##################################################### Variables ############################################################
Lib="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Default variables
outfolder_DEFAULT="FACS_output"
outfolder=$outfolder_DEFAULT

block_DEFAULT="100M"
block=$block_DEFAULT

j=$(nproc)

outtag_DEFAULT="FACS_OUT"
outtag=$outtag_DEFAULT

mem_DEFAULT="0.75"
mem=$mem_DEFAULT

tp=$(mktemp --tmpdir --directory FACS.XXXXXXX)
cls="1"
ep="0"
log="log.txt"

# Help message
show_help ()
{
    echo "
    ############################################################################################################################
    ############################## FACS pipeline - Fast AMP Clustering System               ####################################
    ############################################################################################################################
    ############################## Authors: Célio Dias Santos Júnior, Luis Pedro Coelho     ####################################
    ############################################################################################################################
    ############################## Institute > ISTBI - FUDAN University / Shanghai - China  ####################################
    ############################################################################################################################

    Usage: FACS.sh --mode c/r/p/a [options]

    Here's a guide for avaiable options. Defaults for each option are showed between brackets: [default].

    Basic options:

    -h, --help          Show this help message

    -m          Mode of operation, one of:
                \"c\" to work with contigs,
                \"p\" to predict AMPs directly from a peptides FASTA file,
                \"r\" to work with paired-end reads,
                \"a\" to map reads against AMP output database and generate abundances table

    --fasta             Contigs or peptides fasta file (possibly compressed)
    --fwd               Short-read sequencing file in FASTQ format (forward reads file)
    --rev               Short-read sequencing file in FASTQ format (reverse reads file)
    --ref               Output of module \"c\" in its raw format [file type TSV and compressed ]
    --outfolder         Folder where output will be generated [$outfolder_DEFAULT]
    --outtag            Tag used to name outputs [Default: $outtag_DEFAULT]
    -t, --threads [N]   Number of threads [Default: number of processors]
    --block             Bucket size (in Bytes, but M/G/T/m/g/t postfixes are accepted). [$block_DEFAULT]
    --log               Log file name. FACS will save the run results to this log file in output folder.
    --mem               Memory available to FACS ranging from 0 - 1. [$mem_DEFAULT]
    --tmp               Temporary folder
    --cls               Cluster peptides: yes (1) or no (0). [Default: 1 - yes]
    --ep                Extra profilling (solubility, proteases susceptibility and antigenicity): yes (1) or no (0). [Default: 0 - no ]
"
}

# Taking flags
while [[ $# -gt 0 ]]
do
    case $1 in
        -h|--help|-help|\?|-\?)
            show_help
            exit 0
        ;;
        -m|-M|--mode|--Mode|--m|--M)
            mode=${2}
        ;;
        -tmp|-TMP|--tmp|--TMP|--tp)
            rmdir $tp
            tp=${2}
        ;;
        -t|-T|--threads|--Threads|--THREADS|--t|--T)
            j=${2}
        ;;
        --fasta|-fasta|-fa)
            fasta=$(readlink -f ${2})
            if [[ $? != 0 ]]; then
                echo "[ Could not find fasta file (${2}) ]"
                exit 1
            fi
        ;;
        --fwd|-fwd|--FWD|-r1|-R1|-l)
            read_1=$(readlink -f ${2})
            if [[ $? != 0 ]]; then
                echo "[ Could not find forward read file (${2}) ]"
                exit 1
            fi
        ;;
        --rev|--Rev|-rev|-R2|-r2)
            read_2=$(readlink -f ${2})
            if [[ $? != 0 ]]; then
                echo "[ Could not find reverse read file (${2}) ]"
                exit 1
            fi
        ;;
        --outfolder|-outfolder|-of)
            outfolder=$(readlink -f ${2})
            if [[ $? != 0 ]]; then
                echo "[ Could not find output folder (${2}) ]"
                exit 1
            fi
        ;;
        --outtag|-tag)
            outtag=${2}
        ;;
        --block|-b|-block)
            block=${2}
        ;;
        --log|-log)
            log=${2}
        ;;
        -ref|--ref|--Ref|-Ref)
            reference=$(readlink -e ${2})
            if [[ $? != 0 ]]; then
                echo "[ Could not find reference file (${2}) ]"
                exit 1
            fi
        ;;
        -mem|--Mem|--mem|-Mem)
            mem=${2}
        ;;
        -cls|--cls)
            cls=${2}
        ;;
        -ep|--ep)
            ep=${2}
        ;;
    esac
    shift
done

sanity_check ()
# Checking input variables
{
if [[ -n $mode ]]
then
    if [[ $mode == "r" ]]
    then
        
        
        
        if [[ -n $read_1 ]]
        then
            if [[ -n $read_2 ]]
            then
                if [[ -s $read_1 ]] || [[ -s $read_2 ]]
                then
                    echo "[ M ::: FACS has found your reads files ($read_1/$read_2), starting work... ]"
                    mode="pe"
                    echo -e "[ M ::: Configuration ]
Mode        $mode
Threads     $j
read_R1     $read_1
read_R2     $read_2
Folder      $outfolder
Tag         $outtag
Bucket      $block
Log         $outfolder/$log"
                else
                    >&2 echo "[ ERR010 - FACS has not found your reads files. ]"
                    exit 1
                fi
            elif [[ -s $read_1 ]]
            then
                echo "[ M ::: FACS mode has been assigned as single-end reads ]
[ M ::: FACS has found your reads files, starting work... ]"
                mode="se"
                echo -e "[ M ::: Here we specify your variables ]

Mode        $mode
Threads     $j
read_R1     $read_1
Folder      $outfolder
Tag         $outtag
Bucket      $block
Log         $outfolder/$log"
            else
                >&2 echo "[ W ::: ERR010 - FACS has not found your reads file ($read_1). ]"
                exit 1
            fi
        else
            >&2 echo "[ W ::: ERR010 - FACS has not found your read files. ]"
            exit 1
        fi
    elif    [[ $mode == "p" ]]
    then
        mode="pep"
        
        if [ -s "$fasta" ]
        then
            echo "[ M ::: FACS has found your peptides fasta file, starting work... ]"
            echo -e "[ M ::: Configuration ]

Mode        p
Threads     $j
Contigs     $fasta
Folder      $outfolder
Tag         $outtag
Bucket      $block
Log         $outfolder/$log"
        else
            >&2 echo "[ ERR011 - Peptides file ($fasta) is not present ]"
            exit 1
        fi
    elif    [[ $mode == "c" ]]
    then
        
        if [ -s "$fasta" ]
        then
            echo "[ M ::: FACS has found your contigs file, starting work... ]"
            echo -e "[ M ::: Here we specify your variables ]

Mode        $mode
Threads     $j
Contigs     $fasta
Folder      $outfolder
Tag         $outtag
Bucket      $block
Log         $outfolder/$log"
        else
            >&2 echo "[ W ::: ERR011 - Contigs file ($fasta) not found ]"
            exit 1
        fi
    elif [[ $mode == "a" ]]
    then
        echo "[ M ::: FACS mode has been assigned as read mapper ]"
        
        
        if [ -s "$reference" ]
        then
            RF="0"
            if [[ -s "$read_1" ]] && [[ -s "$read_2" ]]
            then
                mode="mpe"
                echo "[ M ::: FACS has found your reference data set, starting work... ]"
                echo -e "[ M ::: Here we specify your variables ]

** Mapper with paired-end reads
Mode        $mode
Threads     $j
Reference   $reference
R1          $read_1
R2          $read_2
Folder      $outfolder
Tag         $outtag
Bucket      $block
Log         $outfolder/$log"
            elif [[ -s "$read_1" ]]
            then
                mode="mse"
                echo "[ M ::: FACS has found your reference data set, starting work... ]"
                echo -e "[ M ::: Here we specify your variables ]

** Mapper with single-end reads
Mode        $mode
Threads     $j
Reference   $reference
R1          $read_1
Folder      $outfolder
Tag         $outtag
Bucket      $block
Log         $outfolder/$log"
            else
                >&2 echo " [ W ::: ERR011 - FACS has not found your reads files ]"
                exit 1
            fi
        elif [ -s "$fasta" ]
        then
            RF="1"
            if [[ -s "$read_1" ]] && [[ -s "$read_2" ]]
            then
                mode="mpe"
                echo "[ M ::: FACS has found your reference data set, starting work... ]"
                echo -e "[ M ::: Here we specify your variables ]

** Mapper with paired-end reads
Mode        $mode
Threads     $j
Reference   $fasta
R1          $read_1
R2          $read_2
Folder      $outfolder
Tag         $outtag
Bucket      $block
Log         $outfolder/$log"
            elif [[ -s "$read_1" ]]
            then
                mode="mse"
                echo "[ M ::: FACS has found your reference data set, starting work... ]"
                echo -e "[ M ::: Here we specify your variables ]

** Mapper with single-end reads
Mode        $mode
Threads     $j
Reference   $fasta
R1          $read_1
Folder      $outfolder
Tag         $outtag
Bucket      $block
Log         $outfolder/$log"
            else
                >&2 echo "[ W ::: ERR011 - FACS has not found your reads files ]"
                exit 1
            fi
        else
            >&2 echo "[ W ::: ERR011.1 - FACS has not found your reference file ($reference) ]"
            exit 1
        fi
    fi
else
    >&2 echo "[ W ::: ERR010 - The user needs to specify a valid FACS mode, please review the command line]"
    exit 1
fi

if [[ ! -e $tp ]];
then
    echo "[ Temporary folder ($tp) does not exist. Creating it... ]"
    mkdir $tp
    cd $tp
elif [[ -e $tp ]];
then
    cd $tp
elif [[ ! -d $tp ]];
then
    echo "[ Temporary folder ($tp) already exists but is not a directory ]" 1>&2
fi

if [[ -n $outfolder ]]
then
    if [ -d "$outfolder" ]
    then
        echo ""
    else
        echo "[ W ::: Directory $outfolder does not exist.  Creating it... ]"
        mkdir -p $outfolder || (>&2 echo "[ Error creating output folder ($outfolder) ]" ; exit 1)
    fi
else
    >&2 echo "[ No output folder specified ]"
    exit 1
fi

}

############################################################################################################################
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
################################################       ENV      ############################################################

export PATH=$Lib:$PATH

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
################################################    FUNCTIONS   ############################################################
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
################################# 1. generating two files with matching pairs of reads #####################################

read_trimming ()
{
echo "[ M ::: Trimming low quality bases ]"
if [[ $1 == "paired" ]]
then
    ngl=trim.pe.ngl
    files="$read_1 $read_2"
else
    ngl=trim.se.ngl
    files="$read_1"
fi

ngless --no-create-report --quiet -j $j --temporary-directory $tp $Lib/$ngl $files
if [[ $? != 0 ]]
then
    >&2 echo "[ W ::: ERR231 - Read trimming failed ]"
    cd ../
    rm -rf $tp
    exit 1
fi
}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
########################################## 2. Assembly of contigs ##########################################################

assemble ()
{
echo "[ M ::: Assembly using MEGAHIT ]"
if [[ $mode == "pe" ]]
then
    megahit --presets meta-large -1 preproc.pair.1.fq.gz -2 preproc.pair.2.fq.gz -o out -t "$j" -m "$mem" --min-contig-len 1000
elif [[ $mode == "se" ]]
then
    megahit --presets meta-large -r preproc.pair.1.fq.gz -o out -t "$j" -m "$mem" --min-contig-len 1000
else
    >&2 echo "[ E ::: ERR222 - Internal Error: should never happen ]"
    cd ../; rm -rf $tp
    exit 1
fi

if [[ -s out/final.contigs.fa ]]
then
    mv out/final.contigs.fa .callorfinput.fa
    rm -rf out/ preproc.pair.1.fq.gz preproc.pair.2.fq.gz
else
    >&2 echo "[ W ::: ERR128 - Assembly failed ]"
    cd ../; rm -rf $tp/
    exit 1
fi
}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
########################################## 2. Generating peptides ##########################################################

callorf ()
{

if [[ "$mode" != "pep" ]]
then
    echo "[ M ::: Calling ORFs ]"

    rm -rf callorfs/
    mkdir callorfs

    cat .callorfinput.fa | \
        parallel -j $j --block $block --recstart '>' --pipe \
            prodigal_sm -c -m -n -p meta -f sco -a callorfs/{#}.pred.smORFs.fa
            >/dev/null

    ls callorfs/*pred.smORFs.fa > t
    if [ -s t ]
    then
        rm -rf t
    else
        >&2 echo "[ W ::: ERR910 - Error in producing predictions ]"
        cd ../; rm -rf $tp
        exit 1
    fi

    if [[ $mode == "c" ]]
    then
        rm -rf .callorfinput.fa
    else
        mv .callorfinput.fa $outfolder/$outtag.contigs.fna
        pigz --best $outfolder/$outtag.contigs.fna
    fi

    echo "[ M ::: Filtering smORFs ]"

    for i in callorfs/*;
    do
        awk '/^>/ {printf("%s%s\n",(N>0?"\n":""),$0);N++;next;} {printf("%s",$0);} END {printf("\n");}' $i | \
            awk '{y= i++ % 2 ; L[y]=$0; if(y==1 && length(L[1])<=100) {printf("%s\n%s\n",L[0],L[1]);}}' \
            > $i.filtered
        rm -rf $i
    done

    cat callorfs/* > .pep.faa.tmp
    rm -rf callorfs/
    rm -rf .callorfinput.fa
else
    awk '/^>/ {printf("%s%s\n",(N>0?"\n":""),$0);N++;next;} {printf("%s",$0);} END {printf("\n");}' .callorfinput.fa \
        | awk '{y= i++ % 2 ; L[y]=$0; if(y==1 && length(L[1])<=100) {printf("%s\n%s\n",L[0],L[1]);}}' \
        > .pep.faa.tmp
    rm -rf .callorfinput.fa
fi

if [ -s ".pep.faa.tmp" ]
then

    if [[ $cls == 1 ]]
    then

        echo "[ M ::: Performing reduction in sampling space ]"

        sed 's/ /_/g' .pep.faa.tmp | sed 's/;/|/g' \
            | awk '/^>/ {printf("%s%s\t",(N>0?"\n":""),$0);N++;next;} {printf("%s",$0);} END {printf("\n");}' \
            | awk '{print $2"\t"$1}' > .tmp

        rm -rf .pep.faa.tmp
        
        echo "[ M ::: Sorting peptides list ]"
        mkdir sorting_folder/
        
        cat .tmp | parallel --pipe  -j $j --block "$block" --recstart "\n" "cat > sorting_folder/small-chunk{#}" >/dev/null
        rm -rf .tmp

        for X in $(ls sorting_folder/small-chunk*); do sort -S 80% --parallel="$j" -k1,1 -T . < "$X" > "$X".sorted; rm -rf "$X"; done

        sort -S 80% --parallel="$j" -T . -k1,1 -m sorting_folder/small-chunk* > .sorted-huge-file; rm -rf sorting_folder/

        perl -n -e "print unless /^$/" .sorted-huge-file \
            | awk -F'\t' -v OFS=';' '{x=$1;$1="";a[x]=a[x]$0}END{for(x in a)print x,a[x]}' \
            | sed 's/;;/\t/g' \
            | sed 's/>//g' \
            | sed 's/\*//g' \
            > .tmp2

        if [[ -s .tmp2 ]]
        then
            echo "[ M ::: Eliminated all duplicated sequences ]"
            rm -rf .sorted-huge-file
        else
            >&2 echo "[ W ::: ERR510 - Memdev sorting stage has failed ]"
            cd ../; rm -rf $tp
            exit 1
        fi

        echo "[ M ::: Outputting genes lists ]"

        awk '{print ">smORF_"NR"\t"$1"\t"$2}' .tmp2 | pigz --best > $outfolder/$outtag.ids.tsv.gz

        echo "[ M ::: Outputting fastas ]"

        awk '{print ">smORF_"NR"\n"$1}' .tmp2 > .pep.faa
        rm -rf .tmp2
        
        echo "[ M ::: Collecting statistics ]"

        tail -2 .pep.faa \
            | head -1 \
            | sed 's/|/\t/g' \
            | cut -f2 \
            | sed 's/>smORF_//g' \
            > .all.nmb

    else

        echo "[ M ::: Skipping clustering ]"
        mv .pep.faa.tmp .pep.faa
        grep -c ">" .pep.faa > .all.nmb

    fi

else
    >&2 echo "[ W ::: ERR122 - ORFs calling procedure failed ]"
    cd ../; rm -rf $tp
    exit 1
fi


}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
######################################## 5. computing descriptors ########################################################

descriptors ()
{
echo "[ M ::: Split input into chunks ]"
mkdir splits/
parallel --pipe  -j $j --block "$block" --recstart ">" "cat > splits/small-chunk{#}" < .pep.faa >/dev/null
rm -rf .pep.faa

for i in splits/small-chunk*
do
    count=`grep -c ">" $i`
    echo -e "$i\t$count" >> counte.tsv
    unset count
    echo "[ M ::: Counting distribution using SA scale -- $i ]"
    python3 "$Lib"/CTDDClass.py "$i" .CTDDC-SA.tsv 'ALFCGIVW' 'RKQEND' 'MSPTHY' #solventaccess
    awk '{print $2"\t"$7"\t"$12}' .CTDDC-SA.tsv > .tmp
    sed -i '1,1d' .tmp
    echo -e "SA.G1.residue0\tSA.G2.residue0\tSA.G3.residue0" > .header
    cat .header .tmp > .CTDDC-SA.tsv;
    
    rm -rf .tmp .header

    echo "[ M ::: Counting distribution using HB scale -- $i ]"
    python3 "$Lib"/CTDDClass.py "$i" .CTDDC-hb.tsv 'ILVWAMGT' 'FYSQCN' 'PHKEDR' # HEIJNE&BLOMBERG1979
    awk '{print $2"\t"$7"\t"$12}' .CTDDC-hb.tsv > .tmp
    sed -i '1,1d' .tmp
    echo -e "hb.Group.1.residue0\thb.Group.2.residue0\thb.Group.3.residue0" > .header
    cat .header .tmp > .CTDDC-hb.tsv;
    
    rm -rf .tmp .header

    if [[ -s .CTDDC-SA.tsv ]] && [[ -s .CTDDC-hb.tsv ]]
    then
        echo "[ M ::: Computing cheminformatics descriptors -- $i ]"
        echo -e "header\tseq\tgroup" > .tmp
        sed '/>/d' "$i" > .seqs
        grep '>' "$i" | sed 's/ .*//g' | sed 's/>//g' > .heade
        paste -d'\t' .heade .seqs | awk '{print $1"\t"$2"\t""Unk"}' >> .tmp
        rm -rf .heade .seqs
        rm -rf "$i"
        Rscript --vanilla $Lib/features_130819.R .tmp .out.file >/dev/null
        
        rm -rf .tmp
    
        echo "[ M ::: Formatting descriptors -- $i ]"
        if [ -s .out.file ]
        then
            paste -d'\t' .out.file .CTDDC-SA.tsv .CTDDC-hb.tsv | sed 's/\"//g' > $i.tabdesc.tsv
            rm -rf .out.file .CTDDC-SA.tsv .CTDDC-hb.tsv
        else
            rm -rf .CTDDC-SA.tsv .CTDDC-hb.tsv $i
            echo "[ W ::: Error in predictors calculation during cheminformatics steps -- ERR 229 ]
[ ======> Erractic sample $i ]"
        fi
    else
                rm -rf $i
                echo "[ W ::: Error in predictors calculation during CTD steps -- ERR 230 ]
[ ======> Erractic sample $i ]"
    fi
done
}

checkout()
{

for i in splits/small-chunk*
do
    colu=$(awk -F'\t' '{print NF}' $i | sort -nu | wc -l)
    colv=$(awk -F'\t' '{print NF}' $i | sort -nu)
    if [[ "$colu" == "1" ]] && [[ "$colv" == "25"  ]]
    then
        ce=$(grep -w "${i/.tabdesc.tsv/}" counte.tsv | awk '{print $2}')
        coe=$(($ce+1))
        rown=$(awk '{print NR}' $i | tail -1)
        if [[ "$rown" == "$coe" ]]
        then
            touch $i
        else
            rm -rf $i
            echo "[ W ::: Error in table of descriptors // Wrong row formatting -- ERR 89 ]
[ ======> Erractic sample $i ]"
        fi
    else
        echo "[ W ::: Error in table of descriptors // Wrong column formatting -- ERR 29 ]
[ ======> Erractic sample $i ]"
        rm -rf $i
    fi
    unset colv colu rown coe ce
done
}

predicter()
{
if [ "$(ls -A splits/)" ]
then

    for i in splits/small-chunk*
    do
        echo "[ M ::: Predicting AMPs -- $i ]"
        Rscript --vanilla $Lib/Predict_130819.R $i "$Lib"/r22_largeTraining.rds "$Lib"/rf_dataset1.rds "${i/.tabdesc.tsv/.fin}" >/dev/null
        if [[ -s "${i/.tabdesc.tsv/.fin}" ]]
        then
            touch "${i/.tabdesc.tsv/.fin}"
            rm -rf "$i" "$Lib"/__pycache__/
        else
            echo "[ W ::: Sample ${i/.tabdesc.tsv/} did not return any AMP sequences ]"
            rm -rf "$Lib"/__pycache__/ "$i"
        fi
    done
else
    cd ../
    rm -rf $tp
    >&2 echo "[ W ::: There is not valid samples to be processed over pipeline, we are sorry -- ERR675 ]"
    exit 1
fi
}

EXTRADATA()
{
awk '{print ">"$1"\n"$2}' .out2.file > .tmp.fasta
cut -f1 .out2.file | sort | uniq  > listall

# To install protein solubility software
# wget --header 'Host: protein-sol.manchester.ac.uk' --referer 'https://protein-sol.manchester.ac.uk/software' --header 'Upgrade-Insecure-Requests: 1' 'https://protein-sol.manchester.ac.uk/cgi-bin/utilities/download_sequence_code.php' --output-document 'protein-sol-sequence-prediction-software.zip'
# unzip protein-sol-sequence-prediction-software.zip
# mv protein-sol-sequence-prediction-software/ $Lib/envs/FACS_env/bin/

# To install emboss:
# wget -m 'ftp://emboss.open-bio.org/pub/EMBOSS/'
# cp emboss.open-bio.org/pub/EMBOSS/EMBOSS-6.6.0.tar.gz ./
# tar -zxf EMBOSS-6.6.0.tar.gz
# cd EMBOSS-6.6.0/
# ./configure
# make
# cd emboss/
# rm -rf *.c *.h
# mv * $Lib/envs/FACS_env/bin/

echo "[ W ::: Just extra moments to assess the predicted AMPs ]"
echo "[ W ::: Predicting solubility ]"
cp $Lib/envs/FACS_env/bin/protein-sol-sequence-prediction-software/* ./
sh multiple_prediction_wrapper_export.sh .tmp.fasta
grep "SEQUENCE PREDICTIONS,>" seq_prediction.txt | sed 's/SEQUENCE PREDICTIONS,>//g' | sed 's/,/\t/g' > protein-sol.res.tsv
rm -rf .tmp* seq_prediction.txt
awk '{print ">"$1"\n"$2}' .out2.file > .tmp.fasta
cat protein-sol.res.tsv | cut -f1,2,3 | sort -k1,1 > sol
rm -rf protein-sol.res.tsv

echo "[ W ::: Predicting antigenicity ]"
$Lib/envs/FACS_env/bin/antigenic -sequence .tmp.fasta -sprotein1 Y -sformat1 FASTA -minlen 9 -outfile antigenic -rformat excel -rmaxseq2 1 -raccshow2 1 >/dev/null
sed -i '/SeqName/d' antigenic
echo -e "SeqName\tStart\tEnd\tScore\tStrand\tMax_score_pos" > header
cat antigenic | cut -f1 | sort | uniq | awk '{print $1"\t""+"}' > antigen
cat antigenic | cut -f1 | sort | uniq > list0
cat header antigenic | pigz --best > "$outfolder"/"$outtag".antigenic.tsv.gz
rm -rf header antigenic

echo "[ W ::: Creating lists ]"
grep -v -w -f list0 listall > non_antigenic_AMP; rm -rf list0
awk '{print $1"\t""-"}' non_antigenic_AMP > list1
cat antigen list1 | sort -k1,1 > tmp; mv tmp antigen
rm -rf list1 list2 non_antigenic_AMP

echo "[ W ::: Predicting protease sensitivity ]"
echo "[ W ::: This can take a while, since analysis proceed in single sequences ]"
awk '/^>/ {OUT=substr($0,2) ".seq";print " ">OUT}; OUT{print >OUT}' .tmp.fasta

for i in *.seq;
do
    $Lib/envs/FACS_env/bin/epestfind -sequence $i  -window 9 -order score -outfile ${i/.seq/.epest} -graph none -nopoor -nomap >/dev/null
    cat ${i/.seq/.epest} >> final
    rm -rf ${i/.seq/.epest} $i
done

cat final \
    | sed '/PEST-find/d' \
    | grep "No PEST motif was identified in " \
    | sed 's/No PEST motif was identified in //g' \
    | sed 's/^.   //g' \
    | sed 's/ .*//g' \
    | awk '{print $1"\t""-"}' \
    > nonprotea.list

cat final \
    | sed '/PEST-find/d' \
    | grep -v "No PEST motif was identified in " \
    | sed '/^[[:space:]]*$/d' \
    | pigz --best \
    > "$outfolder"/"$outtag".protealytic_assessment.txt.gz

cat final \
    | grep -v "No PEST motif was identified in " \
    | grep "PEST motif was identified in " \
    | sed 's/^.* PEST motif was identified in //g' \
    | sed 's/ .*//g' \
    | awk '{print $1"\t""+"}' \
    > protea.list

cat protea.list nonprotea.list | sort -k1,1 > protea
rm -rf final *.list

pl=$(zcat "$outfolder"/"$outtag".protealytic_assessment.txt.gz | awk '{print NR}' | tail -1)
if [[ $pl -gt 1 ]]
then
    echo ""
else
    rm -rf zcat "$outfolder"/"$outtag".protealytic_assessment.tsv.gz
    echo "[ W ::: No AMPs returned EPEST motifs ]"
fi

echo "[ W ::: Checking structures ]"
echo -e "antigen\nprotea\nsol" > quicktest.list
fin=$(awk '{print NR}' .out2.file | tail -1)
for i in $(cat quicktest.list);
do
    rown=$(awk '{print NR}' $i | tail -1)
    if [[ "$fin" == "$rown" ]]
    then
        touch $i
    else
        echo "[ W ::: Ending loop ]"
        echo -e "Access\tSequence\tAMP_family\tAMP_probability\tHemolytic\tHemolytic_probability" > header
        cat header .out2.file > tmp; mv tmp "$outfolder"/"$outtag".tsv
        rm -rf header .out2.file protea antigen sol quicktest.list
        echo "[ W ::: Error // Wrong row formatting -- ERR 989 ]"
    fi
    unset rown
done
unset fin

if [ -s .out2.file ]
then
    echo "[ W ::: Formatting lists ]"
    sort -k1,1 .out2.file > tmp1
    sort -k1,1 protea | awk '{$1=""}1' | sed 's/^.* //g'  > tmp4
    sort -k1,1 antigen | awk '{$1=""}1' | sed 's/^.* //g'  > tmp3
    sort -k1,1 sol | awk '{$1=""}1' | sed 's/^ //g' | sed 's/ /\t/g' > tmp2
    rm -rf .out2.file protea antigen sol quicktest.list

    paste -d'\t' tmp1 tmp2 tmp3 tmp4 > .out.file
    rm -rf .out2.file protea antigen sol

    echo -e "Access\tSequence\tAMP_family\tAMP_probability\tHemolytic\tHemolytic_probability\tPercent_soluble\tScaled_Solubility\tAntigenicity\tSusceptible_to_proteases" > header
    cat header .out.file > tmp; mv tmp "$outfolder"/"$outtag".tsv
    rm -rf header .out.file

    echo "[ W ::: Deciding promising peptides ]"
    awk '$5 == "NonHEMO" && $8 >= 0.45 && $9 == "-" && $10 == "-"' "$outfolder"/"$outtag".tsv > "$outfolder"/"$outtag".promising_subset.tsv
    if [ -s "$outfolder"/"$outtag".promising_subset.tsv ]
    then
        echo -e "Access\tSequence\tAMP_family\tAMP_probability\tHemolytic\tHemolytic_probability\tPercent_soluble\tScaled_Solubility\tAntigenicity\tSusceptible_to_proteases" > header
        cat header "$outfolder"/"$outtag".promising_subset.tsv > tmp; mv tmp "$outfolder"/"$outtag".promising_subset.tsv
        pigz --best "$outfolder"/"$outtag".promising_subset.tsv
        rm -rf tmp header
        nr=`zcat "$outfolder"/"$outtag".promising_subset.tsv | sed '1,1d' | awk '{print NR}' | tail -1`
        echo "[ W ::: Exists $nr promising AMP candidates saved as "$outfolder"/"$outtag".promising_subset.tsv.gz ]"
    else
        rm -rf "$outfolder"/"$outtag".promising_subset.tsv
        echo "[ W ::: No promising AMP candidates found ]"
    fi
else
    echo "[ W ::: Ending subloop ]"
fi
}
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
#################################### 6. Generating abundance profiles ######################################################

cleanmessy ()
{
echo "[ M ::: Formatting results ]"
tot=$(cat .all.nmb)
rm -rf .all.nmb

if [ "$(ls -A splits/)" ]
then
    cat splits/* > .out2.file
    rm -rf splits/
    sed -i 's/\"//g' .out2.file
    AMP=$(cat .out2.file | wc -l | awk '{print $1}')
    echo "[ M ::: Calculating statistics ]"
    pepval=$(awk '{print $3"_"$5}' .out2.file | sort | uniq -c | awk '{ print $2"\t"$1 }')
    echo "[ M ::: Exporting results ]"
    if [[ $ep == "0" ]]
    then
        echo -e "Access\tSequence\tAMP_family\tAMP_probability\tHemolytic\tHemolytic_probability" > header
        cat header .out2.file > "$outfolder"/"$outtag".tsv
        rm -rf header .out2.file
    elif [[ $ep == "1" ]]
    then
        EXTRADATA
    fi
    pigz --best "$outfolder"/"$outtag".tsv
else
        echo "[ W ::: ERR585 - We are sorry to inform. Your procedure did not return any AMP sequence. We are closing now ]"
        echo "[ W ::: We really tried. None of $tot called smORFs were assigned to a probability higher than 0.5 or survived until here ]"
    cd ../;
    rm -rf $tp
    exit 0
fi
}

loggen()
{
echo "[ M ::: Generating log ]"

if [[ $mode == "r" ]]
then
    ## Preparing report
    echo -e "######################################################## FACS report

[ M ::: Variables ]

Threads     $j
read_R1     $read_1
read_R2     $read_2
Folder      $outfolder
Tag         $outtag
Bucket      $block

========================================= Files were treated

*** Deduplicated ORFs were called

A total of $tot of smORFs were called.

These ORFs were then screened for AMPs.

*** $AMP peptides were called as potential AMPs

These peptides were classified into 4 families which accounts:

-- Distribution of peptides:

$pepval

** Legend: ADP     - Anionic Dissulphide-bond forming peptide
       ALP     - Anionic Linear peptide
       CDP     - Cationic Dissulphide-bond forming peptide
       CLP     - Cationic Linear peptide
       HEMO    - Hemolytic
       NonHEMO - Non-Hemolytic
########################################################" > "$outfolder"/.log
else
    ## Preparing report
    echo -e "######################################################## FACS report

[ M ::: Variables ]

Threads     $j
Contigs     $fasta
Folder      $outfolder
Tag         $outtag
Bucket      $block

========================================= Files were treated

*** Deduplicated ORFs were called

A total of $tot of smORFs were called.

These ORFs were then screened for AMPs.

*** $AMP peptides were called as potential AMPs

These peptides were classified into 4 families which accounts:

-- Distribution of peptides:

$pepval

** Legend: ADP     - Anionic Dissulphide-bond forming peptide
       ALP     - Anionic Linear peptide
       CDP     - Cationic Dissulphide-bond forming peptide
       CLP     - Cationic Linear peptide
       HEMO    - Hemolytic
       NonHEMO - Non-Hemolytic
########################################################" > "$outfolder"/.log
fi

sed -i 's/\"//g' "$outfolder"/.log

if [[ -n $log ]]
then
    cat "$outfolder"/.log
    mv "$outfolder"/.log "$outfolder"/"$log"
else
    cat "$outfolder"/.log
    rm -rf "$outfolder"/.log
fi

}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
###########################################      7. Abundances      ########################################################

mapping ()
{
echo "[ M ::: Indexing references ]"
if [[ "$RF" == "0" ]]
then
    pigz -dc "$reference" | sed '1,1d' | awk '{ print ">"$1"\n"$2 }' > .ref.fa
elif [[ "$RF" == "1" ]]
then
    if [[ "$fasta" =~ \.gz$ ]];
    then
        echo "[ M ::: Decompressing files ]"
        pigz -dc "$fasta" > .ref.fa
    else
        ln -s $fasta .ref.fa
    fi
else
    >&2 echo "[ W ::: ERR223 - FACS followed by a weird way ]"
fi

paladin index -r 3 .ref.fa

if [ -s .ref.fa.amb ]
then
    if [[ $mode == "mse" ]]
    then
        touch .ref.fa
    elif [[ $mode != "mpe" ]]
    then
        >&2 echo "[ W ::: ERR33 - Please review command line // INTERNAL ERROR SANITY CHECK FAIL ]"
        cd ../; rm -rf $tp/
        exit 1
    fi
else
    rm -rf .ref.fa*
    >&2 echo "[ W ::: ERR303 - Error in indexing ]"
    cd ../; rm -rf $tp/
    exit 1
fi

echo "[ M ::: Mapping reads against references, be aware it can take a while ]"

echo "[ M ::: Starting paladin ]"
paladin align -t "$j" -T 20 -f 10 -z 11 -a -V -M .ref.fa preproc.pair.1.fq.gz | samtools view -Sb | samtools sort > .m.bam

if [[ -s .m.bam ]]
then
    touch .m.bam
else
    >&2 echo "[ ERR052 - Mapping failed ]"
    cd ../; rm -rf $tp
    exit 1
fi
}


ab_profiling ()
{
echo "[ M ::: Expressing results of abundance ]"
express --no-bias-correct -o "$outfolder"/ .ref.fa .m.bam
if [[ -s "$outfolder"/results.xprs ]] || [[ -s "$outfolder"/params.xprs ]]
then
    mv "$outfolder"/results.xprs "$outfolder"/"$outtag".xprs
    mv "$outfolder"/params.xprs "$outfolder"/"$outtag".params.xprs
else
    echo "[ W ::: ERR054 - Abundance calling failed ]"
fi
rm -rf .ref.* preproc.*.fq.gz .m*
}


if [[ -d $Lib/envs/FACS_env/bin ]]
then
    export PATH=$Lib/envs/FACS_env/bin:$PATH
fi

sanity_check

if [[ $mode == "pe" || $mode == "se" ]]
then
    if [[ $mode == "pe" ]]
    then
        read_trimming "paired"
    else
        read_trimming "single"
    fi
    assemble
    callorf
    descriptors
    checkout
    predicter
    cleanmessy
    mode="r"
    loggen
elif [[ $mode == "pep" ]]
then
    if [[ "$fasta" =~ \.gz$ ]];
    then
        echo "[ M ::: Decompressing contigs ]"
        pigz -dc "$fasta" > .callorfinput.fa
    else
        ln -s $fasta .callorfinput.fa
    fi
    callorf
    descriptors
    checkout
    predicter
    cleanmessy
    loggen
elif [[ $mode == "c" ]]
then
    if [[ "$fasta" =~ \.gz$ ]];
    then
        echo "[ M ::: Decompressing contigs ]"
        pigz -dc "$fasta" > .callorfinput.fa
    else
        ln -s $fasta .callorfinput.fa
    fi
    callorf
    descriptors
    checkout
    predicter
    cleanmessy
    loggen
elif [[ $mode == "mse" || $mode == "mpe" ]]
then
    if [[ $mode == "mse" ]]
    then
        read_trimming "single"
    elif [[ $mode == "mpe" ]]
    then
        echo "[ W ::: NOTE _ IMPORTANT ]"
        echo "[ W ::: Abundance data is just inferred from R1 file ]"
        read_trimming "paired"
    fi
    mapping
    ab_profiling
else
    >&2 echo "[ W ::: ERR010 - The user needs to specify a valid FACS mode, please review the command line]"
    cd ../; rm -rf $tp/
    exit 1
fi
cd ../
rm -rf $tp/
date
