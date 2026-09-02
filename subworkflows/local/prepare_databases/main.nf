/*
 * Prepare the protein sequence databases, like adding decoys and entrapment sequences
 */

include { FDRBENCH } from '../../../modules/local/fdrbench/main'
include { OPENMS_DECOYDATABASE } from '../../../modules/nf-core/openms/decoydatabase/main'

workflow PREPARE_DATABASES {
    take:
    ch_fasta
    entrapment_fold
    skip_decoy_generation

    main:

    ch_versions = channel.empty()

    if (entrapment_fold > 0) {
        FDRBENCH(
            ch_fasta,
            entrapment_fold,
        )
        // versions are topic-style, already collected globally - do not mix into ch_versions
        ch_fasta = FDRBENCH.out.entrapment_fasta
    }

    if (!skip_decoy_generation) {
        OPENMS_DECOYDATABASE(
            ch_fasta
        )
        // versions are topic-style, already collected globally - do not mix into ch_versions
        ch_fasta = OPENMS_DECOYDATABASE.out.decoy_fasta
    }

    emit:
    versions = ch_versions
    fasta = ch_fasta
}
