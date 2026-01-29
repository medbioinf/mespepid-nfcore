/*
 * Percolator rescoring workflow
 * Takes PIN files from search engines and performs FDR control
 */

include { PERCOLATOR } from '../../../modules/local/percolator/main'

workflow PERCOLATOR_RESCORING {

    take:
    ch_pin_files     // channel: tuple val(meta), path(pin)
    searchengine     // val: search engine name (e.g., 'sage', 'xtandem', 'comet')

    main:
    ch_versions = Channel.empty()

    // Run percolator on each PIN file
    PERCOLATOR(
        ch_pin_files,
        searchengine
    )
    ch_versions = ch_versions.mix(PERCOLATOR.out.versions)

    emit:
    pout_files = PERCOLATOR.out.pout      // channel: tuple val(meta), path(pout)
    versions   = ch_versions               // channel: path(versions.yml)
}
