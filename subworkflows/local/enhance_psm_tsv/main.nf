// Original file: mspepid/src/postprocessing/convert_and_enhance_psm_tsv.nf (enhance_psm_tsv workflow)
/*
 * Enhances PSM TSV files and creates PIN files for Percolator
 */

include { ADJUST_PSM_LIST              } from '../../../modules/local/adjustpsmlist/main.nf'
include { PSMS_TO_PIN_AND_ENHANCED_TSV    } from '../../../modules/local/psmstopinandenhancedtsv/main.nf'

workflow ENHANCE_PSM_TSV {

    take:
    ch_psm_utils_tsvs  // channel: tuple(meta, path(psm_utils_tsv))
    searchengine       // value: search engine name (string)

    main:
    ch_versions = channel.empty()

    // Add searchengine to channel
    ch_psm_with_engine = ch_psm_utils_tsvs.map { meta, tsv ->
        tuple(meta, tsv, searchengine)
    }

    // Adjust PSM list
    ADJUST_PSM_LIST(ch_psm_with_engine)
    ch_versions = ch_versions.mix(ADJUST_PSM_LIST.out.versions.first())

    // Create PIN file and enhanced TSV
    PSMS_TO_PIN_AND_ENHANCED_TSV(ADJUST_PSM_LIST.out.adjusted_tsv)
    ch_versions = ch_versions.mix(PSMS_TO_PIN_AND_ENHANCED_TSV.out.versions.first())

    emit:
    psm_tsv  = PSMS_TO_PIN_AND_ENHANCED_TSV.out.psm_tsv   // channel: tuple(meta, path(enhanced_tsv))
    pin_file = PSMS_TO_PIN_AND_ENHANCED_TSV.out.pin_file  // channel: tuple(meta, path(pin))
    versions = ch_versions                            // channel: path(versions.yml)
}
