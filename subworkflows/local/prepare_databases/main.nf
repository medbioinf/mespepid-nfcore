/*
 * Prepare the protein sequence databases, like adding decoys and entrapment sequences
 */
 
 include { OPENMS_DECOYDATABASE } from '../../../modules/nf-core/openms/decoydatabase/main'

workflow PREPARE_DATABASES {

    take:
    ch_fasta
    skip_decoy_generation

    main:

    ch_versions = channel.empty()

    if (!skip_decoy_generation) {
        OPENMS_DECOYDATABASE (
            ch_fasta
        )
        ch_versions = ch_versions.mix(OPENMS_DECOYDATABASE.out.versions_openms)
        ch_fasta = OPENMS_DECOYDATABASE.out.decoy_fasta
    }

    emit:
    versions = ch_versions
    fasta = ch_fasta
}
