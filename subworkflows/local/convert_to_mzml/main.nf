/*
    Preprocess raw spectral data files into mzml format
*/

include { THERMORAWFILEPARSER } from '../../../modules/nf-core/thermorawfileparser/main.nf'
include { CONVERT_BRUKER_D    } from '../../../modules/local/convertbrukerd/main.nf'
include { ADJUST_MZML         } from '../../../modules/local/adjustmzml/main.nf'

workflow CONVERT_TO_MZML {

    take:
    ch_samplesheet  // channel: tuple val(meta), path(input_file)

    main:
    ch_versions = channel.empty()

    // Branch by acquisition type from metadata
    ch_samplesheet
    .branch {
        meta, file ->

            // timsTOF (.d)
            d : meta.ext == 'd'
                return [ meta.subMap('id', 'sample'), file ]

            // Thermo RAW (.raw)
            raw : meta.ext == 'raw'
                return [ meta.subMap('id', 'sample'), file ]

            // Catch-all
            other : true
    }
    .set { ch_branch }

    // Convert inputs
    CONVERT_BRUKER_D(ch_branch.d)
    ch_versions = ch_versions.mix(CONVERT_BRUKER_D.out.versions)
    
    THERMORAWFILEPARSER(ch_branch.raw)
    ch_versions = ch_versions.mix(THERMORAWFILEPARSER.out.versions)

    // Normalize mzML format (only for Bruker .d files)
    ADJUST_MZML(CONVERT_BRUKER_D.out.mzml)
    ch_versions = ch_versions.mix(ADJUST_MZML.out.versions)

    // Merge mzML streams
    ch_mzml = ADJUST_MZML.out.mzml
                .mix(THERMORAWFILEPARSER.out.spectra)

    emit:
    mzml     = ch_mzml
    versions = ch_versions
}