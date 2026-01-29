// Original file: mspepid/src/identification/sage_identification.nf (sage_identification workflow)
/*
 * Sage peptide identification workflow
 */

include { SAGE_ADJUST_CONFIG    } from '../../../modules/local/sageadjustconfig/main'
include { SAGE_SEARCH          } from '../../../modules/local/sagesearch/main'
include { SAGE_RESULTS_SEPARATE } from '../../../modules/local/sageresultsseparate/main'

workflow SAGE_IDENTIFICATION {

    take:
    ch_sage_config           // channel: path(sage_config)
    ch_fasta                 // channel: path(fasta)
    ch_mzmls                 // channel: tuple(meta, path(mzml))
    precursor_tol_ppm        // value: precursor tolerance in ppm
    fragment_tol_da          // value: fragment tolerance in Da

    main:
    ch_versions = channel.empty()

    // Adjust Sage configuration file with tolerances
    SAGE_ADJUST_CONFIG(
        ch_sage_config,
        precursor_tol_ppm,
        fragment_tol_da
    )
    ch_versions = ch_versions.mix(SAGE_ADJUST_CONFIG.out.versions)

    // Collect all mzMLs for batch processing (Sage processes all at once)
    ch_mzmls_collected = ch_mzmls
        .map { meta, mzml -> mzml }
        .collect()

    // Run Sage search on all mzMLs simultaneously
    SAGE_SEARCH(
        SAGE_ADJUST_CONFIG.out.config,
        ch_fasta,
        ch_mzmls_collected
    )
    ch_versions = ch_versions.mix(SAGE_SEARCH.out.versions)

    // Separate combined results into per-file TSVs
    SAGE_RESULTS_SEPARATE(SAGE_SEARCH.out.sage_tsv)
    ch_versions = ch_versions.mix(SAGE_RESULTS_SEPARATE.out.versions)

    // Map separated results back to meta for downstream processing
    ch_sage_tsvs_with_meta = SAGE_RESULTS_SEPARATE.out.sage_tsv
        .flatten()
        .map { sage_tsv ->
            // Extract mzML filename from sage TSV filename (e.g., "file.mzML.sage.tsv" -> "file")
            def mzml_basename = sage_tsv.name.take(sage_tsv.name.lastIndexOf('.sage.tsv'))
            tuple([id: mzml_basename], sage_tsv)
        }

    emit:
    sage_tsvs = ch_sage_tsvs_with_meta  // channel: tuple val(meta), path(sage_tsv)
    versions  = ch_versions              // channel: path(versions.yml)
}
