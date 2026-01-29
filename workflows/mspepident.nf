/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_mspepident_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { CONVERT_TO_MZML          } from '../subworkflows/local/convert_to_mzml/main'
include { DATABASE_PREPARATION     } from '../subworkflows/local/database_preparation/main'
include { MZML_PROCESSING          } from '../subworkflows/local/mzml_processing/main'
include { COMET_IDENTIFICATION     } from '../subworkflows/local/comet_identification/main'
include { MAXQUANT_IDENTIFICATION  } from '../subworkflows/local/maxquant_identification/main'
include { MSAMANDA_IDENTIFICATION  } from '../subworkflows/local/msamanda_identification/main'
include { MSFRAGGER_IDENTIFICATION } from '../subworkflows/local/msfragger_identification/main'
include { MSGFPLUS_IDENTIFICATION  } from '../subworkflows/local/msgfplus_identification/main'
include { SAGE_IDENTIFICATION      } from '../subworkflows/local/sage_identification/main'
include { XTANDEM_IDENTIFICATION   } from '../subworkflows/local/xtandem_identification/main'
include { CONVERT_AND_ENHANCE_PSM_TSV } from '../subworkflows/local/convert_and_enhance_psm_tsv/main'
include { PERCOLATOR_RESCORING     } from '../subworkflows/local/percolator_rescoring/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow MSPEPIDENT {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    ch_fasta       // channel: reference protein FASTA file from --fasta

    main:

    ch_versions = channel.empty()
    // ch_multiqc_files = channel.empty()

    //
    // SUBWORKFLOW: Convert raw data to mzML format
    //
    CONVERT_TO_MZML(ch_samplesheet)
    ch_versions = ch_versions.mix(CONVERT_TO_MZML.out.versions)

    //
    // SUBWORKFLOW: Prepare protein database with entrapment and decoy sequences
    //
    DATABASE_PREPARATION(
        ch_fasta,
        params.entrapment_fold ?: null
    )
    ch_versions = ch_versions.mix(DATABASE_PREPARATION.out.versions)

    //
    // SUBWORKFLOW: Process mzML files (optional chunking for parallel processing)
    //
    MZML_PROCESSING(
        CONVERT_TO_MZML.out.mzml,
        params.chunk_size
    )
    ch_versions = ch_versions.mix(MZML_PROCESSING.out.versions)

    //
    // SUBWORKFLOW: Comet peptide identification
    //
    if (params.execute_comet) {
        // Create channel for Comet parameters file
        ch_comet_params = channel.fromPath(params.comet_params_file, checkIfExists: true)
            .map { file -> [[id: 'comet_params'], file] }
        
        COMET_IDENTIFICATION(
            MZML_PROCESSING.out.mzml,
            DATABASE_PREPARATION.out.fasta_with_decoys,
            ch_comet_params,
            params.precursor_tol_ppm,
            params.fragment_tol_da
        )
        ch_versions = ch_versions.mix(COMET_IDENTIFICATION.out.versions)
    }

    //
    // SUBWORKFLOW: MaxQuant peptide identification
    //
    if (params.execute_maxquant) {
        // Create channel for MaxQuant parameters file
        ch_maxquant_params = channel.fromPath(params.maxquant_params_file, checkIfExists: true)
            .map { file -> [[id: 'maxquant_params'], file] }
        
        MAXQUANT_IDENTIFICATION(
            ch_samplesheet,
            DATABASE_PREPARATION.out.fasta_with_decoys,
            ch_maxquant_params,
            params.precursor_tol_ppm
        )
        ch_versions = ch_versions.mix(MAXQUANT_IDENTIFICATION.out.versions)
    }

    //
    // SUBWORKFLOW: MSAmanda peptide identification
    //
    if (params.execute_msamanda) {
        // Create channel for MSAmanda parameters file
        ch_msamanda_params = channel.fromPath(params.msamanda_params_file, checkIfExists: true)
        
        MSAMANDA_IDENTIFICATION(
            MZML_PROCESSING.out.mzml,
            DATABASE_PREPARATION.out.fasta_with_decoys.map { meta, fasta -> fasta },
            ch_msamanda_params,
            params.precursor_tol_ppm,
            params.fragment_tol_da
        )
        ch_versions = ch_versions.mix(MSAMANDA_IDENTIFICATION.out.versions)
    }

    //
    // SUBWORKFLOW: MSFragger peptide identification
    //
    if (params.execute_msfragger) {
        // Create channel for MSFragger parameters file
        ch_msfragger_params = channel.fromPath(params.msfragger_params_file, checkIfExists: true)
        
        MSFRAGGER_IDENTIFICATION(
            MZML_PROCESSING.out.mzml,
            DATABASE_PREPARATION.out.fasta_with_decoys.map { meta, fasta -> fasta },
            ch_msfragger_params,
            params.precursor_tol_ppm,
            params.fragment_tol_da
        )
        ch_versions = ch_versions.mix(MSFRAGGER_IDENTIFICATION.out.versions)
    }

    //
    // SUBWORKFLOW: MS-GF+ peptide identification
    //
    if (params.execute_msgfplus) {
        // Create channel for MS-GF+ parameters file
        ch_msgfplus_params = channel.fromPath(params.msgfplus_params_file, checkIfExists: true)
        
        MSGFPLUS_IDENTIFICATION(
            ch_msgfplus_params,
            DATABASE_PREPARATION.out.fasta_with_decoys.map { meta, fasta -> fasta },
            MZML_PROCESSING.out.mzml,
            params.precursor_tol_ppm,
            params.msgfplus_split_fasta,
            params.msgfplus_split_input
        )
        ch_versions = ch_versions.mix(MSGFPLUS_IDENTIFICATION.out.versions)
    }

    //
    // SUBWORKFLOW: Sage peptide identification
    //
    if (params.execute_sage) {
        // Create channel for Sage config file
        ch_sage_config = channel.fromPath(params.sage_config_file, checkIfExists: true)
        
        SAGE_IDENTIFICATION(
            ch_sage_config,
            DATABASE_PREPARATION.out.fasta_with_decoys.map { meta, fasta -> fasta },
            MZML_PROCESSING.out.mzml,
            params.precursor_tol_ppm,
            params.fragment_tol_da
        )
        ch_versions = ch_versions.mix(SAGE_IDENTIFICATION.out.versions)
    }

    //
    // SUBWORKFLOW: X!Tandem peptide identification
    //
    if (params.execute_xtandem) {
        // Create channel for X!Tandem config file
        ch_xtandem_config = channel.fromPath(params.xtandem_config_file, checkIfExists: true).first()
        
        XTANDEM_IDENTIFICATION(
            ch_xtandem_config,
            DATABASE_PREPARATION.out.fasta_with_decoys.map { meta, fasta -> fasta }.first(),
            MZML_PROCESSING.out.mzml,
            params.precursor_tol_ppm,
            params.fragment_tol_da
        )
        ch_versions = ch_versions.mix(XTANDEM_IDENTIFICATION.out.versions)
    }

    //
    // POSTPROCESSING: Convert raw results and run percolator
    //
    if (params.execute_percolator) {
        ch_versions_percolator = channel.empty()

        // Process Comet results
        if (params.execute_comet) {
            CONVERT_AND_ENHANCE_PSM_TSV(
                COMET_IDENTIFICATION.out.mzid_files.map { meta, mzid -> tuple(meta, mzid, 'mzid') },
                'comet'
            )
            ch_versions_percolator = ch_versions_percolator.mix(CONVERT_AND_ENHANCE_PSM_TSV.out.versions)
            
            PERCOLATOR_RESCORING(
                CONVERT_AND_ENHANCE_PSM_TSV.out.pin_file,
                'comet'
            )
            ch_versions_percolator = ch_versions_percolator.mix(PERCOLATOR_RESCORING.out.versions)
        }

        // Process MaxQuant results
        if (params.execute_maxquant) {
            CONVERT_AND_ENHANCE_PSM_TSV(
                MAXQUANT_IDENTIFICATION.out.msms_files.map { meta, msms -> tuple(meta, msms, 'msms') },
                'maxquant'
            )
            ch_versions_percolator = ch_versions_percolator.mix(CONVERT_AND_ENHANCE_PSM_TSV.out.versions)
            
            PERCOLATOR_RESCORING(
                CONVERT_AND_ENHANCE_PSM_TSV.out.pin_file,
                'maxquant'
            )
            ch_versions_percolator = ch_versions_percolator.mix(PERCOLATOR_RESCORING.out.versions)
        }

        // Process MSAmanda results
        if (params.execute_msamanda) {
            CONVERT_AND_ENHANCE_PSM_TSV(
                MSAMANDA_IDENTIFICATION.out.csv_files.map { meta, csv -> tuple(meta, csv, 'msamanda') },
                'msamanda'
            )
            ch_versions_percolator = ch_versions_percolator.mix(CONVERT_AND_ENHANCE_PSM_TSV.out.versions)
            
            PERCOLATOR_RESCORING(
                CONVERT_AND_ENHANCE_PSM_TSV.out.pin_file,
                'msamanda'
            )
            ch_versions_percolator = ch_versions_percolator.mix(PERCOLATOR_RESCORING.out.versions)
        }

        // Process MSFragger results
        if (params.execute_msfragger) {
            CONVERT_AND_ENHANCE_PSM_TSV(
                MSFRAGGER_IDENTIFICATION.out.pepxml_files.map { meta, pepxml -> tuple(meta, pepxml, 'pepxml') },
                'msfragger'
            )
            ch_versions_percolator = ch_versions_percolator.mix(CONVERT_AND_ENHANCE_PSM_TSV.out.versions)
            
            PERCOLATOR_RESCORING(
                CONVERT_AND_ENHANCE_PSM_TSV.out.pin_file,
                'msfragger'
            )
            ch_versions_percolator = ch_versions_percolator.mix(PERCOLATOR_RESCORING.out.versions)
        }

        // Process MS-GF+ results
        if (params.execute_msgfplus) {
            CONVERT_AND_ENHANCE_PSM_TSV(
                MSGFPLUS_IDENTIFICATION.out.mzid_files.map { meta, mzid -> tuple(meta, mzid, 'mzid') },
                'msgfplus'
            )
            ch_versions_percolator = ch_versions_percolator.mix(CONVERT_AND_ENHANCE_PSM_TSV.out.versions)
            
            PERCOLATOR_RESCORING(
                CONVERT_AND_ENHANCE_PSM_TSV.out.pin_file,
                'msgfplus'
            )
            ch_versions_percolator = ch_versions_percolator.mix(PERCOLATOR_RESCORING.out.versions)
        }

        // Process Sage results
        if (params.execute_sage) {
            CONVERT_AND_ENHANCE_PSM_TSV(
                SAGE_IDENTIFICATION.out.sage_tsvs.map { meta, tsv -> tuple(meta, tsv, 'sage_tsv') },
                'sage'
            )
            ch_versions_percolator = ch_versions_percolator.mix(CONVERT_AND_ENHANCE_PSM_TSV.out.versions)
            
            PERCOLATOR_RESCORING(
                CONVERT_AND_ENHANCE_PSM_TSV.out.pin_file,
                'sage'
            )
            ch_versions_percolator = ch_versions_percolator.mix(PERCOLATOR_RESCORING.out.versions)
        }

        // Process X!Tandem results
        if (params.execute_xtandem) {
            CONVERT_AND_ENHANCE_PSM_TSV(
                XTANDEM_IDENTIFICATION.out.xml_files.map { meta, xml -> tuple(meta, xml, 'xtandem') },
                'xtandem'
            )
            ch_versions_percolator = ch_versions_percolator.mix(CONVERT_AND_ENHANCE_PSM_TSV.out.versions)
            
            PERCOLATOR_RESCORING(
                CONVERT_AND_ENHANCE_PSM_TSV.out.pin_file,
                'xtandem'
            )
            ch_versions_percolator = ch_versions_percolator.mix(PERCOLATOR_RESCORING.out.versions)
        }

        ch_versions = ch_versions.mix(ch_versions_percolator)
    }

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

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'mspepident_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    /*
    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )
    */

    emit:
    //multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
