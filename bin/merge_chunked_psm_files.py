#!/usr/bin/env python

import argparse
from psm_utils.io import read_file, write_file

#%%
# Argument parser
parser = argparse.ArgumentParser(description="Concatenate PSM files and update metadata.")
parser.add_argument(
    "--org_filebase",
    type=str,
    required=True,
    help="Original filename to set in the PSM metadata."
)
parser.add_argument(
    "--out_filename",
    type=str,
    required=True,
    help="The output filename for the merged TSV file."
)
parser.add_argument(
    "--files",
    type=str,
    nargs='+',
    required=True,
    help="List of PSM files to concatenate."
)
args = parser.parse_args()

org_filebase = args.org_filebase
out_filename = args.out_filename
files = args.files

#%% read in the separate PSM files
psm_list = None

for file in files:
    if psm_list is None:
        psm_list = read_file(file, filetype="tsv")
    else:
        for psm in read_file(file, filetype="tsv"):
            psm_list.append(psm)

# %% rename the runs in the PSMs
org_mzml_name = org_filebase + ".mzML"
for psm in psm_list:
    psm.run = org_mzml_name
    psm_list[0]['provenance_data']['mzid_filename'] = org_mzml_name

# %% write out the concatenated PSMs
write_file(psm_list, out_filename, filetype="tsv")
