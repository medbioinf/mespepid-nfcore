/*
    Prepare protein database for peptide identification
*/

include { CALL_ENTRAPMENT_DATABASE } from '../../../modules/local/callentrapmentdatabase/main.nf'
include { OPENMS_DECOYDATABASE   } from '../../../modules/nf-core/openms/decoydatabase/main.nf'

workflow DATABASE_PREPARATION {

    take:
    ch_fasta  // channel: tuple val(meta), path(fasta)
    fold      // val: entrapment fold (optional, can be null or 0 to skip)

    main:
    ch_versions = channel.empty()

    // Branch based on fold value
    if (fold && fold > 0) {
        // Extract just the fasta file for CALLENTRAPMENTDATABASE (it doesn't use meta)
        ch_fasta
            .map { meta, fasta -> fasta }
            .set { ch_fasta_only }
        
        CALL_ENTRAPMENT_DATABASE(ch_fasta_only, fold)
        
        // Add meta map back to output
        ch_fasta
            .map { meta, fasta -> meta }
            .combine(CALL_ENTRAPMENT_DATABASE.out.fasta)
            .set { ch_fasta_for_decoy }
        
        ch_versions = ch_versions.mix(CALL_ENTRAPMENT_DATABASE.out.versions)
    } else {
        // Pass through with existing meta
        ch_fasta_for_decoy = ch_fasta
    }

    // Generate decoy database (already has proper tuple structure)
    OPENMS_DECOYDATABASE(ch_fasta_for_decoy)
    // Note: OPENMS_DECOYDATABASE uses topic-based versions (versions_openms with topic: versions)
    // so we don't mix it into ch_versions manually - it's automatically collected

    emit:
    fasta_with_decoys = OPENMS_DECOYDATABASE.out.decoy_fasta
    versions          = ch_versions
}
