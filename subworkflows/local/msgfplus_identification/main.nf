/*
 * MS-GF+ identification workflow
 */

include { MSGFPLUS_SPLIT_FASTA         } from '../../../modules/local/msgfplussplitfasta/main.nf'
include { MSGFPLUS_BUILD_INDEX         } from '../../../modules/local/msgfplusbuildindex/main.nf'
include { MSGFPLUS_SEARCH             } from '../../../modules/local/msgfplussearch/main.nf'
include { MSGFPLUS_MZID_MERGER         } from '../../../modules/local/msgfplusmzidmerger/main.nf'
include { MSGFPLUS_MERGE_PSMS          } from '../../../modules/local/msgfplusmergepsms/main.nf'
include { CONVERT_TO_PSM_UTILS       } from '../../../modules/local/converttopsmutils/main.nf'

workflow MSGFPLUS_IDENTIFICATION {

    take:
    ch_msgfplus_params    // channel: path(msgfplus_params)
    ch_fasta              // channel: path(fasta)
    ch_mzmls              // channel: tuple(meta, path(mzml))
    precursor_tol_ppm     // value: precursor tolerance in ppm
    msgfplus_split_fasta  // value: number of fasta splits (0 = no split)
    msgfplus_split_input  // value: number of mzml splits (0 = no split)

    main:
    ch_versions = channel.empty()

    // Split FASTA if requested
    if (msgfplus_split_fasta > 0) {
        ch_fasta_for_split = ch_fasta.map { fasta -> 
            tuple(fasta, msgfplus_split_fasta)
        }
        MSGFPLUS_SPLIT_FASTA(ch_fasta_for_split)
        ch_fasta_parts = MSGFPLUS_SPLIT_FASTA.out.fasta_parts
            .flatten()
        ch_versions = ch_versions.mix(MSGFPLUS_SPLIT_FASTA.out.versions)
    } else {
        ch_fasta_parts = ch_fasta
    }

    // Build MS-GF+ index for each fasta
    MSGFPLUS_BUILD_INDEX(ch_fasta_parts)
    ch_versions = ch_versions.mix(MSGFPLUS_BUILD_INDEX.out.versions.first())

    // Prepare mzML channels
    if (msgfplus_split_input > 0) {
        // For now, we'll just map mzMLs with their basename
        // User would need to implement SPLIT_MZML_INTO_CHUNKS if needed
        ch_mzmls_to_process = ch_mzmls
    } else {
        ch_mzmls_to_process = ch_mzmls
    }

    // Combine fasta index with mzML files and prepare for search
    ch_search_input = MSGFPLUS_BUILD_INDEX.out.index
        .combine(ch_mzmls_to_process)
        .combine(ch_msgfplus_params)
        .map { fasta, canno, cnlcp, csarr, cseq, meta, mzml, msgfplus_params ->
            tuple(
                meta,
                msgfplus_params,
                mzml,
                fasta,
                canno,
                cnlcp,
                csarr,
                cseq,
                precursor_tol_ppm
            )
        }

    // Run MS-GF+ search
    MSGFPLUS_SEARCH(ch_search_input)
    ch_versions = ch_versions.mix(MSGFPLUS_SEARCH.out.versions.first())

    // Merge FASTA splits if they were created
    if (msgfplus_split_fasta > 0) {
        ch_for_fasta_merge = MSGFPLUS_SEARCH.out.mzid
            .map { meta, mzid ->
                def mzml_split = mzid.name.take(mzid.name.lastIndexOf('-split'))
                tuple(meta, mzml_split, mzid)
            }
            .groupTuple(by: [0, 1])
        
        MSGFPLUS_MZID_MERGER(ch_for_fasta_merge)
        ch_mzid_merged = MSGFPLUS_MZID_MERGER.out.mzid
        ch_versions = ch_versions.mix(MSGFPLUS_MZID_MERGER.out.versions.first())
    } else {
        ch_mzid_merged = MSGFPLUS_SEARCH.out.mzid
    }

    // Convert to PSM utils format
    ch_for_conversion = ch_mzid_merged.map { meta, mzid ->
        tuple(meta, mzid, 'mzid')
    }
    CONVERT_TO_PSM_UTILS(ch_for_conversion)
    ch_versions = ch_versions.mix(CONVERT_TO_PSM_UTILS.out.versions.first())

    // Merge chunks if mzML was split
    if (msgfplus_split_input > 0) {
        ch_for_merge = CONVERT_TO_PSM_UTILS.out.psm_tsv
            .groupTuple(by: 0)
        
        MSGFPLUS_MERGE_PSMS(ch_for_merge)
        ch_final_psms = MSGFPLUS_MERGE_PSMS.out.merged_psm
        ch_versions = ch_versions.mix(MSGFPLUS_MERGE_PSMS.out.versions.first())
    } else {
        ch_final_psms = CONVERT_TO_PSM_UTILS.out.psm_tsv
    }

    emit:
    psm_tsvs = ch_final_psms    // channel: tuple(meta, path(psm_tsv))
    versions = ch_versions       // channel: path(versions.yml)
}
