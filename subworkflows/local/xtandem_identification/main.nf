// TODO nf-core: If in doubt look at other nf-core/subworkflows to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/subworkflows
//               You can also ask for help via your pull request or on the #subworkflows channel on the nf-core Slack workspace:
//               https://nf-co.re/join
// TODO nf-core: A subworkflow SHOULD import at least two modules

// Original file: mspepid/src/identification/xtandem_identification.nf
include { XTANDEM_ADJUST_PARAMS } from '../../../modules/local/xtandemadjustparams/main.nf'
include { XTANDEM_SEARCH        } from '../../../modules/local/xtandemsearch/main.nf'

workflow XTANDEM_IDENTIFICATION {

    take:
    ch_xtandem_config    // channel: path(xtandem_config_file)
    ch_fasta             // channel: path(fasta)
    ch_mzmls             // channel: [ val(meta), path(mzml) ]
    precursor_tol_ppm    // val: precursor tolerance in ppm
    fragment_tol_da      // val: fragment tolerance in Da

    main:
    ch_versions = channel.empty()

    // Create param file and taxonomy file for each mzML
    XTANDEM_ADJUST_PARAMS(
        ch_mzmls,
        ch_xtandem_config,
        ch_fasta,
        precursor_tol_ppm,
        fragment_tol_da
    )
    ch_versions = ch_versions.mix(XTANDEM_ADJUST_PARAMS.out.versions.first())

    // Perform X!Tandem search - combine each sample with shared taxonomy and fasta
    XTANDEM_SEARCH(
        XTANDEM_ADJUST_PARAMS.out.param_file
            .combine(XTANDEM_ADJUST_PARAMS.out.taxonomy_file.first())
            .combine(ch_fasta)
    )
    ch_versions = ch_versions.mix(XTANDEM_SEARCH.out.versions.first())

    emit:
    xml_files    = XTANDEM_SEARCH.out.xml       // channel: [ val(meta), path(xml) ]
    versions     = ch_versions                   // channel: [ versions.yml ]
}
