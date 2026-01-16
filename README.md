# Overview
This repository provides a [Nextflow (DSL2)](https://nextflow.io) workflow for estimating heritability of complex traits using SNPs, INDELs, and structural variants (SVs) based on [LDAK](https://github.com/dougspeed/LDAK).
The pipeline supports single-variant-type and multi-GRM (MGRM) REML analyses across multiple phenotypes, enabling systematic partitioning of genetic variance with support for user-provided covariate files (e.g PCA from `plink2`).

## Requirments
The following software must be installed and available in the **system environment ($PATH)** before running the pipeline:
- nextflow
- ldak
- plink 
- bcftools
- python3

**Note**: The executable names are case-sensitive and must exactly match those listed above.

## Quick Start
```sh
nextflow run main.nf --snp_vcf_path test.snp.impute_biallelic_id.vcf \
    --indel_vcf_path test.indel.impute_biallelic_id.vcf \
    --sv_vcf_path test.sv.impute_biallelic_id.vcf \
    --phenotypes_dir phenotypes/705rice/ \
    --outdir test_output
```
You will see the final formatted result at `test_output/heritability_summary/heritability_summary.xlsx`.

## Configuration

All parameters can be provided either via the command line or a Nextflow configuration file.

### Input Parameters

| Parameter | Description | Required/Default |
|----------|------------|----------|
| `--snp_vcf_path` | Path to the SNP VCF file | Yes |
| `--indel_vcf_path` | Path to the INDEL VCF file | Yes |
| `--sv_vcf_path` | Path to the SV VCF file | Yes |
| `--phenotypes_dir` | Directory containing phenotype `.tsv` files | Yes |
| `--covar_path` | Covariate file (e.g. PCA eigenvectors) | No |
| `--maf` | Minor allele frequency threshold used in PLINK | `0.05` |
| `--kinship_power` | LDAK kinship power parameter | `-0.25` |
| `--window_prune` | LD pruning threshold for LDAK thinning | `0.98` |
| `--outdir` | Output directory for all results | `results/` |

### VCF Preprocessing
This pipeline requires input VCF files to be preprocessed before analysis.
Specifically, all VCFs must be **biallelic** and **have variant IDs assigned according to variant type**.

You could follow the procedure below:
```sh
VAR=SNP # or INDEL; or SV
bcftools norm -m -any $VAR.raw.vcf > $VAR.biallelic.vcf
bash scripts/assign_ID.sh $VAR $VAR.biallelic.vcf > $VAR.biallelic.id.vcf
```
Variant IDs are assigned in the format:`VAR-chromosome-position-Number`,
where Number is incremented for multiple alleles at the same site.

### Phenotypes Preprocessing
Phenotype files in the `--phenotypes_dir` dir need to be preprocessed in advance. For example, a phenotype file such as `FGP_WenJ15.tsv` should look like:
```
FID     IID     FGP_WenJ15
1701    1701    128.60
1702    1702    92.70
1703    1703    97.10
1704    1704    103.80
1705    1705    76.80
1706    1706    107.60
1707    1707    114.20
Y10     Y10     53.10
Y104    Y104    NA
```
Please preprocess all phenotype files accordingly. In general, make sure they follow the rules below:
1. The first two header columns must be `FID` and `IID`. The third column should be the phenotype name.
2. Missing values must be coded as NA, not -9. Unlike `plink`, `ldak` does not support `-9` 

### Example: Covariate (PCA) calculation (Optional)
Covariates (e.g. PCA) can be generated from merged SNP and INDEL VCFs after VCF preprocessing.
```sh
cd pca_culate
P=705rice
MODE=biallelic.id
bgzip -@ 24 ../$P/$MODE/$P.snp.$MODE.vcf -c  > $P.snp.$MODE.vcf.gz
bcftools index --threads 24 $P.snp.$MODE.vcf.gz
bgzip -@ 24 ../$P/$MODE/$P.indel.$MODE.vcf -c  > $P.indel.$MODE.vcf.gz
bcftools index --threads 24 $P.indel.$MODE.vcf.gz
bcftools concat --threads 24 -a $P.snp.$MODE.vcf.gz $P.indel.$MODE.vcf.gz -Oz -o $P.snp.indel.$MODE.vcf.gz

plink2 --vcf $P.snp.indel.$MODE.vcf.gz --double-id --make-pgen --maf 0.05 --out $P.snp.indel --threads 24
plink2 --pfile $P.snp.indel --pca 5 --out $P.snp.indel.graph.pca5 --threads 24
```

