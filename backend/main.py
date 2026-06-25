"""
main.py
FastAPI backend for the polyp detection system.

Run locally:
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload

Endpoints:
    GET  /health   -> service + model status check
    POST /predict  -> multipart image upload, returns detection result
"""

import logging
import time

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from model_utils import (
    InvalidImageError,
    ModelInferenceError,
    PolypModelHandler,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("polyp-detection-api")

app = FastAPI(
    title="Polyp Detection API",
    description="Inference service for endoscopy polyp detection",
    version="1.0.0",
)

# In production, replace "*" with your actual app's origin / a config value.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

MAX_FILE_SIZE_MB = 10
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/jpg"}

model_handler: PolypModelHandler | None = None


@app.on_event("startup")
def load_model() -> None:
    """Load the model once when the server starts, not per-request."""
    global model_handler
    try:
        model_handler = PolypModelHandler()
        logger.info("Model loaded successfully.")
    except ModelInferenceError as exc:
        # Server still starts so /health reports the problem clearly,
        # rather than crashing with an opaque error.
        logger.error("Model failed to load: %s", exc)
        model_handler = None


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool


class PredictionResponse(BaseModel):
    status: str
    is_polyp_detected: bool
    confidence: float
    original_image: str  # base64 JPEG
    annotated_image: str  # base64 JPEG
    inference_time_ms: float


@app.get("/health", response_model=HealthResponse)
def health_check():
    return HealthResponse(
        status="ok" if model_handler else "model_unavailable",
        model_loaded=model_handler is not None,
    )


@app.post("/predict", response_model=PredictionResponse)
async def predict(file: UploadFile = File(...)):
    if model_handler is None:
        raise HTTPException(
            status_code=503,
            detail="Model is not loaded. Check server logs and /health.",
        )

    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported file type '{file.content_type}'. "
            "Please upload a JPEG or PNG image.",
        )

    image_bytes = await file.read()

    size_mb = len(image_bytes) / (1024 * 1024)
    if size_mb > MAX_FILE_SIZE_MB:
        raise HTTPException(
            status_code=413,
            detail=f"Image too large ({size_mb:.1f} MB). Max size is {MAX_FILE_SIZE_MB} MB.",
        )

    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    start_time = time.time()
    try:
        result = model_handler.predict(image_bytes)
    except InvalidImageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ModelInferenceError as exc:
        logger.exception("Model inference failed")
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Unexpected error during prediction")
        raise HTTPException(
            status_code=500, detail="Unexpected server error during inference."
        ) from exc

    elapsed_ms = round((time.time() - start_time) * 1000, 1)
    return PredictionResponse(**result, inference_time_ms=elapsed_ms)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
