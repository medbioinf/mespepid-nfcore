process OKTOBERFEST_RUNOKTOBERFEST {
    tag "$meta.id"

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://quay.io/medbioinf/oktoberfest:0.11.1-dev-90a95c7':
        'quay.io/medbioinf/oktoberfest:0.11.1-dev-90a95c7' }"

    input:
    tuple val(meta), path(mzml), path(raw_spectra), path(psms_file)

    output:
    tuple val(meta), path("${prefix}.pin"), emit: pin
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    // Regular expression pattern to extract the scan number from the spectrum ID. Use `scan_id` for the matching group, e.g. `scan=(?P<scan_id>\\d+)`)
    scan_id_pattern = meta.scan_id_pattern ?: '^(?P<scan_id>\\d+)$'
    // use mzML if given, otherwise use raw spectra
    spectra_file = mzml ?: raw_spectra
    // internal output folder for oktoberfest results
    out_folder = meta.out_folder ?: "./oktoberfest_out"
    // the mass tolerance, basically fragment mass tolerance
    mass_tolerance = meta.mass_tolerance ?: 0.02
    // the unit can be either da or ppm
    mass_tolerance_unit = meta.mass_tolerance_unit ?: "da"
    // the irt model provided by Koina
    irt_model = meta.oktoberfest_irt_model ?: "Prosit_2019_irt"
    // the intensity_model model provided by Koina
    intensity_model = meta.oktoberfest_intensity_model ?: "Prosit_2020_intensity_HCD"
    // the used prediction server (e.g. koina.wilhelmlab.org:443 or koina.bi.denbi.de:443)
    // override via ext.prediction_server in conf/modules.config
    prediction_server = task.ext.prediction_server ?: "koina.wilhelmlab.org:443"
    template 'oktoberfest_feature_gen.py'

    stub:
    """
    touch ${prefix}.pin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | cut -d ' ' -f 2)
        oktoberfest: \$(python -c "import oktoberfest; print(oktoberfest.__version__)")
    END_VERSIONS
    """
}
