include { COMET } from '../../../modules/local/comet/main'
include { SAGECONFIG } from '../../../modules/local/sageconfig/main'
include { SAGEBETA } from '../../../modules/local/sagebeta/main'

include { PSMUTILSCONVERSIONS } from '../../../modules/local/psmutilsconversions/main'
include { PERCOLATOR } from '../../../modules/local/percolator/main'

workflow SPECTRA_IDENTIFICATION {
    take:
    ch_fasta
    ch_spectra_files // val(meta), path(mzml), path(raw_spectra)
    precursor_tol_ppm
    fragment_tol_da
    run_comet
    run_sage
    run_percolator
    sage_config_template
    sage_prefilter_chunk_size
    sage_prefilter

    main:

    ch_versions = channel.empty()

    // TODO: this will become the identifications, probably with some meta mapping?
    ch_identifications = channel.empty()

    // prepare the input channel for identifications
    // TODO: this right now only adds the fasta - must be adapted for per sample DB
    // TODO: also adapt for per-sample parameters
    ch_ident_in = ch_spectra_files.combine(ch_fasta.map { _meta, fasta -> [fasta] })

    // run Comet, if enabled
    if (run_comet) {
        ch_comet_in = ch_ident_in.map { meta, mzml, _raw_spectra, fasta -> [meta, mzml, fasta] }
        COMET(
            ch_comet_in,
            precursor_tol_ppm,
            fragment_tol_da,
        )
        ch_versions = ch_versions.mix(COMET.out.versions_comet)
        ch_identifications = ch_identifications.mix(COMET.out.mzid.map { meta, mzid -> [meta + [searchengine: 'comet', idfile_type: 'mzid'], mzid] })
    }

    if (run_sage) {
        SAGECONFIG(
            sage_config_template,
            sage_prefilter_chunk_size,
            sage_prefilter,
            precursor_tol_ppm,
            fragment_tol_da,
        )
        ch_versions = ch_versions.mix(SAGECONFIG.out.versions_sageconfig)

        ch_sage_spectra = ch_spectra_files.map { meta, mzml, _raw_spectra -> [meta, mzml] }
        // add empty meta information for compatibility and convert to value channel
        ch_sage_config = SAGECONFIG.out.config.map { config -> [["ID": "SAGE_CONFIG"], config] }
        // convert to value channe
        ch_sage_fasta = ch_fasta.first()

        SAGEBETA(
            ch_sage_spectra,
            ch_sage_fasta,
            ch_sage_config,
        )
        ch_versions = ch_versions.mix(SAGEBETA.out.versions_sagebeta)
        ch_identifications = ch_identifications.mix(SAGEBETA.out.tsv.map { meta, tsv -> [meta + [searchengine: 'sage', idfile_type: 'sage_tsv'], tsv] })
    }

    // convert search results into psm-utils format and PIN files for downstream processing
    PSMUTILSCONVERSIONS(
        ch_identifications
    )
    ch_versions = ch_versions.mix(PSMUTILSCONVERSIONS.out.versions_psm_utils)
    ch_versions = ch_versions.mix(PSMUTILSCONVERSIONS.out.versions_python)

    ch_psmutils_tsvs = PSMUTILSCONVERSIONS.out.psm_utils_tsv.map { meta, file -> [meta + [status: 'psmutils'], file] }
    ch_searchengine_pins = PSMUTILSCONVERSIONS.out.pin.map { meta, file -> [meta + [status: 'pin'], file] }

    // run percolator, if enabled
    if (run_percolator) {
        ch_percolator_in = ch_searchengine_pins.map { meta, pin -> [meta + [outdir: meta.searchengine], pin] }
        PERCOLATOR(
            ch_percolator_in
        )
        ch_versions = ch_versions.mix(PERCOLATOR.out.versions_percolator)
    }

    emit:
    versions = ch_versions
    raw_identifications = ch_identifications
    psmutils_tsvs = ch_psmutils_tsvs
    searchengine_pins = ch_searchengine_pins
}
