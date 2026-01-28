/*
 * Peptide identification using MSAmanda search engine
 */

include { MSAMANDA_SEARCH } from '../../../modules/local/msamandasearch/main.nf'

workflow MSAMANDA_IDENTIFICATION {

    take:
    ch_mzml              // channel: tuple val(meta), path(mzml)
    ch_fasta             // channel: path(fasta)
    ch_msamanda_params   // channel: path(msamanda_params)
    precursor_tol_ppm    // val: precursor mass tolerance in ppm
    fragment_tol_da      // val: fragment mass tolerance in Da

    main:
    ch_versions = channel.empty()

    // Combine mzML files with fasta and params for MSAmanda search
    ch_mzml
        .combine(ch_fasta)
        .combine(ch_msamanda_params)
        .set { ch_msamanda_input }

    // Run MSAmanda peptide identification
    MSAMANDA_SEARCH(
        ch_msamanda_input,
        precursor_tol_ppm,
        fragment_tol_da
    )
    ch_versions = ch_versions.mix(MSAMANDA_SEARCH.out.versions)

    emit:
    csv      = MSAMANDA_SEARCH.out.csv         // channel: tuple val(meta), path(*.csv)
    versions = ch_versions                    // channel: path(versions.yml)
}
