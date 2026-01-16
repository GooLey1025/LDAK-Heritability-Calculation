nextflow.enable.dsl = 2

// Configurations
params.snp_vcf_path = 'raw_vcf/705rice.graph.0.5_0.05.snp.impute.biallelic.id.vcf'
params.indel_vcf_path = 'raw_vcf/705rice.graph.0.5_0.05.indel.impute.biallelic.id.vcf'
params.sv_vcf_path = 'raw_vcf/705rice.graph.0.5_0.05.sv.impute.biallelic.id.vcf'
params.phenotypes_dir = 'phenotypes/705rice'
params.outdir = '705rice_graph_0.5_0.05'
params.script_dir = file('scripts').toRealPath()
params.kinship_power = -.25
params.maf = 0.05
params.covar_path = "pca_calculate/705rice.snp.indel.graph.pca.eigenvec" // Optional: You can provide the covar file path, if not provided, no covariate will be used
params.window_prune = 0.98
params.covar_file = params.covar_path ? file(params.covar_path) : null


workflow {
    Channel.fromPath("${params.phenotypes_dir}/*.tsv").set { pheno_ch }
    Channel.of(
        tuple('SNP', file(params.snp_vcf_path)),
        tuple('INDEL', file(params.indel_vcf_path)),
        tuple('SV', file(params.sv_vcf_path))
    ).set {vcf_ch}

    prepare_vcf_for_ldak_ch = vcf_ch | prepare_vcf_for_ldak
    
    grm_kins_ch = prepare_vcf_for_ldak_ch | grm_kins

    grm_kins_ch.combine(pheno_ch) | reml_single
    
    // grm_kins_ch.collect().view { "$it" }

    grm_kins_ch.collect().map { lst ->
        // log.info "GRM KINS GROUP: ${lst}"

        def iSNP = lst.indexOf('SNP')
        def iINDEL = lst.indexOf('INDEL')
        def iSV = lst.indexOf('SV')

        def snp_files = lst[iSNP+1]
        def snp_prefix = lst[iSNP+2]
        def indel_files = lst[iINDEL+1]
        def indel_prefix = lst[iINDEL+2]
        def sv_files = lst[iSV+1]
        def sv_prefix = lst[iSV+2]

        tuple(snp_prefix, snp_files, indel_prefix, indel_files, sv_prefix, sv_files)
    }.set { mgrm_inputs_ch }

    mgrm_inputs_ch.combine(pheno_ch) | mgrm_calculation
    
    // Collect all reml files from reml_single and mgrm_calculation
    reml_single_ch = reml_single.out.her_file.map { type, reml_file -> reml_file }
    reml_mgrm_ch = mgrm_calculation.out.her_snp_indel.mix(mgrm_calculation.out.her_snp_indel_sv)
    all_reml_ch = reml_single_ch.mix(reml_mgrm_ch).collect()
    
    all_reml_ch | table_all_reml
}

process prepare_vcf_for_ldak {
    input:
        tuple val(type), file(vcf)
    output:
        tuple val(type), path("${vcf.baseName}.ldak.vcf")
    publishDir "${params.outdir}/prepare_vcf_for_ldak_vcf", mode: "link", pattern: '*.ldak.vcf'
    script:
    """
        bash ${params.script_dir}/vcf_recode_for_ldak.sh ${vcf} > ${vcf.baseName}.ldak.vcf
    """
}


process grm_kins {
    cpus 24
    publishDir "${params.outdir}/grm_kins", mode: "copy", pattern: '*.plink.ldak_thin.grm.*'
    tag "${type} (power: ${params.kinship_power}) maf: ${params.maf} window_prune: ${params.window_prune}"
    input:
        tuple val(type), path(vcf)
    output:
        tuple val(type), 
              path("${vcf.baseName}.plink.ldak_thin.grm.*"),
              val("${vcf.baseName}.plink.ldak_thin"), emit: grm_files

    script:
    """

        plink --vcf ${vcf} --double-id --make-bed --out ${vcf.baseName}.plink --allow-extra-chr --allow-no-sex --maf ${params.maf}
        ldak --thin ${vcf.baseName}.plink.ldak_thin.thin --bfile ${vcf.baseName}.plink --window-prune ${params.window_prune} --window-kb 100 --max-threads ${task.cpus}
        awk '{print \$1, 1}' ${vcf.baseName}.plink.ldak_thin.thin.in > ${vcf.baseName}.plink.ldak_thin.weights
        ldak --bfile ${vcf.baseName}.plink --calc-kins-direct ${vcf.baseName}.plink.ldak_thin --weights ${vcf.baseName}.plink.ldak_thin.weights --power ${params.kinship_power} --max-threads ${task.cpus}
    """
}

process reml_single {
    cpus 4
    publishDir "${params.outdir}/single_heritability", mode: "copy", pattern: '*.reml'
    input:
        tuple val(type), path(grm_files), val(prefix), path(phenotype)

    output:
        tuple val(type), path("${phenotype.baseName}.${type}.reml"), emit: her_file
    script:
    def covar_option = params.covar_file ? "--covar ${params.covar_file}" : ""
    """
        ldak --reml ${phenotype.baseName}.${type} --grm ${prefix} --pheno ${phenotype} --constrain YES ${covar_option} --max-threads ${task.cpus}
    """

}

process mgrm_calculation {
    publishDir "${params.outdir}/fuse_heritability", mode: "copy", pattern: '*.reml'

    cpus 4
    input:
        tuple val(snp_prefix),   path(snp_grm_files),
              val(indel_prefix), path(indel_grm_files),
              val(sv_prefix),    path(sv_grm_files),
              path(phenotype)

    output:
        path("*.SNP_INDEL.reml"),       emit: her_snp_indel
        path("*.SNP_INDEL_SV.reml"),    emit: her_snp_indel_sv

    script:
    def covar_option = params.covar_file ? "--covar ${params.covar_file}" : ""
    """
        printf '%s\n%s\n' "${snp_prefix}" "${indel_prefix}" > ${phenotype.baseName}_SNP_INDEL.grm.list
        printf '%s\n%s\n%s\n' "${snp_prefix}" "${indel_prefix}" "${sv_prefix}" > ${phenotype.baseName}_SNP_INDEL_SV.grm.list

        ldak --reml ${phenotype.baseName}.SNP_INDEL \
             --mgrm ${phenotype.baseName}_SNP_INDEL.grm.list \
             --pheno ${phenotype} \
             --constrain YES \
             ${covar_option} \
             --max-threads ${task.cpus}

        ldak --reml ${phenotype.baseName}.SNP_INDEL_SV \
             --mgrm ${phenotype.baseName}_SNP_INDEL_SV.grm.list \
             --pheno ${phenotype} \
             --constrain YES \
             ${covar_option} \
             --max-threads ${task.cpus}
    """
}

process table_all_reml {
    publishDir "${params.outdir}/heritability_summary", mode: "copy", pattern: '*.xlsx'
    
    input:
        path reml_files
    
    output:
        path("heritability_summary.xlsx"), emit: summary_file
    
    script:
    """
    # Find and copy all reml files to current directory
    
    python3 ${params.script_dir}/table_all_reml.py --pattern "*.reml" -o heritability_summary.xlsx
    """
}
