include { PERCOLATOR ; PERCOLATOR as MS2RESCORE_PERCOLATOR } from '../../../modules/nf-core/percolator/main'
include { MS2RESCORE_GETMODEL } from '../../../modules/local/ms2rescore/getmodel/main'
include { MS2RESCORE_RUNMS2RESCORE } from '../../../modules/local/ms2rescore/runms2rescore/main'
include { OKTOBERFEST_GENERATEFEATURES } from '../../../modules/local/oktoberfest/generatefeatures/main'

workflow SPECTRA_RESCORING {
    take:
    psmutils_tsvs
    searchengine_pins
    prepared_spectra
    fragment_tol_da
    run_percolator          // boolean: whether to run Percolator for rescoring
    run_ms2rescore          // boolean: whether to run MS2Rescore for rescoring
    run_oktoberfest         // boolean: whether to run Oktoberfest for rescoring
    ms2rescore_model        // string: which MS2Rescore model to use
    ms2rescore_model_dir    // string: optional directory containing pre-downloaded MS2PIP models

    main:
    ch_versions = channel.empty()

    // combine the mzML, raw spectra, and psm-utils files
    ch_prepared_spectra_by_id = prepared_spectra.map { meta, mzml, raw_spectra -> [meta.id, meta, mzml, raw_spectra] }
    ch_psmutils_tsvs_by_id = psmutils_tsvs.map { meta, psmutils_tsv -> [meta.id, meta, psmutils_tsv] }

    ch_rescoring_in = ch_prepared_spectra_by_id
        .combine(ch_psmutils_tsvs_by_id, by: 0)
        .map { _id, spectra_meta, mzml, raw_spectra, psm_meta, psmutils_tsv ->
            [spectra_meta + psm_meta + [outdir: psm_meta.searchengine], mzml, raw_spectra, psmutils_tsv]
        }
    ch_rescoring_out = channel.empty()

    // run percolator, if enabled
    if (run_percolator) {
        ch_percolator_in = searchengine_pins.map { meta, pin -> [meta + [outdir: meta.searchengine + "/percolator"], pin] }
        PERCOLATOR(
            ch_percolator_in
        )
        ch_rescoring_out = ch_rescoring_out
            .mix(PERCOLATOR.out.target_psms.map { meta, file -> [meta + [status: 'percolator_target'], file] })
            .mix(PERCOLATOR.out.decoy_psms.map { meta, file -> [meta + [status: 'percolator_decoy'], file] })
    }

    // run MS2Rescore, if enabled
    if (run_ms2rescore) {
        // check/download MS2Rescore model
        // TODO: allow models per sample (and download multiple models if needed)
        if (!ms2rescore_model_dir) {
            MS2RESCORE_GETMODEL(ms2rescore_model)
            ms2rescore_model_dir_val =  MS2RESCORE_GETMODEL.out.model_dir
        }
        else {
            ms2rescore_model_dir_val = channel.value(file(ms2rescore_model_dir, checkIfExists: true))
        }

        // TODO: make the setting of the model and fragment_tolerance per sample, not hardcoded for all runs
        ch_ms2rescore_in = ch_rescoring_in.map { meta, mzml, raw_spectra, psmutils_tsv ->
            [meta + [outdir: meta.searchengine + "/ms2rescore", ms2pip_model: ms2rescore_model, fragment_tol_da: fragment_tol_da], mzml, raw_spectra, psmutils_tsv]
        }
        MS2RESCORE_RUNMS2RESCORE(
            ch_ms2rescore_in,
            ms2rescore_model_dir_val,
        )
        ch_versions = ch_versions.mix(MS2RESCORE_RUNMS2RESCORE.out.versions)

        ch_percolator_ms2rescore_in = MS2RESCORE_RUNMS2RESCORE.out.pin.map { meta, pin ->
            [meta + [status: 'ms2rescore', outdir: meta.searchengine + "/ms2rescore"], pin]
        }
        MS2RESCORE_PERCOLATOR(
            ch_percolator_ms2rescore_in
        )
        ch_rescoring_out = ch_rescoring_out
            .mix(MS2RESCORE_PERCOLATOR.out.target_psms.map { meta, file -> [meta + [status: 'ms2rescore_target'], file] })
            .mix(MS2RESCORE_PERCOLATOR.out.decoy_psms.map { meta, file -> [meta + [status: 'ms2rescore_decoy'], file] })
    }

    // run Oktoberfest, if enabled
    if (run_oktoberfest) {

        // TODO: parameterize the oktoberfest models
        ch_oktoberfest_in = ch_rescoring_in.map { meta, mzml, raw_spectra, psmutils_tsv ->
            [meta + [outdir: meta.searchengine + "/oktoberfest", oktoberfest_intensity_model: "Prosit_2020_intensity_HCD", oktoberfest_irt_model: "Prosit_2019_irt", fragment_tol_da: fragment_tol_da], mzml, raw_spectra, psmutils_tsv]
        }

        OKTOBERFEST_GENERATEFEATURES(
            ch_oktoberfest_in,
        )
        ch_versions = ch_versions.mix(OKTOBERFEST_GENERATEFEATURES.out.versions)

    }

    emit:
    versions = ch_versions
    rescoring_out = ch_rescoring_out
}
