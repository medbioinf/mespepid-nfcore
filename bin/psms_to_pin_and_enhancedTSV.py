#!/usr/bin/env python

"""
This script calculates / adds all "rescoring" values to the psm_utils TSV file for usage by 
Percolater, Mokapot and also MS2rescore. Additionally, the PIN is written for usage by Percolator.

The "adjust_psm_list.py" script should be called before this script.
"""

import argparse
from psm_utils.io import read_file, write_file

def argparse_setup():
    parser = argparse.ArgumentParser()
    parser.add_argument("-in_file", help="Input file name")
    parser.add_argument("-out_file", help="Output tsv file (for MS2rescore)")
    parser.add_argument("-out_pin", help="Output PIN file (for percolator)")
    parser.add_argument("-use_only_rank1_psms", help="Output only PSMs with rank=1 (which still can be multiple per spectrum)", default="true")
    parser.add_argument("-searchengine", help="The searchengine (comet, maxquant, msaamanda, msfragger, msgfplus, sage, xtandem)")

    return parser.parse_args()


if __name__ == "__main__":
    args = argparse_setup()

    file = args.in_file
    outfile = args.out_file
    outpin = args.out_pin
    searchengine = args.searchengine

    decoy_prefix = "DECOY_"
    decoy_needs_adjustment = False

    # read results
    psm_list = read_file(file, filetype="tsv")

    # Features:
    # - ExpMass         experimental mass (precursor m/z)
    # - CalcMass        calculated mass (theoretical m/z)			
    # - dM              Difference between theoretical and observed precursor mass
    # - absdM           Absolute difference between theoretical and observed precursor mass
    # - Mass	        theoretical mass of peptide (with modifications etc.) 
    # - PepLen          Peptide length
    #
    # - ChargeN         Precursor charge state
    # - Charge1	        one hot encoding of charge state 1
    # - Charge2         one hot encoding of charge state 2
    # - Charge3         one hot encoding of charge state 3
    # - Charge4         one hot encoding of charge state 4
    # - Charge5         one hot encoding of charge state 5
    # - Charge6         one hot encoding of charge state 6
    # - Charge7         one hot encoding of charge state 7
    #
    # - scores          either score or -ln(score) (if p- or e-value style)

    score_mapping = {}
    if searchengine == "comet":
        score_mapping = {
            "score": "comet_xcorr",
            "metadata": {
                "Comet:deltacn": "comet_deltacn",
                "Comet:spscore": "comet_spscore",
                "Comet:sprank": "comet_sprank",
                "Comet:expectation value": "neg_ln_comet_expectation_value",
                },
        }
    elif searchengine == "maxquant":
        score_mapping = {
            "score": "maxquant_Score",
        }
    elif searchengine == "msamanda":
        score_mapping = {
            "score": "amanda_score",
            "rescoring": {
                "binom score": "amanda_binom_score",
                },
        }
        decoy_needs_adjustment = True
    elif searchengine == "msfragger":
        score_mapping = {
            "score": "neg_ln_msfragger_expect",
            "metadata": {
                "search_score_hyperscore": "msfragger_hyperscore",
                "search_score_nextscore": "msfragger_nextscore"
                },
        }
    elif searchengine == "msgfplus":
        score_mapping = {
            "score": "ln_msgf_specevalue",
            "metadata": {
                "MS-GF:RawScore": "msgf_rawscore",
                "MS-GF:DeNovoScore": "msgf_denovoscore",
                "MS-GF:EValue": "neg_ln_msgf_evalue",
                },
        }
    elif searchengine == "sage":
        score_mapping = {
            "score": "sage_discriminant_score",
            "rescoring": {
                "hyperscore": "sage_hyperscore",
                },
        }
    elif searchengine == "xtandem":
        score_mapping = {
            "score": "neg_ln_xtandem_expect",       # is already -ln(value) by default loading
            "metadata": {
                "xtandem_hyperscore": "xtandem_hyperscore",
                "xtandem_delta": "xtandem_delta",
                "xtandem_nextscore": "xtandem_nextscore",
                },
        }

    #%% adjust features
    for psm in psm_list:
        # add features and scores to the rescoring features
        rescoring_features = {
            'ExpMass': psm.precursor_mz,
            'CalcMass': psm.peptidoform.theoretical_mz,
            'dM' : psm.precursor_mz_error,
            'absdM': abs(psm.precursor_mz_error),
            'Mass': psm.peptidoform.theoretical_mass,
            'PepLen': len(psm.peptidoform.sequence),
            'ChargeN': psm.peptidoform.precursor_charge,
            'Charge1': 1 if psm.peptidoform.precursor_charge == 1 else 0,
            'Charge2': 1 if psm.peptidoform.precursor_charge == 2 else 0,
            'Charge3': 1 if psm.peptidoform.precursor_charge == 3 else 0,
            'Charge4': 1 if psm.peptidoform.precursor_charge == 4 else 0,
            'Charge5': 1 if psm.peptidoform.precursor_charge == 5 else 0,
            'Charge6': 1 if psm.peptidoform.precursor_charge == 6 else 0,
            'Charge7': 1 if psm.peptidoform.precursor_charge == 7 else 0
        }

        rescoring_features[score_mapping["score"]] = psm.score

        if "metadata" in score_mapping.keys():
            for key, value in score_mapping["metadata"].items():
                rescoring_features[value] = float(psm.metadata[key])
        
        if "rescoring" in score_mapping.keys():
            for key, value in score_mapping["rescoring"].items():
                rescoring_features[value] = float(psm.rescoring_features[key])
        
        psm.rescoring_features = rescoring_features

        # if decoy is not set -> set it to True (will be adjusted immediately)
        if psm.is_decoy == None or decoy_needs_adjustment:
            psm.is_decoy = True
        
        # adjust decoys: only mark as decoy, if all proteins are decoys
        if psm.is_decoy:
            if psm.protein_list is not None and psm.protein_list != []:
                for protein in psm.protein_list:
                    if not protein.startswith(decoy_prefix):
                        psm.is_decoy = False
                        break

    # %%
    if args.use_only_rank1_psms.lower() == "true":
        psm_list.set_ranks(lower_score_better=False)
        psm_list = psm_list.get_rank1_psms()
    
    psm_list.calculate_qvalues()
    write_file(psm_list, outfile, filetype="tsv")

    #%%
    percolator_features = list(psm_list[0].rescoring_features.keys())
    write_file(psm_list, outpin, filetype="percolator", feature_names=percolator_features)
