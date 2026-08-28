#!/usr/bin/env python

"""
Generates features for PSM-rescoring using Oktoberfest and formet the result int a Percolator PIN
The rescoring itself is suppressed by setting an unknown FDR estimation method.
Percolator or similar needs to be run afterwards.
"""

import copy
from functools import reduce
import json
import logging
from pathlib import Path
import re
from time import sleep
from typing import Union
import platform
from importlib.metadata import version

import oktoberfest as ok
from oktoberfest.runner import _preprocess, _ce_calib, _refinement_learn, _calculate_features
from oktoberfest.utils import Config, JobPool, ProcessStep
from oktoberfest import rescore as ok_re
from oktoberfest import preprocessing as ok_pp
import pandas as pd
import psm_utils
import psm_utils.io
import tritonclient


COLS_TO_REMOVE = [
    "filename",     # str column
    "lda_scores"    # the LDA score
]
"""Columns to remove from the Oktoberfest feature file.
E.g. due to wrong type or because they cause Percolator to perform weird
"""

COLS_TO_RENAME = {
    "SpecId": "id",
}
"""Columns to rename in the Oktoberfest feature file."""

OKTOBERFEST_RETRIES = 5
"""Number of retries for the oktberfest job in case of a server error."""

OKTOBERFEST_UNSUPPORTED_AMINO_ACIDS = {"U", "O"}
"""According to documentation, Oktoberfest does not support the amino acids U and O."""

OKTOBERFEST_MODIFICATION_REPLACEMENTS = [
    ("C[UNIMOD:Carbamidomethyl]", "C[UNIMOD:4]"),
    ("C-[UNIMOD:Carbamidomethyl]", "C[UNIMOD:4]"), # MaxQant-specific if C is last in sequence, PSM is annotated with C- instead of C
    ("M[UNIMOD:Oxidation]", "M[UNIMOD:35]"),
    ("M-[UNIMOD:Oxidation]", "M[UNIMOD:35]"), # MaxQant-specific if M is last in sequence, PSM is annotated with M- instead of M
]

def parse_str_bool(value: str) -> bool:
    """
    Parses a string argument to a boolean value.

    Arguments
    ---------
    value : str
        The string value to parse. Accepts 'true', 'false', '1', '

    Returns
    -------
    bool
        Returns True for 'true' or '1', and False for 'false' or '

    Raises
    ------
    ValueError
        If the value is not a valid boolean representation.
    """
    if value.lower() in ['true', '1']:
        return True
    elif value.lower() in ['false', '0']:
        return False
    else:
        raise ValueError(f"Invalid boolean value: {value}")

def get_scan_id(spectrum_id: str, scan_id_regex: re.Pattern) -> int:
    """
    Using the provided regex to extract the scan number from the spectrum ID.
    Arguments
    ---------
    spectrum_id : str
        The spectrum ID from which to extract the scan number.
    scan_id_regex : re.Pattern
        A compiled regular expression pattern to match the scan number.

    Returns
    -------
    int
        The extracted scan number as an integer.
    """
    match = scan_id_regex.match(spectrum_id)
    if not match:
        raise ValueError(f"Could not extract scan number from spectrum ID: {spectrum_id}")
    return int(match.group("scan_id"))


def feature_generation(config_path: Union[str, Path]):
    """
    Parts of Oktoberfest's [run_rescore-function without the rescoring step](https://github.com/wilhelm-lab/oktoberfest/blob/ce8d909ebf64aaaf9c0eebcc2bb33b9c4492ae90/oktoberfest/runner.py#L1238-L1312)
    with some renamed dependencies to avoid conflicts e.g. `re` => `ok_re` (for Oktoberfests rescoring module) to avoid conflicts with the built-in `re` module.

    Arguments
    ---------
    config_path : Union[str, Path]
        Path to the configuration file for Oktoberfest. This file should contain all necessary parameters for the
    """

    config = Config()
    config.read(config_path)
    config.check()

    # load spectra file names
    spectra_files = ok_pp.list_spectra(input_dir=config.spectra, input_format=config.spectra_type)

    proc_dir = config.output / "proc"
    proc_dir.mkdir(parents=True, exist_ok=True)

    spectra_files = _preprocess(spectra_files, config)

    # TODO is this the most elegant way to multi-thread CE calibration before running refinement learning?
    # Should we store the returned libraries and pass them to _calculate_features and _refinement_learn instead of
    # _ce_calib returning cached outputs?
    if config.num_threads > 1:
        processing_pool = JobPool(processes=config.num_threads)
        for spectra_file in spectra_files:
            _ = processing_pool.apply_async(_ce_calib, [spectra_file, config])
        processing_pool.check_pool()
    else:
        for spectra_file in spectra_files:
            _ = _ce_calib(spectra_file, config)

    if config.do_refinement_learning:
        _refinement_learn(spectra_files, config)

    if config.num_threads > 1:
        processing_pool = JobPool(processes=config.num_threads)
        for spectra_file in spectra_files:
            if "xl" in config.models["intensity"].lower():
                if "cms2" in config.models["intensity"].lower():
                    cms2 = True
                else:
                    cms2 = False
                processing_pool.apply_async(_calculate_features, [spectra_file, config], xl=True, cms2=cms2)
            else:
                processing_pool.apply_async(_calculate_features, [spectra_file, config])
        processing_pool.check_pool()
    else:
        for spectra_file in spectra_files:
            if "xl" in config.models["intensity"].lower():
                if "cms2" in config.models["intensity"].lower():
                    cms2 = True
                else:
                    cms2 = False
                _calculate_features(spectra_file, config, xl=True, cms2=cms2)
            else:
                _calculate_features(spectra_file, config)

    # prepare rescoring

    fdr_dir = config.output / "results" / config.fdr_estimation_method
    original_tab_files = [fdr_dir / spectra_file.with_suffix(".original.tab").name for spectra_file in spectra_files]
    rescore_tab_files = [fdr_dir / spectra_file.with_suffix(".rescore.tab").name for spectra_file in spectra_files]

    prepare_tab_original_step = ProcessStep(config.output, f"{config.fdr_estimation_method}_prepare_tab_original")
    prepare_tab_rescore_step = ProcessStep(config.output, f"{config.fdr_estimation_method}_prepare_tab_prosit")

    if not prepare_tab_original_step.is_done():
        logging.info("Merging input tab files for rescoring without peptide property prediction")
        ok_re.merge_input(tab_files=original_tab_files, output_file=fdr_dir / "original.tab")
        prepare_tab_original_step.mark_done()

    if not prepare_tab_rescore_step.is_done():
        logging.info("Merging input tab files for rescoring with peptide property prediction")
        ok_re.merge_input(tab_files=rescore_tab_files, output_file=fdr_dir / "rescore.tab")
        prepare_tab_rescore_step.mark_done()


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


def main():
    """
    Generates features for PSM-rescoring using Oktoberfest.
    The rescoring itself is suppresed by setting an unknown FDR estimation method.

    The resulting features can be found as `<output_folder>/none/rescore.tab`
    """

    logging.basicConfig(level=logging.INFO)

    # Regular expression to extract the scan number from the spectrum ID. Use `scan_id` for the matching group, e.g. `scan=(?P<scan_id>\\d+)`)
    scan_id_regex = re.compile("${scan_id_pattern}")

    oktoberfest_input_csv_path = Path("${psms_file}").with_suffix(".oktoberfest.input.csv")
    psms = psm_utils.io.read_file("${psms_file}")

    # Necessary columns according to the docs:
    # RAW_FILE,SCAN_NUMBER,MODIFIED_SEQUENCE,PRECURSOR_CHARGE,
    # SCAN_EVENT_NUMBER,MASS,SCORE,REVERSE,SEQUENCE,PEPTIDE_LENGTH
    oktoberfest_df = pd.DataFrame()

    # RAW_FILE,
    oktoberfest_df["RAW_FILE"] = [Path("${spectra_file}").stem] * len(psms)

    # SCAN_NUMBER
    oktoberfest_df["SCAN_NUMBER"] = [get_scan_id(psm.spectrum_id, scan_id_regex) for psm in psms]

    # MODIFIED_SEQUENCE
    oktoberfest_df["MODIFIED_SEQUENCE"] = [
        psm.peptidoform.modified_sequence for psm in psms
    ]
    # sequentially apply the replacements using functools.reduce
    oktoberfest_df["MODIFIED_SEQUENCE"] = oktoberfest_df["MODIFIED_SEQUENCE"].apply(
        lambda seq: reduce(
            lambda seq_x, repl: seq_x.replace(repl[0], repl[1]), # lambda to replace
            OKTOBERFEST_MODIFICATION_REPLACEMENTS, # replacements
            seq # starting with the sequences as stated in the PSMs file
        )
    )

    # PRECURSOR_CHARGE
    oktoberfest_df["PRECURSOR_CHARGE"] = [psm.get_precursor_charge() for psm in psms]

    # MASS
    oktoberfest_df["MASS"] = [psm.peptidoform.theoretical_mass for psm in psms]

    # SCORE
    oktoberfest_df["SCORE"] = [psm.score for psm in psms]

    # REVERSE
    oktoberfest_df["REVERSE"] = [psm.is_decoy for psm in psms]

    # SEQUENCE
    oktoberfest_df["SEQUENCE"] = [psm.peptidoform.sequence for psm in psms]

    # PEPTIDE_LENGTH
    oktoberfest_df["PEPTIDE_LENGTH"] = [len(psm.peptidoform.sequence) for psm in psms]

    # free up some memory
    del psms

    psms_df = pd.read_csv(Path("${psms_file}"), sep="\\t")

    # PROTEINS (not in the docs, but required by oktberfest)
    oktoberfest_df["PROTEINS"] = psms_df["protein_list"].apply(
        lambda x: x.replace("[", "").replace("]", "").replace("'", "")
    )  # remove the brackets and quotes

    # adding present rescoring columns
    present_rescoring_cols = list(
        filter(lambda x: x.startswith("rescoring:"), psms_df.columns)
    )
    for rescoring_col in present_rescoring_cols:
        oktoberfest_df[rescoring_col] = psms_df[rescoring_col]

    # free up some more memory as the dataframe is read fromt disk again
    del psms_df

    # Filter unsupported amino acids
    psms_len = len(oktoberfest_df)
    oktoberfest_df = oktoberfest_df[~oktoberfest_df["SEQUENCE"].str.contains("|".join(OKTOBERFEST_UNSUPPORTED_AMINO_ACIDS), regex=True)]
    if len(oktoberfest_df) < psms_len:
        logging.warning(
            "Removed %i PSMs with unsupported amino acids: %s", psms_len - len(oktoberfest_df), OKTOBERFEST_UNSUPPORTED_AMINO_ACIDS
        )

    # Some search engines do not provide protein accessions for decoys.
    # In this case, we set the PROTEINS column to the `PEP_<MODIFIED_SEQUENCE>` like in the ms2rescore.
    oktoberfest_df.replace({"PROTEINS": ""}, pd.NA, inplace=True)
    oktoberfest_df.fillna({"PROTEINS": "PEP_" + oktoberfest_df["MODIFIED_SEQUENCE"]}, inplace=True)
    oktoberfest_df.to_csv(
        oktoberfest_input_csv_path,
        sep=",",
        index=False,
    )

    # free up more memory
    del oktoberfest_df

    # create the config file
    config_dict = copy.deepcopy(ok.utils.example_configs.RESCORING)

    # misc
    config_dict["output"] = "${out_folder}"
    config_dict["numThreads"] = 1  # Set to 1 for debugging, can be increased later
    config_dict["prediction_server"] = "${prediction_server}"
    # mass spec parameters
    config_dict["massTolerance"] = float("${mass_tolerance}")
    config_dict["unitMassTolerance"] = "${mass_tolerance_unit}"
    config_dict["fragmentation_method"] = "CID"
    # predicition params
    config_dict["models"]["irt"] = "${irt_model}"
    config_dict["models"]["intensity"] = "${intensity_model}"
    # input params
    config_dict["inputs"]["search_results"] = str(oktoberfest_input_csv_path)
    config_dict["inputs"]["search_results_type"] = "Internal"
    config_dict["inputs"]["spectra"] = "${spectra_file}"
    config_dict["inputs"]["spectra_type"] = "mzml"
    # Setting this to none has the effect, that the generated features
    # are stored in the subfolder `results/none` of the output folder.
    config_dict["fdr_estimation_method"] = "NONE"
    config_dict["quantification"] = False
    config_dict["add_feature_cols"] = "all"

    config_path = Path("oktoberfest.config.json")

    with config_path.open("w", encoding="utf-8") as json_file:
        json_file.write(json.dumps(config_dict))

    is_successfull = False
    for _ in range(OKTOBERFEST_RETRIES):
        try:
            feature_generation(config_path)
            is_successfull = True
            break
        except tritonclient.utils.InferenceServerException as e:
            if str(e.status) == "504":
                logging.error("Koina server not available, retrying in 10 seconds...")
                sleep(10)
            else:
                logging.error("Oktoberfest job failed with an unexpected error: %s", e)
                raise

    if not is_successfull:
        logging.error("Oktoberfest job failed after multiple retries.")
        exit(101)


    # now, converts Oktoberfest feature files to Percolator's PIN file

    # feature dataframe
    features_file = f"{config_dict['output']}/results/none/rescore.tab"
    feature_df = pd.read_csv(features_file, sep="\\t")

    for col in COLS_TO_REMOVE:
        if col in feature_df.columns:
            feature_df.drop(columns=col, inplace=True)

    for col, new_col in COLS_TO_RENAME.items():
        if col in feature_df.columns:
            feature_df.rename(columns={col: new_col}, inplace=True)

    for col in feature_df.columns:
        feature_df.rename(columns={col: col.lower()}, inplace=True)

    feature_df.to_csv(
        "${prefix}.pin",
        sep="\\t",
        index=False,
    )


    # finally, output versions in YML file
    versions = {
        "${task.process}": {
            "python": platform.python_version(),
            "oktoberfest": version("oktoberfest"),
        }
    }
    with open("versions.yml", "w") as f:
        f.write(format_yaml_like(versions))

if __name__ == "__main__":
    main()
