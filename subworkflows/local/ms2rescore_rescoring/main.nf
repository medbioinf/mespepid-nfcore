/*
 * MS2Rescore rescoring workflow
 * Takes PSM TSV files and corresponding mzML files and performs MS2 rescoring
 * using MS2PIP and DeepLC features, then outputs PIN files for Percolator
 */

include { MS2RESCORE_MODEL_DOWNLOAD } from '../../../modules/local/ms2rescoremodeldownload/main'
include { MS2RESCORE              } from '../../../modules/local/ms2rescore/main'
include { MS2RESCORE_PIN_CORRECTION } from '../../../modules/local/ms2rescorepincorrection/main'
include { PERCOLATOR              } from '../../../modules/local/percolator/main'

workflow MS2RESCORE_RESCORING {

    take:
    ch_psm_tsv           // channel: tuple val(meta), path(psm_tsv), path(spectra_file)
    searchengine         // val: search engine name (e.g., 'sage', 'xtandem', 'comet')
    spectrum_id_pattern  // val: regex pattern to match spectrum IDs
    fragment_tol_da      // val: fragment tolerance in Daltons
    ms2rescore_model     // val: MS2PIP model name (e.g., 'HCD')
    ms2rescore_chunk_size // val: chunk size for processing PSMs
    model_dir            // val: directory for MS2PIP model storage

    main:
    ch_versions = channel.empty()

    // Download/check MS2PIP model (runs once)
    MS2RESCORE_MODEL_DOWNLOAD(
        ms2rescore_model,
        model_dir
    )
    ch_versions = ch_versions.mix(MS2RESCORE_MODEL_DOWNLOAD.out.versions.first())
    // Run MS2Rescore on each PSM TSV file
    MS2RESCORE(
        ch_psm_tsv,
        searchengine,
        spectrum_id_pattern,
        fragment_tol_da,
        ms2rescore_model,
        ms2rescore_chunk_size,
        MS2RESCORE_MODEL_DOWNLOAD.out.model_dir
    )
    ch_versions = ch_versions.mix(MS2RESCORE.out.versions)

    // Correct MS2Rescore PIN files to have proper SpecId and ScanNr format
    MS2RESCORE_PIN_CORRECTION(
        MS2RESCORE.out.pin,
        searchengine
    )
    ch_versions = ch_versions.mix(MS2RESCORE_PIN_CORRECTION.out.versions)

    // Run Percolator on corrected MS2Rescore PIN files
    PERCOLATOR(
        MS2RESCORE_PIN_CORRECTION.out.pin,
        searchengine
    )
    ch_versions = ch_versions.mix(PERCOLATOR.out.versions)

    emit:
    pin_files  = MS2RESCORE_PIN_CORRECTION.out.pin  // channel: tuple val(meta), path(pin)
    pout_files = PERCOLATOR.out.pout                // channel: tuple val(meta), path(pout)
    versions   = ch_versions                        // channel: path(versions.yml)
}
