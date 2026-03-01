#!/usr/bin/env python3
"""Download the pre-trained ONNX orientation detection model from HuggingFace."""

import os
import urllib.request
from pathlib import Path

MODEL_URL = (
    "https://huggingface.co/DuarteBarbosa/deep-image-orientation-detection"
    "/resolve/main/orientation_model_v2_0.9882.onnx"
)
MODEL_DIR = Path(__file__).parent / "models"
MODEL_PATH = MODEL_DIR / "orientation_model.onnx"


def download():
    MODEL_DIR.mkdir(parents=True, exist_ok=True)

    if MODEL_PATH.exists():
        size_mb = MODEL_PATH.stat().st_size / (1024 * 1024)
        print(f"Model already exists at {MODEL_PATH} ({size_mb:.1f} MB)")
        return

    print(f"Downloading model from HuggingFace...")
    print(f"  URL:  {MODEL_URL}")
    print(f"  Dest: {MODEL_PATH}")

    urllib.request.urlretrieve(MODEL_URL, str(MODEL_PATH))

    size_mb = MODEL_PATH.stat().st_size / (1024 * 1024)
    print(f"Done! ({size_mb:.1f} MB)")


if __name__ == "__main__":
    download()
