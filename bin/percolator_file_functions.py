# some functions for the parsing of percolator files
import pandas as pd


def parse_percolator_tsv(filename: str) -> pd.DataFrame:
    """
    Reads in the given percolator TSV file as a DataFrame (can be pin or pout, index is not set accordingly)
    """
    line_count = 0
    headers = []
    nr_headers = 0
    lines_list = list()
    with open(filename) as fp:
        for line in fp:
            if line_count == 0:
                # parse the headers first
                splitline = str(line).strip().split("\t")
                headers = splitline
                nr_headers = len(headers)
                line_count += 1
            else:
                splitline = str(line).strip().split("\t", maxsplit=nr_headers - 1)
                splitline[nr_headers - 1] = splitline[nr_headers - 1].split("\t")
                lines_list.append(splitline)

    df_perc = pd.DataFrame(data=lines_list, columns=headers)

    return df_perc


def parse_percolator_pin(filename: str) -> pd.DataFrame:
    """
    Reads in the given percolator pin file as a DataFrame
    """
    df_perc = parse_percolator_tsv(filename)

    # set correct index and data types
    df_perc["SpecId"] = pd.to_numeric(df_perc["SpecId"])
    df_perc.set_index("SpecId", inplace=True, drop=False)
    df_perc["Label"] = pd.to_numeric(df_perc["Label"])
    df_perc["ScanNr"] = pd.to_numeric(df_perc["ScanNr"])

    return df_perc


def parse_percolator_pout(filename: str) -> pd.DataFrame:
    """
    Reads in the given percolator pout file as a DataFrame.
    """
    df_perc = parse_percolator_tsv(filename)

    # set correct index and data types
    df_perc["PSMId"] = pd.to_numeric(df_perc["PSMId"])
    df_perc.set_index("PSMId", inplace=True, drop=False)
    df_perc["score"] = pd.to_numeric(df_perc["score"])
    df_perc["q-value"] = pd.to_numeric(df_perc["q-value"])
    df_perc["posterior_error_prob"] = pd.to_numeric(df_perc["posterior_error_prob"])

    return df_perc


def read_enriched_pout_with_pin_data(pout_file: str, pin_file: str) -> pd.DataFrame:
    """
    Reads in a Percolator pout file and enriches it with the data from the corresponding pin file
    """
    pin_df = parse_percolator_pin(pin_file)
    pout_df = parse_percolator_pout(pout_file)

    return pout_df.merge(
        pin_df,
        how="left",
        left_index=True,
        right_index=True,
        suffixes=("_pout", "_pin"),
    )[
        [
            "PSMId",
            "ScanNr",
            "score",
            "q-value",
            "posterior_error_prob",
            "peptide",
            "proteinIds",
        ]
    ]


def read_and_filter_pout_file(
    pout_file: str,
    pin_file: str,
    qvalue_thr: float = 0.01,
    remove_duplicates: bool = True,
) -> pd.DataFrame:
    """
    Reads in a Percolator pout file, enriches it with data from the corresponding pin file and filters it by the given q-value threshold.
    After this, the DataFrame is sorted by the q-value and, if selected, spectra with duplicated identifications are removed (keeping only the first/best identification per spectrum).
    """
    perc_df = read_enriched_pout_with_pin_data(pout_file, pin_file)
    perc_df = perc_df[(perc_df["q-value"] < qvalue_thr)]

    perc_df.sort_values(by=["q-value", "score"], ascending=[True, False], inplace=False)

    if remove_duplicates:
        perc_df.drop_duplicates(subset=["ScanNr"], inplace=True, keep="first")

    return perc_df


def write_percolator_pin_file(perc_df: pd.DataFrame, outfile: str):
    """
    Writes the given DataFrame to a Percolator pin file.
    """

    perc_df["Proteins"] = perc_df["Proteins"].apply(lambda x: "\t".join(x))
    perc_df.to_csv(outfile, sep="\t", index=False, header=True)
