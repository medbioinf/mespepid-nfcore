process OKTOBERFEST_GENERATEFEATURES {
    tag "$meta.id"
    label 'process_high'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://quay.io/medbioinf/oktoberfest:0.11-dev':
        'quay.io/medbioinf/oktoberfest:0.11-dev' }"

    input:
    tuple val(meta), path(mzml), path(raw_spectra), path(psms_file)

    output:
    tuple val(meta), path("${out_file}"), emit: pin
    path "versions.yml", emit: versions

    // TODO nf-core: Named file extensions MUST be emitted for ALL output channels
    tuple val(meta), path("*.bam"), emit: bam
    // TODO nf-core: List additional required output channels/values here
    // TODO nf-core: Update the command here to obtain the version number of the software used in this module
    // TODO nf-core: If multiple software packages are used in this module, all MUST be added here
    //               by copying the line below and replacing the current tool with the extra tool(s)
    tuple val("${task.process}"), val('oktoberfest'), eval("oktoberfest --version"), topic: versions, emit: versions_oktoberfest

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    out_file = "${prefix}.features.tsv"
    // use mzML if given, otherwise use raw spectra
    spectra_file = mzml ?: raw_spectra
    ms2pip_model = meta.ms2pip_model ?: 'HCD'
    spectrum_id_pattern = meta.spectrum_id_pattern ?: '.*scan=(\\d+)$'
    fragment_tol_da = meta.fragment_tol_da ?: 0.02
    chunk_size = task.ext.chunk_size ?: 100000
    template 'oktoberfest_feature_gen.py'

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | cut -d ' ' -f 2)
        oktoberfest: \$(python -c "import oktoberfest; print(oktoberfest.__version__)")
    END_VERSIONS
    """
}
