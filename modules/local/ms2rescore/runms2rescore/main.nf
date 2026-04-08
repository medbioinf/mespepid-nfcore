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
    tuple val(meta), path("${out_file}"), emit: pin
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    out_file = "${prefix}.pin"
    // use mzML if given, otherwise use raw spectra
    spectra_file = mzml ?: raw_spectra
    ms2pip_model = meta.ms2pip_model ?: 'HCD'
    spectrum_id_pattern = meta.spectrum_id_pattern ?: '.*scan=(\\d+)$'
    fragment_tol_da = meta.fragment_tol_da ?: 0.02
    chunk_size = task.ext.chunk_size ?: 100000
    template 'ms2rescore_run_chunked.py'

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}

    touch ${prefix}.pin
    """
}
