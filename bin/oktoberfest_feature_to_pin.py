#!/usr/bin/env python

"""
Converts Oktoberfest feature files to Percolator's PIN file.
"""

import argparse
import logging
from pathlib import Path

import pandas as pd

COLS_TO_REMOVE = [
    "filename"  # str column
]
"""Columns to remove from the Oktoberfest feature file.
E.g. due to wrong type
"""

COLS_TO_RENAME = {
    "SpecId": "id",
}
"""Columns to rename in the Oktoberfest feature file.
"""


def argparse_setup() -> argparse.Namespace:
    """
    Creates the argument parser for the Oktoberfest feature generation script.
    """

    parser = argparse.ArgumentParser()
    # files
    parser.add_argument(
        "-in-file", help="Input feature TSV file", required=True, type=Path
    )
    parser.add_argument("-out-file", help="Pin file ", required=True, type=Path)

    return parser.parse_args()


def main():
    """
    Converts Oktoberfest feature files to Percolator's PIN file.
    """

    args = argparse_setup()
    logging.basicConfig(level=logging.INFO)

    # feature dataframe
    feature_df = pd.read_csv(args.in_file, sep="\t")

    for col in COLS_TO_REMOVE:
        if col in feature_df.columns:
            feature_df.drop(columns=col, inplace=True)

    for col, new_col in COLS_TO_RENAME.items():
        if col in feature_df.columns:
            feature_df.rename(columns={col: new_col}, inplace=True)

    for col in feature_df.columns:
        feature_df.rename(columns={col: col.lower()}, inplace=True)

    feature_df.to_csv(
        args.out_file,
        sep="\t",
        index=False,
    )

if __name__ == "__main__":
    main()
