/*
 * Peptide identification using MaxQuant search engine
 */

include { MAXQUANT_ADJUST_PARAMS } from '../../../modules/local/maxquantadjustparams/main.nf'
include { MAXQUANT_SEARCH        } from '../../../modules/local/maxquantsearch/main.nf'

workflow MAXQUANT_IDENTIFICATION {

    take:
    ch_spectra           // channel: tuple val(meta), path(spectra_file) - .d or .raw files with meta.ext
    ch_fasta             // channel: tuple val(meta), path(fasta)
    ch_maxquant_params   // channel: tuple val(meta), path(params)
    precursor_tol_ppm    // val: precursor mass tolerance in ppm

    main:
    ch_versions = channel.empty()

    // Combine spectra files with fasta and params for MaxQuant parameter adjustment
    ch_spectra
        .combine(ch_fasta.map { _meta, fasta -> fasta })
        .combine(ch_maxquant_params.map { _meta, params -> params })
        .set { ch_maxquant_input }

    // Adjust MaxQuant parameter file with tolerances and file paths
    MAXQUANT_ADJUST_PARAMS(
        ch_maxquant_input,
        precursor_tol_ppm
    )
    ch_versions = ch_versions.mix(MAXQUANT_ADJUST_PARAMS.out.versions)

    // Extract spectra_file and params for search (drop fasta)
    MAXQUANT_ADJUST_PARAMS.out.params
        .map { meta, spectra_file, _fasta, params -> [meta, spectra_file, params] }
        .set { ch_adjusted_params }

    // Run MaxQuant peptide identification with adjusted parameters
    MAXQUANT_SEARCH(ch_adjusted_params)
    ch_versions = ch_versions.mix(MAXQUANT_SEARCH.out.versions)

    emit:
    msms     = MAXQUANT_SEARCH.out.msms    // channel: tuple val(meta), path(*_msms.txt)
    versions = ch_versions                  // channel: path(versions.yml)
}
