/*
    Process mzML files for downstream analysis
*/

include { SPLIT_MZML_INTO_CHUNKS } from '../../../modules/local/splitmzmlintochunks/main.nf'

workflow MZML_PROCESSING {

    take:
    ch_mzml      // channel: tuple val(meta), path(mzml)
    chunksize    // val: number of spectra per chunk (optional, 0 or null to skip chunking)

    main:
    ch_versions = channel.empty()
    
    // Split mzML files into chunks if chunksize is provided and > 0
    if (chunksize && chunksize > 0) {
        SPLIT_MZML_INTO_CHUNKS(ch_mzml, chunksize)
        ch_mzml_out = SPLIT_MZML_INTO_CHUNKS.out.mzml_chunks
            .transpose() // Convert list of chunks to individual files
        ch_versions = ch_versions.mix(SPLIT_MZML_INTO_CHUNKS.out.versions)
    } else {
        // Pass through without chunking
        ch_mzml_out = ch_mzml
    }

    emit:
    mzml     = ch_mzml_out
    versions = ch_versions
}
