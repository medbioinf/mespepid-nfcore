#!/usr/bin/env python

"""
This script performs some fine tuning in the initial psm_utils TSV file from the conversion of the
original search results.

The modifications (variable and fixed) are renamed to UniMod names and fixed modifications are
added, if not already present.
Scores are adjusted to -ln(score) if they are originally "lower score better" (i.e. e- or p-value
style).
Other minor fixes for some search engines are performed as well.
"""

import argparse
import math
from psm_utils.io import read_file, write_file

def argparse_setup():
    parser = argparse.ArgumentParser()
    parser.add_argument("-in_file", help="Input file name")
    parser.add_argument("-out_file", help="Output file name")
    parser.add_argument("-searchengine", help="The searchengine (only mandatory for comet, maxquant, msgfplus, msfragger)")

    return parser.parse_args()

if __name__ == "__main__":
    args = argparse_setup()

    psm_list = read_file(args.in_file)

    # rename some modifications to UniMod names (for all search engines)
    psm_list.rename_modifications({
        "Oxidation": "U:Oxidation",
        "Oxidation (M)": "U:Oxidation",
        "+15.9949": "U:Oxidation",
        "+15.99492": "U:Oxidation",
        "+15.994915": "U:Oxidation",
        "Carbamidomethyl": "U:Carbamidomethyl",
        "Carbamidomethyl (C)": "U:Carbamidomethyl",
        "+57.0215": "U:Carbamidomethyl",
        "+57.02147": "U:Carbamidomethyl",
        "+57.021465": "U:Carbamidomethyl",
        "Acetyl (Protein N-term)": "U:Acetylation",
    })

    # add fixed modification(s) for searchengines which wrongly do not include them
    if args.searchengine in ["comet", "maxquant"]:
        psm_list.add_fixed_modifications([("U:Carbamidomethyl", ["C"])])
        psm_list.apply_fixed_modifications()

    if(args.searchengine == "comet"):
        for psm in psm_list:
            # the score is usually "spec e-value", so use its -ln(score)
            psm["metadata"]["Comet:expectation value"] = -math.log(float(psm["metadata"]["Comet:expectation value"]))
    if (args.searchengine == "maxquant"):
        # we need to increase the spectrum_id by 1 and set "correct" empty proteins (for decoys)
        for psm in psm_list:
            psm["spectrum_id"] = int(psm["spectrum_id"]) + 1
            if psm["protein_list"] == None:
                psm["protein_list"] = []
    elif (args.searchengine == "msgfplus"):
        for psm in psm_list:
            # these scores are usually "spec e-value", so use their -ln(score)
            psm["score"] = -math.log(psm["score"])  # the MS-GF:SpecEValue
            psm["metadata"]["MS-GF:EValue"] = -math.log(float(psm["metadata"]["MS-GF:EValue"]))
    elif (args.searchengine == "msfragger"):
        for psm in psm_list:
            # the score is an "expect value", so use its -ln(score)
            psm["score"] = -math.log(float(psm["metadata"]["search_score_expect"]))    # use the search_score_expect here
            del psm["metadata"]["search_score_expect"]                          # ... and remove it from the metadata

    write_file(psm_list, args.out_file, filetype="tsv") 
