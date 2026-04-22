process MS2RESCORE_GETMODEL {
    tag "${ms2pip_model}"
    label 'process_single'

    publishDir path: { "${params.outdir}/ms2rescore" }, mode: params.publish_dir_mode

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/ms2rescore:3.2.1--pyhdfd78af_0'
        : 'biocontainers/ms2rescore:3.2.1--pyhdfd78af_0'}"

    input:
    val ms2pip_model

    output:
    path ('ms2pip_model'), emit: model_dir

    tuple val("${task.process}"), val('ms2rescore'), eval('ms2rescore --version | tail -1'), topic: versions, emit: versions_ms2rescore
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), topic: versions, emit: versions_python

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    cat << 'PY' > get_ms2pip_model.py
from ms2pip.constants import MODELS
from ms2pip._utils.xgb_models import validate_requested_xgb_model

ms2pip_model = "${ms2pip_model}"
model_dir = "./ms2pip_model"

# Validate / download requested model
if ms2pip_model in MODELS.keys():
    print(f"Checking {ms2pip_model} model")
    if "xgboost_model_files" in MODELS[ms2pip_model].keys():
        validate_requested_xgb_model(
            MODELS[ms2pip_model]["xgboost_model_files"],
            MODELS[ms2pip_model]["model_hash"],
            model_dir,
        )
PY

    python ${args} get_ms2pip_model.py
    """

    stub:
    def args = task.ext.args ?: ''
    """
    echo ${args}

    mkdir -p ms2pip_model
    touch ms2pip_model/STUB_MODEL
    """
}
