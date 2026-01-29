// Original file: mspepid/src/postprocessing/convert_and_enhance_psm_tsv.nf (convert_and_enhance_psm_tsv workflow)
/*
 * Converts search engine results to PSM utils format, then enhances and creates PIN files
 */

include { CONVERT_TO_PSM_UTILS          } from '../../../modules/local/converttopsmutils/main'
include { ENHANCE_PSM_TSV            } from '../enhance_psm_tsv/main'

workflow CONVERT_AND_ENHANCE_PSM_TSV {

    take:
    ch_searchengine_results  // channel: tuple(meta, path(results), val(type))
    searchengine             // value: search engine name (string)

    main:
    ch_versions = channel.empty()

    // Convert search engine results to PSM utils format
    CONVERT_TO_PSM_UTILS(ch_searchengine_results)
    ch_versions = ch_versions.mix(CONVERT_TO_PSM_UTILS.out.versions.first())

    // Enhance PSM TSV and create PIN files
    ENHANCE_PSM_TSV(CONVERT_TO_PSM_UTILS.out.psm_tsv, searchengine)
    ch_versions = ch_versions.mix(ENHANCE_PSM_TSV.out.versions)

    emit:
    psm_tsv  = ENHANCE_PSM_TSV.out.psm_tsv   // channel: tuple(meta, path(enhanced_tsv))
    pin_file = ENHANCE_PSM_TSV.out.pin_file  // channel: tuple(meta, path(pin))
    versions = ch_versions                    // channel: path(versions.yml)
}
