#!/bin/bash
#SBATCH --job-name=merge_bigwigs
#SBATCH --output=merge_bigwigs_%A_%a.out
#SBATCH --error=merge_bigwigs_%A_%a.err
#SBATCH --array=0-5 # change to the number of groups that you have
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=4:00:00
#SBATCH --partition=hpg-default
#SBATCH --account=cancercenter-dept
#SBATCH --qos=cancercenter-dept-b

# Load required modules
module purge
module load ucsc

# Set paths
BIGWIG_DIR="/blue/cancercenter-dept/privapps/data/atac/RM1/RM1_ATACSEQ_Manuscript/rm1_combined_human"
SAMPLE_INFO="/blue/cancercenter-dept/shared/RM1-mergedbigwigs-profile/RM1-CCI-HC-RAP-sampleinfo.csv"
OUTPUT_DIR="/blue/cancercenter-dept/shared/RM1-mergedbigwigs-profile/merged_bigwigs"
MERGED_SAMPLE_INFO="${OUTPUT_DIR}/merged-sample-info.csv"

# Create output directory
mkdir -p $OUTPUT_DIR

# Get chromosome sizes
CHROM_SIZES="/orange/cancercenter-dept/GENOMES/GENOMES/references/Homo_sapiens/UCSC/GRCh38/Annotation/hg38.chrom.sizes"

# Get array of unique groups and select the one for this task
GROUP_LIST=($(tail -n +2 $SAMPLE_INFO | cut -d',' -f2 | sort -u))
GROUP=${GROUP_LIST[$SLURM_ARRAY_TASK_ID]}

echo "Task $SLURM_ARRAY_TASK_ID processing group: $GROUP"

# Get color and sample_label for this group
COLOR=$(grep ",${GROUP}," $SAMPLE_INFO | head -1 | cut -d',' -f3)
LABEL=$(grep ",${GROUP}," $SAMPLE_INFO | head -1 | cut -d',' -f4)

# Get all samples for this group
SAMPLES=$(grep ",${GROUP}," $SAMPLE_INFO | cut -d',' -f1)

# Create array of bigwig files for this group
BIGWIG_LIST=()
for SAMPLE in $SAMPLES; do
    BIGWIG_FILE="${BIGWIG_DIR}/${SAMPLE}.mLb.clN.bigWig"
    if [[ -f $BIGWIG_FILE ]]; then
        BIGWIG_LIST+=("$BIGWIG_FILE")
        echo "  Found: $BIGWIG_FILE"
    else
        echo "  WARNING: Missing $BIGWIG_FILE"
        exit 1
    fi
done

# Merge bigwigs
MERGED_NAME="${GROUP}.merged"
BEDGRAPH="${OUTPUT_DIR}/${MERGED_NAME}.bedGraph"
MERGED_BIGWIG="${OUTPUT_DIR}/${MERGED_NAME}.bigWig"

echo "Merging ${#BIGWIG_LIST[@]} bigwigs..."
bigWigMerge "${BIGWIG_LIST[@]}" $BEDGRAPH

echo "Sorting bedGraph with ${SLURM_CPUS_PER_TASK} threads..."
sort -k1,1 -k2,2n --parallel=${SLURM_CPUS_PER_TASK} -S 24G $BEDGRAPH > ${BEDGRAPH}.sorted
mv ${BEDGRAPH}.sorted $BEDGRAPH

echo "Converting to bigWig..."
bedGraphToBigWig $BEDGRAPH $CHROM_SIZES $MERGED_BIGWIG

rm $BEDGRAPH

echo "Created: $MERGED_BIGWIG"

# Append to sample info file
echo "${MERGED_NAME},${GROUP},${COLOR},${LABEL}" >> $MERGED_SAMPLE_INFO

echo "Group $GROUP complete!"
