/*
 * Runs sage search engine
 * The modules inputs/ouptus are intentionally designed to match the [existing Sage module](https://nf-co.re/modules/sageproteomics_sage/).
 * Once the existing one is updated it can be droped in place of thie local one.
 **/
process SAGEBETA {
    tag "${meta.id}"
    label 'process_high_memory'

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'medbioinf/sage:v0.15.0-beta.1'
        : 'medbioinf/sage:v0.15.0-beta.1'}"

    input:
    tuple val(meta), path(mzml)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(config)

    output:
    tuple val(meta), path("*.results.sage.tsv"), emit: tsv
    tuple val(meta), path("*.results.sage.pin"), emit: pin, optional: true
    tuple val(meta), path("*.results.json"), emit: json, optional: true
    tuple val(meta), path("*.tmt.tsv"), emit: tmt_tsv, optional: true
    tuple val(meta), path("*.lfq.tsv"), emit: lfq_tsv, optional: true
    tuple val("${task.process}"), val('sage'), eval("sage --version"), topic: versions, emit: versions_sagebeta

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    RAYON_NUM_THREADS=${task.cpus.intValue()} sage -f ${fasta} --batch-size ${task.cpus.intValue()} --write-pin --output_directory ./ ${args} ${config} ${mzml}

    for file in results.sage.tsv results.sage.pin results.json tmt.tsv lfq.tsv; do
        if [ -f "\$file" ]; then
            mv \$file "${prefix}.\${file}"
        fi
    done
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}

    touch ${prefix}.results.sage.tsv
    touch ${prefix}.results.sage.pin
    touch ${prefix}.results.json
    touch ${prefix}.tmt.tsv
    touch ${prefix}.lfq.tsv
    """
}
