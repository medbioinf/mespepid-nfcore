#!/usr/bin/env python

# Copyright 2026 Julian Uszkoreit - MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

import platform
import logging
from importlib.metadata import version

from psm_utils.io import read_file, write_file

from ms2rescore.feature_generators.ms2pip import MS2PIPFeatureGenerator
from ms2rescore.feature_generators.deeplc import DeepLCFeatureGenerator


def format_yaml_like(data: dict, indent: int = 0) -> str:
    """Formats a dictionary to a YAML-like string.

    Args:
        data (dict): The dictionary to format.
        indent (int): The current indentation level.

    Returns:
        str: A string formatted as YAML.
    """
    yaml_str = ""
    for key, value in data.items():
        spaces = "  " * indent
        if isinstance(value, dict):
            yaml_str += f"{spaces}{key}:\\n{format_yaml_like(value, indent + 1)}"
        else:
            yaml_str += f"{spaces}{key}: {value}\\n"
    return yaml_str


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger("ms2rescore_run_chunked")
    logger.setLevel(logging.INFO)

    # parameters are passed from the main.nf script
    psm_filename = "${psms_file}"
    spectrafile = "${spectra_file}"
    out_file = "${out_file}"

    model = "${ms2pip_model}"
    model_dir = "${model_dir}"
    ms2_tolerance = float("${fragment_tol_da}")
    spectrum_id_pattern = "${spectrum_id_pattern}"
    processes = int("${task.cpus}")

    ms2pip_chunksize = int("${chunk_size}")

    logger.info(
        f"""Parameters:
        PSMs file: {psm_filename}
        Spectra file: {spectrafile}
        MS2PIP model: {model}
        MS2PIP model dir: {model_dir}
        MS2 tolerance: {ms2_tolerance}
        Spectrum ID pattern: {spectrum_id_pattern}
        Processes: {processes}
        MS2PIP chunk size: {ms2pip_chunksize}
        Output file: {out_file}
"""
    )

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
        model_dir=model_dir,
        processes=processes,
    )

    # go chunk-wise through the PSMs and add MS2PIP features
    chunk_start = 0
    while chunk_start < len(psm_list):
        psm_list_chunk = psm_list[
            chunk_start : (min(chunk_start + ms2pip_chunksize, len(psm_list)))
        ]
        ms2pip_fgen.add_features(psm_list_chunk)
        chunk_start = min(chunk_start + ms2pip_chunksize, len(psm_list))
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
        (set(psm.rescoring_features.keys()) == psm_list_feature_names)
        for psm in psm_list
    ]

    if psms_with_features.count(False) > 0:
        removed_psms = psm_list[[not psm for psm in psms_with_features]]
        missing_features = {
            feature_name
            for psm in removed_psms
            for feature_name in psm_list_feature_names
            - set(psm.rescoring_features.keys())
        }
        print(
            f"Removed {psms_with_features.count(False)} PSMs that were missing one or more rescoring feature(s), {missing_features}."
        )
        psm_list = psm_list[psms_with_features]

    # output the Percolator PIN file
    write_file(
        psm_list, out_file, filetype="percolator", feature_names=psm_list_feature_names
    )

    # output versions in YML file
    versions = {
        "${task.process}": {
            "python": platform.python_version(),
            "ms2rescore": version("ms2rescore"),
        }
    }
    with open("versions.yml", "w") as f:
        f.write(format_yaml_like(versions))
