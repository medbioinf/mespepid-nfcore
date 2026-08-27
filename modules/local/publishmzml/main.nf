/*
 * Pass-through process to publish only the final, prepared mzML files from
 * PREPARE_SPECTRA, after any processing.
 * The intermediate per-step outputs have publishDir disabled by default,
 * so only this final result ends up under outdir/mzmls.
 **/
process PUBLISHMZML {
    tag "${meta.id}"
    label 'process_single'

    input:
    tuple val(meta), path(mzml)

    output:
    tuple val(meta), path(mzml), emit: mzml

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """

    stub:
    """
    """
}
