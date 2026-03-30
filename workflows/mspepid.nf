/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_mspepid_pipeline'

include { PREPARE_DATABASES } from '../subworkflows/local/prepare_databases'
include { PREPARE_SPECTRA } from '../subworkflows/local/prepare_spectra'
include { SPECTRA_IDENTIFICATION } from '../subworkflows/local/spectra_identification'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow MSPEPID {
    take:
    ch_samplesheet // channel: samplesheet read in from --input
    fasta // string: path to fasta file
    entrapment_fold // integer: fold for entrapment generation, 0 for none
    skip_decoy_generation // boolean: whether to skip decoy generation
    precursor_tol_ppm // integer: Precursor mass tolerance in ppm for spectra identification
    fragment_tol_da // float: Fragment mass tolerance in Da for spectra identification
    run_comet // boolean: whether to run Comet for spectra identification
    run_sage // boolean: whether to run Sage for spectra identification
    run_percolator // boolean: whether to run Percolator for rescoring
    sage_config_template // path: path to sage config template
    sage_prefilter_chunk_size // integer: chunk size for sage prefiltering
    sage_prefilter // boolean: whether to run sage prefiltering

    main:
    ch_versions = channel.empty()

    // create channel for fasta input
    ch_fasta = channel.fromPath(fasta, checkIfExists: true)
        .map { fa -> [[id: fa.getBaseName()], fa] }

    // prepare the databases: decoy generation and entrapment database creation
    PREPARE_DATABASES(
        ch_fasta,
        entrapment_fold,
        skip_decoy_generation,
    )
    ch_fasta_db = PREPARE_DATABASES.out.fasta

    // prepare the spectra files
    PREPARE_SPECTRA(
        ch_samplesheet
    )
    ch_prepared_spectra = PREPARE_SPECTRA.out.mzmls.join(PREPARE_SPECTRA.out.uncompressed, by: 0)

    // spectra identification
    SPECTRA_IDENTIFICATION(
        ch_fasta_db,
        ch_prepared_spectra,
        precursor_tol_ppm,
        fragment_tol_da,
        run_comet,
        run_sage,
        run_percolator,
        sage_config_template,
        sage_prefilter_chunk_size,
        sage_prefilter,
    )


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
            [process[process.lastIndexOf(':') + 1..-1], "  ${tool}: ${version}"]
        }
        .groupTuple(by: 0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_' + 'mspepid_software_' + 'versions.yml',
            sort: true,
            newLine: true,
        )
        .set { ch_collated_versions }

    emit:
    versions = ch_versions // channel: [ path(versions.yml) ]
}
