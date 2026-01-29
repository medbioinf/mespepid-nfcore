include { OKTOBERFEST        } from '../../../modules/local/oktoberfest/main'
include { OKTOBERFEST_TO_PIN } from '../../../modules/local/oktoberfesttopin/main'
include { PERCOLATOR         } from '../../../modules/local/percolator/main'

workflow OKTOBERFEST_RESCORING {
    take:
    ch_psm_tsv             // channel: tuple(meta, psm_tsv, spectra_file)
    searchengine           // val: search engine name
    scan_id_pattern        // val: regex pattern to extract scan ID
    fragment_tol_da        // val: fragment tolerance in Da
    oktoberfest_intensity_model  // val: intensity prediction model
    oktoberfest_irt_model        // val: iRT prediction model

    main:
    ch_versions = channel.empty()

    // Run Oktoberfest feature generation
    OKTOBERFEST(
        ch_psm_tsv,
        searchengine,
        scan_id_pattern,
        fragment_tol_da,
        oktoberfest_intensity_model,
        oktoberfest_irt_model
    )
    ch_versions = ch_versions.mix(OKTOBERFEST.out.versions)

    // Convert Oktoberfest features to PIN format
    OKTOBERFEST_TO_PIN(
        OKTOBERFEST.out.features,
        searchengine
    )
    ch_versions = ch_versions.mix(OKTOBERFEST_TO_PIN.out.versions)

    // Run Percolator on Oktoberfest PIN files
    PERCOLATOR(
        OKTOBERFEST_TO_PIN.out.pin,
        searchengine
    )
    ch_versions = ch_versions.mix(PERCOLATOR.out.versions)

    emit:
    features   = OKTOBERFEST.out.features
    pin_files  = OKTOBERFEST_TO_PIN.out.pin
    pout_files = PERCOLATOR.out.pout
    versions   = ch_versions
}
