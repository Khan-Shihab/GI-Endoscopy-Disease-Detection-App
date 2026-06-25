"""
export_from_notebook.py

Your polyps.ipynb already saves clean state_dicts directly via
torch.save(global_model.state_dict(), path) at two points:

    {DATA_DIR}/best_polyp_model.pth        <- after SFU Phase 1
    {DATA_DIR}/best_polyp_model_ultra.pth  <- after SFU Phase 2 (use this one,
                                               it's the final/best checkpoint)

So there's no checkpoint-unwrapping needed. This script just copies the
ultra-fine-tuned weights into the backend's expected location and runs a
sanity check that they load against the exact inference architecture in
model_utils.py, so a mismatch is caught now instead of at server startup.

Usage:
    python export_from_notebook.py --source /path/to/best_polyp_model_ultra.pth
"""

import argparse
import os
import shutil

import torch
import torch.nn as nn
from torchvision import models

CLASS_NAMES = ["Polyp", "Polyp Normal"]
DEFAULT_SOURCE = (
    "/home/shihab/Documents/Programming/Thesis/Polyps_Image/best_polyp_model_ultra.pth"
)
OUTPUT_PATH = "backend/models/polyp_model.pth"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        default=DEFAULT_SOURCE,
        help="Path to best_polyp_model_ultra.pth (defaults to your DATA_DIR path)",
    )
    args = parser.parse_args()

    if not os.path.exists(args.source):
        raise FileNotFoundError(
            f"Couldn't find '{args.source}'. Pass the correct path with "
            "--source, e.g. --source /home/shihab/.../best_polyp_model_ultra.pth"
        )

    # Sanity check: load it against the exact same architecture model_utils.py
    # will use, so any mismatch surfaces here rather than at server startup.
    model = models.resnet50(weights=None)
    model.fc = nn.Linear(model.fc.in_features, len(CLASS_NAMES))
    state_dict = torch.load(args.source, map_location="cpu")
    model.load_state_dict(state_dict)
    print("Architecture check passed: weights load cleanly into ResNet50(2 classes).")

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    shutil.copy(args.source, OUTPUT_PATH)
    print(f"Copied to {OUTPUT_PATH} -- the backend will pick this up on startup.")


if __name__ == "__main__":
    main()
