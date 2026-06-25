"""
model_utils.py
Handles model loading, preprocessing, inference, and Grad-CAM-based
annotation for the polyp detection backend.

Matches the architecture trained in polyps.ipynb: ResNet50 backbone,
2-class linear head, trained via federated learning (FedAvg across 3
clients) with staged unfreezing (SFU Phase 1 -> SFU Phase 2). Only the
final global_model weights matter for inference -- the federated
training process itself has no bearing on how the saved model is
loaded or run here.
"""

import io
import base64
from typing import Tuple

import cv2
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from torchvision import models, transforms

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
MODEL_PATH = "models/best_gi_model_phase1.pth"

# ImageFolder sorts class folder names alphabetically, so the order is:
#   0 = "GERD"
#   1 = "GERD Normal"
#   2 = "Polyp"
#   3 = "Polyp Normal"
# "Detected" means the model predicted a pathological class (GERD or Polyp),
# i.e. any class whose name does NOT end with "Normal".
CLASS_NAMES = ["GERD", "GERD Normal", "Polyp", "Polyp Normal"]
PATHOLOGICAL_CLASSES = {"GERD", "Polyp"}  # detected = abnormal finding

IMAGE_SIZE = 224  # matches IMG_SIZE in the notebook

# Exact ImageNet normalization used in get_data_transforms() in the notebook.
NORMALIZE_MEAN = [0.485, 0.456, 0.406]
NORMALIZE_STD = [0.229, 0.224, 0.225]

preprocess_transform = transforms.Compose(
    [
        transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize(mean=NORMALIZE_MEAN, std=NORMALIZE_STD),
    ]
)


class InvalidImageError(Exception):
    """Raised when the uploaded file isn't a readable image."""


class ModelInferenceError(Exception):
    """Raised when the model fails to run inference."""


# --------------------------------------------------------------------------
# Model handler
# --------------------------------------------------------------------------


class PolypModelHandler:
    """
    Loads the trained model once at startup and exposes a single
    `predict()` method that returns classification + an annotated image.

    Designed around a ResNet50 classifier with Grad-CAM, since that
    matches a typical "Detected / Not Detected" binary polyp classifier
    exported from a notebook. If your model is an object detector
    (e.g. YOLOv8) instead, see `predict_with_bounding_boxes()` below.
    """

    def __init__(self, model_path: str = MODEL_PATH):
        self.model = self._load_model(model_path)
        self.model.eval()
        self.model.to(DEVICE)

        # Hook the last conv block for Grad-CAM (ResNet50 -> layer4)
        self._gradients = None
        self._activations = None
        target_layer = self.model.layer4[-1]
        target_layer.register_forward_hook(self._save_activation)
        target_layer.register_full_backward_hook(self._save_gradient)

    def _load_model(self, model_path: str) -> nn.Module:
        try:
            model = models.resnet50(weights=None)
            in_feats = model.fc.in_features
            # Must match the Sequential head defined in the notebook:
            #   fc.0 = BatchNorm1d, fc.1 = Dropout (no params), fc.2 = Linear
            model.fc = nn.Sequential(
                nn.BatchNorm1d(in_feats),
                nn.Dropout(p=0.4),
                nn.Linear(in_feats, len(CLASS_NAMES)),
            )
            state_dict = torch.load(model_path, map_location=DEVICE)
            # Handles checkpoints saved as {"model_state_dict": ...} too
            if "model_state_dict" in state_dict:
                state_dict = state_dict["model_state_dict"]
            model.load_state_dict(state_dict)
            return model
        except FileNotFoundError as exc:
            raise ModelInferenceError(
                f"Model weights not found at '{model_path}'. "
                "Export your trained model from the notebook first "
                "(see convert_to_onnx.py / README for guidance)."
            ) from exc
        except Exception as exc:  # malformed checkpoint, arch mismatch, etc.
            raise ModelInferenceError(f"Failed to load model: {exc}") from exc

    def _save_activation(self, module, inp, output):
        self._activations = output.detach()

    def _save_gradient(self, module, grad_input, grad_output):
        self._gradients = grad_output[0].detach()

    # ----------------------------------------------------------------
    # Public API
    # ----------------------------------------------------------------

    def predict(self, image_bytes: bytes) -> dict:
        """
        Run classification + Grad-CAM on raw image bytes.
        Returns a dict ready to be serialized as the API response.
        """
        pil_image = self._bytes_to_image(image_bytes)
        input_tensor = preprocess_transform(pil_image).unsqueeze(0).to(DEVICE)
        input_tensor.requires_grad_(True)

        try:
            logits = self.model(input_tensor)
            probabilities = F.softmax(logits, dim=1)
            confidence, predicted_idx = torch.max(probabilities, dim=1)
            predicted_idx = predicted_idx.item()
            confidence = confidence.item()

            # Backprop on the predicted class to get Grad-CAM weights
            self.model.zero_grad()
            logits[0, predicted_idx].backward()
            heatmap = self._compute_gradcam()

        except Exception as exc:
            raise ModelInferenceError(f"Inference failed: {exc}") from exc

        annotated_b64 = self._overlay_heatmap(pil_image, heatmap)
        original_b64 = self._image_to_base64(pil_image)

        predicted_class = CLASS_NAMES[predicted_idx]
        detected = predicted_class in PATHOLOGICAL_CLASSES
        return {
            "status": predicted_class,           # e.g. "Polyp", "GERD", "Polyp Normal"
            "is_polyp_detected": detected,        # True for any pathological finding
            "confidence": round(confidence * 100, 2),
            "original_image": original_b64,
            "annotated_image": annotated_b64,
        }

    # ----------------------------------------------------------------
    # Internals
    # ----------------------------------------------------------------

    def _compute_gradcam(self) -> np.ndarray:
        gradients = self._gradients[0]  # (C, H, W)
        activations = self._activations[0]  # (C, H, W)
        weights = gradients.mean(dim=(1, 2))  # global-average-pool gradients

        cam = torch.zeros(activations.shape[1:], dtype=torch.float32, device=DEVICE)
        for i, w in enumerate(weights):
            cam += w * activations[i]

        cam = F.relu(cam)
        cam = cam - cam.min()
        cam = cam / (cam.max() + 1e-8)
        return cam.cpu().numpy()

    def _overlay_heatmap(self, pil_image: Image.Image, heatmap: np.ndarray) -> str:
        img = np.array(pil_image.resize((IMAGE_SIZE, IMAGE_SIZE)))
        heatmap_resized = cv2.resize(heatmap, (IMAGE_SIZE, IMAGE_SIZE))
        heatmap_uint8 = np.uint8(255 * heatmap_resized)
        heatmap_color = cv2.applyColorMap(heatmap_uint8, cv2.COLORMAP_JET)
        heatmap_color = cv2.cvtColor(heatmap_color, cv2.COLOR_BGR2RGB)

        overlay = cv2.addWeighted(img, 0.6, heatmap_color, 0.4, 0)
        overlay_pil = Image.fromarray(overlay)
        return self._image_to_base64(overlay_pil)

    @staticmethod
    def _bytes_to_image(image_bytes: bytes) -> Image.Image:
        try:
            image = Image.open(io.BytesIO(image_bytes))
            image.verify()  # raises if corrupted
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
            return image
        except Exception as exc:
            raise InvalidImageError(
                "Uploaded file is not a valid image (corrupted or unsupported format)."
            ) from exc

    @staticmethod
    def _image_to_base64(image: Image.Image) -> str:
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG", quality=90)
        return base64.b64encode(buffer.getvalue()).decode("utf-8")


# --------------------------------------------------------------------------
# Optional enhancement: your notebook also includes a physics-based size
# estimation step (pinhole-camera approximation from the Grad-CAM bounding
# contour, see the final cell of polyps.ipynb). That's a reasonable next
# feature to add here -- after computing the heatmap above, threshold it,
# run cv2.findContours, and convert the bounding box to mm using the same
# focal-length/distance constants, then return width_mm/height_mm in the
# API response. Skipped here to keep the deployed model identical to what
# you've validated in the notebook; add it once you've picked stable
# CAMERA_FOCAL_LENGTH_PX / CAMERA_DISTANCE_MM values for your endoscope.
#
# If you later swap to an object detector (YOLOv8 / Faster R-CNN) instead
# of this classifier, only this module needs to change -- the FastAPI
# route and the Flutter app's contract (status/confidence/annotated image)
# stay the same.
# --------------------------------------------------------------------------
