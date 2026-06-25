"""
convert_to_onnx.py

Converts the trained PyTorch model to ONNX format.

Two reasons you'd want this:
  1. Faster, framework-agnostic CPU inference on the FastAPI server
     (via onnxruntime instead of raw PyTorch).
  2. A stepping stone toward TensorFlow Lite for on-device inference
     in Flutter (ONNX -> TensorFlow -> TFLite, see convert_to_tflite.py).

Usage:
    python convert_to_onnx.py
"""

import torch
import torch.nn as nn
from torchvision import models

CLASS_NAMES = ["Polyp", "Polyp Normal"]  # index 0 = Polyp, matches the notebook
WEIGHTS_PATH = "backend/models/polyp_model.pth"
ONNX_OUTPUT_PATH = "backend/models/polyp_model.onnx"
IMAGE_SIZE = 224

model = models.resnet50(weights=None)
model.fc = nn.Linear(model.fc.in_features, len(CLASS_NAMES))
model.load_state_dict(torch.load(WEIGHTS_PATH, map_location="cpu"))
model.eval()

dummy_input = torch.randn(1, 3, IMAGE_SIZE, IMAGE_SIZE)

torch.onnx.export(
    model,
    dummy_input,
    ONNX_OUTPUT_PATH,
    export_params=True,
    opset_version=13,
    input_names=["input"],
    output_names=["output"],
    dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}},
)

print(f"Exported ONNX model to {ONNX_OUTPUT_PATH}")

# --------------------------------------------------------------------
# Sanity check: run inference with onnxruntime and compare to PyTorch
# --------------------------------------------------------------------
import onnxruntime as ort
import numpy as np

session = ort.InferenceSession(ONNX_OUTPUT_PATH)
onnx_output = session.run(None, {"input": dummy_input.numpy()})[0]

with torch.no_grad():
    torch_output = model(dummy_input).numpy()

print("Max difference between PyTorch and ONNX outputs:",
      np.abs(onnx_output - torch_output).max())
