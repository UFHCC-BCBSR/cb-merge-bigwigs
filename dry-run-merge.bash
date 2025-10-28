#!/bin/bash

# Set paths
BIGWIG_DIR="/blue/cancercenter-dept/privapps/data/atac/RM1/RM1_ATACSEQ_Manuscript/rm1_combined_human"
SAMPLE_INFO="/blue/cancercenter-dept/shared/RM1-mergedbigwigs-profile/RM1-CCI-HC-RAP-sampleinfo.csv"
OUTPUT_DIR="/blue/cancercenter-dept/shared/RM1-mergedbigwigs-profile/merged_bigwigs"
MERGED_SAMPLE_INFO="${OUTPUT_DIR}/merged-sample-info.csv"
CHROM_SIZES="/orange/cancercenter-dept/GENOMES/GENOMES/references/Homo_sapiens/UCSC/GRCh38/Annotation/hg38.chrom.sizes"

echo "=========================================="
echo "DRY RUN - BigWig Merge Preview"
echo "=========================================="
echo ""
echo "Sample info file: $SAMPLE_INFO"
echo "BigWig directory: $BIGWIG_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Chrom sizes file: $CHROM_SIZES"
echo ""

# Check if sample info exists
if [[ ! -f $SAMPLE_INFO ]]; then
    echo "ERROR: Sample info file not found: $SAMPLE_INFO"
    exit 1
fi

# Check if chrom sizes exists
if [[ ! -f $CHROM_SIZES ]]; then
    echo "WARNING: Chromosome sizes file not found: $CHROM_SIZES"
    echo ""
fi

# Get unique groups from sample-info.csv - CHANGED VARIABLE NAME
GROUP_LIST=$(tail -n +2 $SAMPLE_INFO | cut -d',' -f2 | sort -u)

echo "Found $(echo $GROUP_LIST | wc -w) unique groups:"
for GROUP in $GROUP_LIST; do
    echo "  - $GROUP"
done
echo ""

echo "=========================================="
echo "Merge Plan by Group"
echo "=========================================="
echo ""

# Process each group
TOTAL_FOUND=0
TOTAL_MISSING=0

for GROUP in $GROUP_LIST; do
    echo "----------------------------------------"
    echo "GROUP: $GROUP"
    echo "----------------------------------------"
    
    # Get color and sample_label for this group
    COLOR=$(grep ",${GROUP}," $SAMPLE_INFO | head -1 | cut -d',' -f3)
    LABEL=$(grep ",${GROUP}," $SAMPLE_INFO | head -1 | cut -d',' -f4)
    
    echo "  Color: $COLOR"
    echo "  Label: $LABEL"
    echo ""
    
    # Get all samples for this group
    SAMPLES=$(grep ",${GROUP}," $SAMPLE_INFO | cut -d',' -f1)
    
    # Count samples and files
    SAMPLE_COUNT=$(echo "$SAMPLES" | wc -l)
    echo "  Samples in group: $SAMPLE_COUNT"
    echo ""
    
    # Check for bigwig files
    FOUND_COUNT=0
    MISSING_COUNT=0
    
    echo "  Input BigWig files:"
    for SAMPLE in $SAMPLES; do
        BIGWIG_FILE="${BIGWIG_DIR}/${SAMPLE}.mLb.clN.bigWig"
        if [[ -f $BIGWIG_FILE ]]; then
            echo "    ✓ $BIGWIG_FILE"
            ((FOUND_COUNT++))
        else
            echo "    ✗ MISSING: $BIGWIG_FILE"
            ((MISSING_COUNT++))
        fi
    done
    
    TOTAL_FOUND=$((TOTAL_FOUND + FOUND_COUNT))
    TOTAL_MISSING=$((TOTAL_MISSING + MISSING_COUNT))
    
    echo ""
    echo "  Files found: $FOUND_COUNT"
    echo "  Files missing: $MISSING_COUNT"
    echo ""
    
    # Show output filenames
    MERGED_NAME="${GROUP}.merged"
    MERGED_BIGWIG="${OUTPUT_DIR}/${MERGED_NAME}.bigWig"
    
    echo "  Output file:"
    echo "    → $MERGED_BIGWIG"
    echo ""
    
    # Show sample info entry
    echo "  Sample info entry:"
    echo "    ${MERGED_NAME},${GROUP},${COLOR},${LABEL}"
    echo ""
done

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "New sample info file will be created at:"
echo "  $MERGED_SAMPLE_INFO"
echo ""
echo "Expected contents:"
echo "  sample,group,color,sample_label"
for GROUP in $GROUP_LIST; do
    COLOR=$(grep ",${GROUP}," $SAMPLE_INFO | head -1 | cut -d',' -f3)
    LABEL=$(grep ",${GROUP}," $SAMPLE_INFO | head -1 | cut -d',' -f4)
    MERGED_NAME="${GROUP}.merged"
    echo "  ${MERGED_NAME},${GROUP},${COLOR},${LABEL}"
done
echo ""
echo "Total BigWig files found: $TOTAL_FOUND"
echo "Total BigWig files missing: $TOTAL_MISSING"
echo ""

if [[ $TOTAL_MISSING -gt 0 ]]; then
    echo "⚠️  WARNING: Some files are missing!"
    echo "   Please verify file paths before running the merge."
else
    echo "✓ All files found! Ready to merge."
fi
echo ""
echo "=========================================="
