#!/bin/bash
#SBATCH --job-name=merge_bigwigs_spikein
#SBATCH --output=logs/merge_bigwigs_spikein_%A_%a.out
#SBATCH --error=logs/merge_bigwigs_spikein_%A_%a.err
#SBATCH --array=0-5
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --time=08:00:00
#SBATCH --partition=hpg-default
#SBATCH --account=cancercenter-dept
#SBATCH --qos=cancercenter-dept-b

# Load required modules
module purge
module load ucsc

# Set paths
BIGWIG_DIR="/blue/cancercenter-dept/privapps/data/atac/RM1/RM1_ATACSEQ_Manuscript/BAMS/median_dmel"
SAMPLE_INFO="/blue/cancercenter-dept/shared/RM1-mergedbigwigs-profile/RM1-CCI-HC-RAP-sampleinfo-spikein.csv"
OUTPUT_DIR="/blue/cancercenter-dept/shared/RM1-mergedbigwigs-profile/output/merged-bigwigs-spikein"
MERGED_SAMPLE_INFO="${OUTPUT_DIR}/merged-sample-info.csv"
CHROM_SIZES="/orange/cancercenter-dept/GENOMES/GENOMES/references/Homo_sapiens/UCSC/GRCh38/Annotation/hg38.chrom.sizes"

# Create output directory
mkdir -p $OUTPUT_DIR

# Use blue storage for temp instead of default /tmp
TMPDIR="${OUTPUT_DIR}/temp_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
mkdir -p $TMPDIR
trap "rm -rf $TMPDIR" EXIT

echo "Using temp directory: $TMPDIR"

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
    BIGWIG_FILE="${BIGWIG_DIR}/${SAMPLE}.bw"
    if [[ -f $BIGWIG_FILE ]]; then
        BIGWIG_LIST+=("$BIGWIG_FILE")
        echo "  Found: $SAMPLE"
    else
        echo "  WARNING: Missing $BIGWIG_FILE"
        exit 1
    fi
done

# Merge bigwigs
MERGED_NAME="${GROUP}.merged"
BEDGRAPH="${TMPDIR}/${MERGED_NAME}.bedGraph"
MERGED_BIGWIG="${OUTPUT_DIR}/${MERGED_NAME}.bigWig"

echo "Merging ${#BIGWIG_LIST[@]} bigwigs..."
bigWigMerge "${BIGWIG_LIST[@]}" $BEDGRAPH

echo "Sorting bedGraph with ${SLURM_CPUS_PER_TASK} threads..."
sort -k1,1 -k2,2n \
    --parallel=${SLURM_CPUS_PER_TASK} \
    -S 100G \
    -T $TMPDIR \
    $BEDGRAPH > ${BEDGRAPH}.sorted

mv ${BEDGRAPH}.sorted $BEDGRAPH

echo "Filtering out chrEBV..."
grep -v "^chrEBV" $BEDGRAPH | \
  awk '{if ($1 ~ /^chr[0-9]+$/ || $1 == "chrX" || $1 == "chrY" || $1 == "chrM") print}' > ${BEDGRAPH}.filtered


echo "Converting to bigWig..."
bedGraphToBigWig ${BEDGRAPH}.filtered $CHROM_SIZES $MERGED_BIGWIG

echo ""
echo "========================================"
echo "SUCCESS!"
echo "Created: $MERGED_BIGWIG"
ls -lh $MERGED_BIGWIG
bigWigInfo $MERGED_BIGWIG
echo "========================================"

# Append to sample info file
echo "${MERGED_NAME},${GROUP},${COLOR},${LABEL}" >> $MERGED_SAMPLE_INFO

echo "Group $GROUP complete!"
