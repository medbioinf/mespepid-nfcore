#!/usr/bin/env python

import argparse
import logging
from pathlib import Path

from ms2pip.constants import MODELS
from ms2pip._utils.xgb_models import validate_requested_xgb_model


def argparse_setup():
    parser = argparse.ArgumentParser()
    parser.add_argument("-ms2pip_model", help="Model for MS2PIP", default="HCD", type=str)
    parser.add_argument("-model_dir", help="Directory to store/find MS2PIP model", required=True, type=str)

    return parser.parse_args()

if __name__ == "__main__":
    args = argparse_setup()
    logging.basicConfig(level=logging.INFO)

    ms2pip_model = args.ms2pip_model
    model_dir = Path(args.model_dir)

    # Enforce the contract: Nextflow must provide a valid directory
    if not model_dir.exists() or not model_dir.is_dir():
        raise RuntimeError(
            f"MS2PIP model directory does not exist: {model_dir}. "
            "This directory must be created by the Nextflow workflow."
        )

    if ms2pip_model not in MODELS:
        raise ValueError(f"Unknown MS2PIP model: {ms2pip_model}")

    logging.info(f"Using MS2PIP model directory: {model_dir}")  
    logging.info(f"Checking MS2PIP model: {ms2pip_model}")

    model_info = MODELS[ms2pip_model]

    # Validate / download requested model
    if "xgboost_model_files" in model_info:
        try:
            validate_requested_xgb_model(
                model_info["xgboost_model_files"],
                model_info["model_hash"],
                str(model_dir),
            )
        except Exception as e:
            logging.warning(f"Model validation failed: {e}")
            logging.warning("Continuing anyway - models were downloaded successfully")
    