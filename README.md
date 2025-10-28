# RM1Merged BigWigs for Deeptools Profile Plots

This repository contains scripts for merging ATAC-seq bigWig files by biological condition to prepare aggregate signal tracks for visualization with deeptools (`computeMatrix` and `plotProfile`/`plotHeatmap`).

## Overview

Individual ATAC-seq samples are merged by experimental group as defined in a sampleinfo.csv to create single bigWig files representing the combined signal for each condition. This simplifies downstream visualization and makes it easier to compare chromatin accessibility patterns across conditions.

### Input Data
- **path/to/Individual-bigWigs**
- **Sample metadata**: `sample-info.csv` maps individual samples to groups with color/label info (used in downstream steps)

### Output
Merged bigWig files in $OUTPUT_DIR, one per condition, ready for deeptools.

## Repository Structure

```
├── RM1-CCI-HC-RAP-sampleinfo.csv          # Sample-to-group mapping with visualization metadata
├── merge-bigwigs.sbatch                    # Main SLURM script for merging (standard norm)
├── dry-run-merge.bash                      # Test script (prints what would be merged)
```

## Usage

### 1. Run the dry-run to check what will be merged and edit if needed

```bash
bash dry-run-merge.bash
```

### 1. Submit the array job on hipergator
```bash
sbatch merge-bigwigs.sbatch
```

This will:
- Process all groups in parallel using SLURM array jobs
- Merge individual sample bigWigs by group
- Filter out problematic chromosomes (chrEBV)
- Create output in `$OUTPUT_DIR`

## Sample Info Format

`RM1-CCI-HC-RAP-sampleinfo.csv`:
```csv
sample_name,group,color,label
RM1-CCI-1,CCI_d4,red,CCI Day 4
RM1-CCI-2,CCI_d4,red,CCI Day 4
RM1-HC-1,HC_d4,blue,HC Day 4
...
```

- **sample_name**: Base name of individual bigWig file
- **group**: Condition identifier (used for merging)
- **color**: Suggested color for plotting
- **label**: Human-readable label for figures

## Resource Requirements

Each array task uses:
- **CPUs**: 16 threads (for parallel sorting)
- **Memory**: 120G
- **Time**: 4 hours
- **Storage**: Temporary files use blue storage (`/blue`) to avoid `/tmp` quota issues

## Troubleshooting

If individual array tasks fail:
1. Check logs in `logs/` directory
2. Identify problematic group from SLURM_ARRAY_TASK_ID
3. Resubmit specific array task: `sbatch --array=X merge-bigwigs.sbatch`

Common issues:
- **Missing files**: Check that all samples in CSV exist in bigWig directory
- **Memory errors**: Large groups may need increased `--mem`
- **chrEBV errors**: Script automatically filters this chromosome

## Output for Deeptools

Use merged bigWigs with deeptools:

```bash
computeMatrix reference-point 
  --referencePoint TSS 
  -b 3000 -a 3000 
  -R genes.bed 
  -S merged_bigwigs/CCI_d4.merged.bigWig 
     merged_bigwigs/HC_d4.merged.bigWig 
  -o matrix.gz

plotProfile -m matrix.gz -o profile.pdf
```

