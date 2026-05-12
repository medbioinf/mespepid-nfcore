/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_mspepid_pipeline'

include { PREPARE_DATABASES      } from '../subworkflows/local/prepare_databases'
include { PREPARE_SPECTRA        } from '../subworkflows/local/prepare_spectra'
include { SPECTRA_IDENTIFICATION } from '../subworkflows/local/spectra_identification'
include { SPECTRA_RESCORING      } from '../subworkflows/local/spectra_rescoring'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow MSPEPID {
    take:
    ch_samplesheet    // channel: [meta, spectrum_file, fasta_file] read in from --input
    outdir
    entrapment_fold // integer: fold for entrapment generation, 0 for none
    skip_decoy_generation // boolean: whether to skip decoy generation
    precursor_tol_ppm // integer: Precursor mass tolerance in ppm for spectra identification
    fragment_tol_da // float: Fragment mass tolerance in Da for spectra identification
    run_comet // boolean: whether to run Comet for spectra identification
    run_sage // boolean: whether to run Sage for spectra identification
    run_percolator // boolean: whether to run Percolator for rescoring
    run_ms2rescore // boolean: whether to run MS2Rescore for rescoring
    comet_config_template // string: path to comet config template, or null to use created default config
    sage_config_template // path: path to sage config template
    sage_prefilter_chunk_size // integer: chunk size for sage prefiltering
    sage_prefilter // boolean: whether to run sage prefiltering
    ms2rescore_model // string: which MS2Rescore model to use for rescoring
    ms2rescore_model_dir // string: optional directory containing pre-downloaded MS2PIP models

    main:

    def ch_versions = channel.empty()

    // Extract fasta from the samplesheet channel
    ch_fasta = ch_samplesheet.map { meta, _spectrum_file, fasta_file -> [meta, fasta_file] }

    // Deduplicate FASTAs by path: run PREPARE_DATABASES once per unique FASTA file.
    // To later join the FASTAs back to then runs, meta gets a 'sample_ids' list of all run IDs
    ch_fasta_dedup = ch_fasta
        .map { meta, fasta -> [fasta.toString(), meta.id, fasta] }
        .groupTuple(by: 0)
        .map { _path_key, sample_ids, fastas ->
            [[id: fastas[0].getBaseName(), sample_ids: sample_ids], fastas[0]]
        }

    // prepare the databases: decoy generation and entrapment database creation
    PREPARE_DATABASES(
        ch_fasta_dedup,
        entrapment_fold,
        skip_decoy_generation,
    )
    // create one [sample_id, db_fasta] for each sample_id in the original samplesheet
    ch_fasta_db_per_run = PREPARE_DATABASES.out.fasta
        .flatMap { db_meta, db_fasta ->
            db_meta.sample_ids.collect { run_id -> [run_id, db_fasta] }
        }

    // prepare the spectra files (strip the fasta_file before passing to PREPARE_SPECTRA)
    PREPARE_SPECTRA(
        ch_samplesheet.map { meta, spectrum_file, _fasta_file -> [meta, spectrum_file] }
    )
    ch_prepared_spectra = PREPARE_SPECTRA.out.mzmls.join(PREPARE_SPECTRA.out.uncompressed, by: 0)

    // spectra identification
    SPECTRA_IDENTIFICATION(
        ch_prepared_spectra,
        ch_fasta_db_per_run,
        precursor_tol_ppm,
        fragment_tol_da,
        run_comet,
        run_sage,
        comet_config_template,
        sage_config_template,
        sage_prefilter_chunk_size,
        sage_prefilter,
    )

    // spectra rescoring
    SPECTRA_RESCORING(
        SPECTRA_IDENTIFICATION.out.psmutils_tsvs,
        SPECTRA_IDENTIFICATION.out.searchengine_pins,
        ch_prepared_spectra,
        fragment_tol_da,
        run_percolator,
        run_ms2rescore,
        ms2rescore_model,
        ms2rescore_model_dir,
    )
    ch_versions = ch_versions.mix(SPECTRA_RESCORING.out.versions)

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'mspepid_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        )
    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
