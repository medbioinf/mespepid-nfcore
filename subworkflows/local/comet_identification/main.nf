/*
 * Peptide identification using Comet search engine
 */

include { COMET_ADJUST_PARAMS } from '../../../modules/local/cometadjustparams/main.nf'
include { COMET_SEARCH        } from '../../../modules/local/cometsearch/main.nf'

workflow COMET_IDENTIFICATION {

    take:
    ch_mzml              // channel: tuple val(meta), path(mzml)
    ch_fasta             // channel: tuple val(meta), path(fasta)
    ch_comet_params      // channel: tuple val(meta), path(params)
    precursor_tol_ppm    // val: precursor mass tolerance in ppm
    fragment_tol_da      // val: fragment mass tolerance in Da

    main:
    ch_versions = channel.empty()

    // Adjust Comet parameter file with tolerances
    COMET_ADJUST_PARAMS(
        ch_comet_params,
        precursor_tol_ppm,
        fragment_tol_da
    )
    ch_versions = ch_versions.mix(COMET_ADJUST_PARAMS.out.versions)

    // Combine mzML files with fasta and adjusted params for Comet search
    // Assuming each mzML should be searched against the same fasta with the same params
    ch_mzml
        .combine(ch_fasta.map { meta, fasta -> fasta })
        .combine(COMET_ADJUST_PARAMS.out.params.map { meta, params -> params })
        .set { ch_comet_input }

    // Run Comet peptide identification
    COMET_SEARCH(ch_comet_input)
    ch_versions = ch_versions.mix(COMET_SEARCH.out.versions)

    emit:
    mzid     = COMET_SEARCH.out.mzid          // channel: tuple val(meta), path(*.mzid)
    versions = ch_versions                    // channel: path(versions.yml)
}
