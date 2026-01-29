#!/usr/bin/env python

import argparse
import pyteomics.fasta

def argparse_setup():
    parser = argparse.ArgumentParser()
    parser.add_argument("-in_file", help="Input FASTA file", required=True)
    parser.add_argument("-out_file_base", help="Output file base name", required=True)
    parser.add_argument("-splits", help="Number of splits for the FASTA file", type=int, default=10)

    return parser.parse_args()

if __name__ == "__main__":
    args = argparse_setup()

    fastafile = args.in_file
    splitfile_base = args.out_file_base
    
    n_split = int(args.splits)

    prot_file_count = 0
    for acc, seq in pyteomics.fasta.read(fastafile):

        split_filename = splitfile_base + "-" + str(prot_file_count) + ".fasta"
        with open(split_filename, 'a') as fasta_writer:
            fasta_writer.write(f">{acc}\n")
            while seq:
                fasta_writer.write(f"{seq[:60]}\n")
                seq = seq[60:]

        prot_file_count = (prot_file_count + 1) % n_split

    print(f"Done splitting FASTA file into {n_split} files.")
