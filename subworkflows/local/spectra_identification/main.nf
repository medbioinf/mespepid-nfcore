include { COMETCONFIG } from '../../../modules/local/cometconfig/main'
include { COMET } from '../../../modules/nf-core/comet/main'
include { SAGECONFIG } from '../../../modules/local/sageconfig/main'
include { SAGEBETA } from '../../../modules/local/sagebeta/main'

include { PSMUTILSCONVERSIONS } from '../../../modules/local/psmutilsconversions/main'

workflow SPECTRA_IDENTIFICATION {
    take:
    ch_spectra_files // val(meta), path(mzml), path(raw_spectra)
    ch_fasta_db // channel: [sample_id, db_fasta] one item per sample
    precursor_tol_ppm
    fragment_tol_da
    run_comet
    run_sage
    comet_config_template
    sage_config_template
    sage_prefilter_chunk_size
    sage_prefilter

    main:
    ch_versions = channel.empty()

    // this will contain the identifications, with some meta data
    ch_identifications = channel.empty()

    // join each spectrum file with its per-run database FASTA
    ch_ident_in = ch_spectra_files
        .map { meta, mzml, raw -> [meta.id, meta, mzml, raw] }
        .join(ch_fasta_db, by: 0)
        .map { _id, meta, mzml, raw, fasta -> [meta, mzml, raw, fasta] }

    // run Comet, if enabled
    if (run_comet) {
        // TODO: allow comet_config_templates per sample file
        ch_comet_config_template = comet_config_template ? channel.fromPath(comet_config_template, checkIfExists: true) : channel.fromPath("${projectDir}/assets/searchengines/comet.params", checkIfExists: true)
        ch_comet_config_template = ch_comet_config_template.map { params -> [[id: 'default'], params] }

        COMETCONFIG(
            ch_comet_config_template,
            precursor_tol_ppm,
            fragment_tol_da,
        )

        ch_comet_in = ch_ident_in
            .map { meta, mzml, _raw_spectra, fasta -> [meta, mzml, fasta] }
            .combine(COMETCONFIG.out.params.map { _meta, params -> [params] })

        COMET(
            ch_comet_in
        )
        ch_versions = ch_versions.mix(COMET.out.versions_comet)
        ch_identifications = ch_identifications.mix(
            COMET.out.mzid.map { meta, mzid ->
                def spectrumPattern = meta.vendor == 'bruker'
                    ? '.*index=(\\d+)(?!\\d).*$'
                    : '.*scan=(\\d+)(?!\\d).*$'

                def scanIdPattern = '^(?P<scan_id>\\d+)(?!\\d).*$'

                [meta + [searchengine: 'comet', idfile_type: 'mzid', spectrum_id_pattern: spectrumPattern, scan_id_pattern: scanIdPattern], mzid]
            }
        )
    }

    if (run_sage) {
        // TODO: allow per sample config files
        ch_sage_config_template = sage_config_template ? channel.fromPath(sage_config_template, checkIfExists: true) : channel.fromPath("${projectDir}/assets/searchengines/default.sage.json", checkIfExists: true)
        SAGECONFIG(
            ch_sage_config_template,
            sage_prefilter_chunk_size,
            sage_prefilter,
            precursor_tol_ppm,
            fragment_tol_da,
        )
        ch_versions = ch_versions.mix(SAGECONFIG.out.versions_python)

        ch_sage_config = SAGECONFIG.out.config.map { config -> [['ID': 'SAGE_CONFIG'], config] }.first()

        // Re-use ch_ident_in (already joined with per-run fasta) and split into
        // the two separate channels SAGEBETA requires.
        ch_sage_joined = ch_ident_in.multiMap { meta, mzml, _raw, fasta ->
            spectra: [meta, mzml]
            fasta: [[id: fasta.getBaseName()], fasta]
        }

        SAGEBETA(
            ch_sage_joined.spectra,
            ch_sage_joined.fasta,
            ch_sage_config,
        )
        ch_versions = ch_versions.mix(SAGEBETA.out.versions_sagebeta)
        ch_identifications = ch_identifications.mix(
            SAGEBETA.out.tsv.map { meta, tsv ->
                def spectrumPattern = meta.vendor == 'bruker'
                    ? '(.*)'
                    : '(.*)'

                def scanIdPattern = meta.vendor == 'bruker'
                    ? '.*index=(?P<scan_id>\\d+)(?!\\d).*$'
                    : '.*scan=(?P<scan_id>\\d+)(?!\\d).*$'

                [meta + [searchengine: 'sage', idfile_type: 'sage_tsv', spectrum_id_pattern: spectrumPattern, scan_id_pattern: scanIdPattern], tsv]
            }
        )
    }

    // convert search results into psm-utils format and PIN files for downstream processing
    PSMUTILSCONVERSIONS(
        ch_identifications
    )
    ch_versions = ch_versions.mix(PSMUTILSCONVERSIONS.out.versions_psm_utils)
    ch_versions = ch_versions.mix(PSMUTILSCONVERSIONS.out.versions_python)

    ch_psmutils_tsvs = PSMUTILSCONVERSIONS.out.psm_utils_tsv.map { meta, file -> [meta + [status: 'psmutils'], file] }
    ch_searchengine_pins = PSMUTILSCONVERSIONS.out.pin.map { meta, file -> [meta + [status: 'pin'], file] }

    emit:
    versions = ch_versions
    raw_identifications = ch_identifications
    psmutils_tsvs = ch_psmutils_tsvs
    searchengine_pins = ch_searchengine_pins
}
