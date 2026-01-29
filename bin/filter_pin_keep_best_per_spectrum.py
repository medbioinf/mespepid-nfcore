#!/usr/bin/env python

"""
Sorts the given PIN by the search engine's score (respectively the given score) and keeps only the best scoring PSM for each ScanNr / spectrum.
"""

import argparse
import pandas as pd
import percolator_file_functions as pff

def argparse_setup():
    parser = argparse.ArgumentParser()
    parser.add_argument("-in_file", help="the input PIN file")
    parser.add_argument("-out_pin", help="Output PIN file")
    parser.add_argument("-searchengine", help="The search engine used to generate the PIN file", default=None)
    parser.add_argument("-mainscore", help="The main score (if searchengine is given, it is guessed automatically)", default=None)

    return parser.parse_args()


if __name__ == "__main__":
    args = argparse_setup()

    pin_df = pff.parse_percolator_pin(args.in_file)

    searchengine = args.searchengine
    if searchengine is None:
        se_score = args.mainscore
    elif searchengine == "comet":
        se_score = "neg_ln_comet_expectation_value"
    elif searchengine == "maxquant":
        se_score = "maxquant_Score"
    elif searchengine == "msamanda":
        se_score = "amanda_score"
    elif searchengine == "msfragger":
        se_score = "neg_ln_msfragger_expect"
    elif searchengine == "msgfplus":
        se_score = "ln_msgf_specevalue"
    elif searchengine == "sage":
        se_score = "sage_discriminant_score"
    elif searchengine == "xtandem":
        se_score = "neg_ln_xtandem_expect"
    
    pin_df[se_score] = pd.to_numeric(pin_df[se_score])
    pin_df.sort_values(by=[se_score], ascending=[False], inplace=True)
    
    # keep only the best scoring PSM for each ScanNr
    pin_df.drop_duplicates(subset=["ScanNr"], keep="first", inplace=True)

    pff.write_percolator_pin_file(pin_df, args.out_pin)
