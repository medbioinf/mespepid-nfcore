#!/usr/bin/env python

import argparse
import logging
from pathlib import Path

from psm_utils.io import read_file, write_file

from ms2rescore.feature_generators.ms2pip import MS2PIPFeatureGenerator
from ms2rescore.feature_generators.deeplc import DeepLCFeatureGenerator


def argparse_setup():
    parser = argparse.ArgumentParser()
    parser.add_argument("-psms_file", help="Input PSMs TSV file", required=True, type=argparse.FileType('r'))
    parser.add_argument("-spectra", help="Corresponding mzML file or .d path for PSMs file", required=True, type=str)

    parser.add_argument("-model", help="Model for MS2PIP", default="HCD", type=str)
    parser.add_argument("-model_dir", help="Directory to store/find MS2PIP model", required=True, type=str)
    parser.add_argument("-ms2_tolerance", help="The MS2/fragment tolerance", default=0.02, type=float)
    parser.add_argument("-spectrum_id_pattern", help="The spectrum ID pattern to correspond PSMs to spectra", default="(.*)", type=str)
    parser.add_argument("-processes", help="Number of processes / threads to use", default=8, type=int)

    parser.add_argument("-chunk_size", help="Number of PSMs per chunk (for MS2PIP), if <1 use all", default=100000, type=int)

    parser.add_argument("-out_file", help="Output Percolator PIN file", required=True, type=argparse.FileType('w'))

    return parser.parse_args()

if __name__ == "__main__":
    args = argparse_setup()
    logging.basicConfig(level=logging.INFO)

    model = args.model
    model_dir = Path(args.model_dir)

    # Enforce the contract
    if not model_dir.exists() or not model_dir.is_dir():
        raise RuntimeError(
            f"MS2PIP model directory does not exist: {model_dir}. "
            "It must be created by the Nextflow workflow."
        )

    logging.info(f"Using MS2PIP model directory: {model_dir}")


    psm_filename = args.psms_file.name
    spectrafile = args.spectra

    ms2_tolerance = args.ms2_tolerance
    spectrum_id_pattern = args.spectrum_id_pattern #r".*scan=(\d+)$"
    processes = args.processes

    ms2pip_chunksize = args.chunk_size

    # read in the PSMs
    psm_list = read_file(psm_filename, filetype="tsv")
    print(f"Read in PSM file with {len(psm_list)} PSMs")
    if ms2pip_chunksize < 1:
        ms2pip_chunksize = len(psm_list)

    # initialize the MS2PIP feature generator
    ms2pip_fgen = MS2PIPFeatureGenerator(
        model=model,
        ms2_tolerance=ms2_tolerance,
        spectrum_path=spectrafile,
        spectrum_id_pattern=spectrum_id_pattern,
        model_dir=str(model_dir),
        processes=processes
    )

    # go chunk-wise through the PSMs and add MS2PIP features
    chunk_start = 0
    while chunk_start < len(psm_list):
        psm_list_chunk = psm_list[chunk_start:(min(chunk_start+ms2pip_chunksize, len(psm_list)))]
        ms2pip_fgen.add_features(psm_list_chunk)
        chunk_start = min(chunk_start+ms2pip_chunksize, len(psm_list))
        print(f"Done adding MS2PIP features for {chunk_start} / {len(psm_list)} PSMs")
    
    # initialie the DeepLC feature generator
    deeplc_fgen = DeepLCFeatureGenerator(
        lower_score_is_better=False,
        calibration_set_size=0.15,
        spectrum_path=None,
        processes=processes,
        deeplc_retrain=False,
    )

    # add DeepLC features to the PSMs
    deeplc_fgen.add_features(psm_list)
    
    
    psm_list_feature_names = {
        feature_name
        for psm_list_features in psm_list["rescoring_features"]
        for feature_name in psm_list_features.keys()
    }

    # remove PSMs with missing features
    psms_with_features = [
        (set(psm.rescoring_features.keys()) == psm_list_feature_names) for psm in psm_list
    ]

    if psms_with_features.count(False) > 0:
        removed_psms = psm_list[[not psm for psm in psms_with_features]]
        missing_features = {
            feature_name
            for psm in removed_psms
            for feature_name in psm_list_feature_names - set(psm.rescoring_features.keys())
        }
        print(f"Removed {psms_with_features.count(False)} PSMs that were missing one or more rescoring feature(s), {missing_features}.")
        psm_list = psm_list[psms_with_features]

    # output the Percolator PIN file
    write_file(psm_list, args.out_file.name, filetype="percolator", feature_names=psm_list_feature_names)
