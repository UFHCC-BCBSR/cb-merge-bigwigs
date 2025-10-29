#!/bin/bash
#SBATCH --job-name=multibw_summary
#SBATCH --output=logs/multibw_summary_%j.out
#SBATCH --error=logs/multibw_summary_%j.err
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --partition=hpg-default
#SBATCH --account=cancercenter-dept
#SBATCH --qos=cancercenter-dept

# Load modules
module purge
module load deeptools

# Paths from your sbatch
BIGWIG_DIR="/blue/cancercenter-dept/privapps/data/atac/RM1/RM1_ATACSEQ_Manuscript/BAMS/median_dmel"
SAMPLE_INFO="/blue/cancercenter-dept/shared/RM1-mergedbigwigs-profile/RM1-CCI-HC-RAP-sampleinfo-spikein.csv"
OUTPUT_DIR="/blue/cancercenter-dept/shared/RM1-mergedbigwigs-profile"
TSS_BED="/blue/cancercenter-dept/hkates/github-clones/app-deeptools-plot/test-beds/hg38.genes.tss.bed"

# Output files
OUTPUT_NPZ="${OUTPUT_DIR}/tss_scores_individual.npz"
OUTPUT_TAB="${OUTPUT_DIR}/tss_scores_per_gene_individual.tab"

# Build bigwig array from sample info
BIGWIG_LIST=()
while IFS=',' read -r sample group color label; do
    BIGWIG_LIST+=("${BIGWIG_DIR}/${sample}.bw")
done < <(tail -n +2 $SAMPLE_INFO)

# Run multiBigwigSummary
multiBigwigSummary BED-file \
    -b "${BIGWIG_LIST[@]}" \
    -o $OUTPUT_NPZ \
    --outRawCounts $OUTPUT_TAB \
    --BED $TSS_BED \
    -p ${SLURM_CPUS_PER_TASK}

echo "Done! Output: $OUTPUT_TAB"
