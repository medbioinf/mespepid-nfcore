process MS2RESCORE_RUNMS2RESCORE {
    tag "$meta.id"

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/ms2rescore:3.2.1--pyhdfd78af_0'
        : 'biocontainers/ms2rescore:3.2.1--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(mzml), path(raw_spectra), path(psms_file)
    path model_dir

    output:
    tuple val(meta), path("*.pin"), emit: pin
    tuple val("${task.process}"), val('ms2rescore'), eval('ms2rescore --version | tail -1'), topic: versions, emit: versions_ms2rescore
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), topic: versions, emit: versions_python

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // use mzML if given, otherwise use raw spectra
    def spectra_file = mzml ?: raw_spectra
    def ms2pip_model = meta.ms2pip_model ?: 'HCD'
    def spectrum_id_pattern = meta.spectrum_id_pattern ?: '.*scan=(\\d+)$'
    def fragment_tol_da = meta.fragment_tol_da ?: 0.02
    """
    ms2rescore_run_chunked.py \\
        ${args} \\
        -psms_file ${psms_file} \\
        -spectra ${spectra_file} \\
        -model ${ms2pip_model} \\
        -model_dir ${model_dir} \\
        -ms2_tolerance ${fragment_tol_da} \\
        -spectrum_id_pattern '${spectrum_id_pattern}' \\
        -processes ${task.cpus} \\
        -out_file ${prefix}.pin
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}

    touch ${prefix}.pin
    """
}
