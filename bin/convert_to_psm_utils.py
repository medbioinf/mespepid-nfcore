#!/usr/bin/env python

import argparse
from psm_utils.io import convert

def argparse_setup():
    parser = argparse.ArgumentParser()
    parser.add_argument("-in_file", help="Input file name")
    parser.add_argument("-out_file", help="Output file name")
    parser.add_argument("-in_type", help="The input file type")

    return parser.parse_args()

if __name__ == "__main__":
    args = argparse_setup()

    convert(input_filename=args.in_file, output_filename=args.out_file,
            input_filetype=args.in_type, output_filetype="tsv")
