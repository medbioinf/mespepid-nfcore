include { COMET } from '../../../modules/local/comet/main'

workflow SPECTRA_IDENTIFICATION {
    take:
    ch_fasta
    ch_samplesheet
    precursor_tol_ppm
    fragment_tol_da

    main:

    ch_versions = channel.empty()

    // TODO: this will become the identifications, probably with some meta mapping?
    ch_identifications = channel.empty()

    // prepare the input channel for identifications
    // TODO: this right now only adds the fasta - must be adapted for per sample DB
    // TODO: also adapt for per-sample parameters
    ch_ident_in = ch_samplesheet.combine(ch_fasta.map { _meta, fasta -> [fasta] })

    //TODO: only run if comet is activated
    COMET(
        ch_ident_in,
        precursor_tol_ppm,
        fragment_tol_da,
    )
    ch_versions = ch_versions.mix(COMET.out.versions_comet)
    ch_identifications = COMET.out.mzid

    emit:
    versions = ch_versions
    identifications = ch_identifications
}
