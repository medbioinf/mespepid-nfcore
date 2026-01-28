/*
 * Peptide identification using MSFragger search engine
 */

include { MSFRAGGER_ADJUST_PARAMS } from '../../../modules/local/msfraggeradjustparams/main.nf'
include { MSFRAGGER_SEARCH         } from '../../../modules/local/msfraggersearch/main.nf'

workflow MSFRAGGER_IDENTIFICATION {

    take:
    ch_mzml              // channel: tuple val(meta), path(mzml)
    ch_fasta             // channel: path(fasta)
    ch_msfragger_params  // channel: path(msfragger_params)
    precursor_tol_ppm    // val: precursor mass tolerance in ppm
    fragment_tol_da      // val: fragment mass tolerance in Da

    main:
    ch_versions = Channel.empty()

    // Create a meta map for the params file and adjust parameters
    ch_msfragger_params
        .map { params_file -> [ [id: 'msfragger_params'], params_file ] }
        .set { ch_params_with_meta }

    MSFRAGGER_ADJUST_PARAMS(
        ch_params_with_meta,
        ch_fasta,
        precursor_tol_ppm,
        fragment_tol_da
    )
    ch_versions = ch_versions.mix(MSFRAGGER_ADJUST_PARAMS.out.versions)

    // Extract adjusted params without meta for combining with mzML files
    MSFRAGGER_ADJUST_PARAMS.out.params
        .map { meta, params -> params }
        .set { ch_adjusted_params }

    // Combine mzML files with fasta and adjusted params for MSFragger search
    ch_mzml
        .combine(ch_fasta)
        .combine(ch_adjusted_params)
        .set { ch_msfragger_input }

    // Run MSFragger peptide identification
    MSFRAGGER_SEARCH(
        ch_msfragger_input
    )
    ch_versions = ch_versions.mix(MSFRAGGER_SEARCH.out.versions)

    emit:
    pepxml   = MSFRAGGER_SEARCH.out.pepxml     // channel: tuple val(meta), path(*.pepXML)
    versions = ch_versions                     // channel: path(versions.yml)
}
