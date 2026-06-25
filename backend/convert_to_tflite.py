"""
convert_to_tflite.py

Converts the ONNX model (exported by convert_to_onnx.py) into a
quantized TensorFlow Lite model for ON-DEVICE inference in Flutter --
i.e. no backend server required at all.

Pipeline: PyTorch -> ONNX -> TensorFlow SavedModel -> TFLite

Install (separate from backend requirements, only needed for this
one-time conversion step):
    pip install onnx onnx-tf tensorflow

Usage:
    python convert_to_tflite.py
"""

import onnx
import tensorflow as tf
from onnx_tf.backend import prepare

ONNX_PATH = "backend/models/polyp_model.onnx"
SAVEDMODEL_DIR = "backend/models/saved_model_tf"
TFLITE_OUTPUT_PATH = "flutter_app/assets/models/polyp_model.tflite"

# 1. ONNX -> TensorFlow SavedModel
onnx_model = onnx.load(ONNX_PATH)
tf_rep = prepare(onnx_model)
tf_rep.export_graph(SAVEDMODEL_DIR)

# 2. TensorFlow SavedModel -> TFLite, with dynamic-range quantization
#    to shrink model size for mobile (roughly 4x smaller, minor accuracy
#    trade-off). Drop the optimizations line for a full-precision model.
converter = tf.lite.TFLiteConverter.from_saved_model(SAVEDMODEL_DIR)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

import os

os.makedirs(os.path.dirname(TFLITE_OUTPUT_PATH), exist_ok=True)
with open(TFLITE_OUTPUT_PATH, "wb") as f:
    f.write(tflite_model)

print(f"Exported TFLite model to {TFLITE_OUTPUT_PATH}")
print(
    "Next step: bundle this file as a Flutter asset and run inference "
    "with the tflite_flutter package -- no server round-trip needed. "
    "Note: you'll need to reimplement Grad-CAM-style highlighting "
    "on-device too, or simplify to just returning a bounding box / "
    "confidence score without the heatmap overlay."
)
