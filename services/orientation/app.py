"""
Orientation detection microservice.

Loads a pre-trained EfficientNetV2 ONNX model that classifies images into
four orientation buckets (0°, 90°, 180°, 270°) and returns the corrective
rotation needed.
"""

import os
import logging
from pathlib import Path

import numpy as np
import onnxruntime
from fastapi import FastAPI, File, UploadFile
from PIL import Image

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MODEL_DIR = Path(__file__).parent / "models"
MODEL_PATH = MODEL_DIR / "orientation_model.onnx"
IMAGE_SIZE = 384
IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

# Model class → corrective rotation in degrees (clockwise).
#   Class 0: image is upright          → 0°
#   Class 1: rotated 90° CCW by model  → needs 90° CW  to fix
#   Class 2: rotated 180°              → needs 180°     to fix
#   Class 3: rotated 270° CCW (=90 CW) → needs 270° CW to fix (= 90° CCW)
CLASS_TO_ROTATION = {0: 0, 1: 90, 2: 180, 3: 270}

# ---------------------------------------------------------------------------
# Model loading
# ---------------------------------------------------------------------------
ort_session = None


def load_model():
    global ort_session

    if not MODEL_PATH.exists():
        logger.error("ONNX model not found at %s", MODEL_PATH)
        logger.error(
            "Download it with: python download_model.py"
        )
        return

    providers = ["CPUExecutionProvider"]
    available = onnxruntime.get_available_providers()
    for gpu in ["CUDAExecutionProvider", "CoreMLExecutionProvider"]:
        if gpu in available:
            providers.insert(0, gpu)
            break

    ort_session = onnxruntime.InferenceSession(str(MODEL_PATH), providers=providers)
    actual = ort_session.get_providers()[0]
    logger.info("Loaded ONNX model from %s (provider: %s)", MODEL_PATH, actual)


# ---------------------------------------------------------------------------
# Preprocessing — mirrors torchvision transforms used during training,
# reimplemented with Pillow + numpy to avoid a torch dependency.
# ---------------------------------------------------------------------------
def preprocess(image: Image.Image) -> np.ndarray:
    """Resize, center-crop, normalise, and return a (1, 3, H, W) float32 array."""
    img = image.convert("RGB")

    # Resize to (IMAGE_SIZE + 32) on each side, then center-crop to IMAGE_SIZE.
    resize_to = IMAGE_SIZE + 32
    img = img.resize((resize_to, resize_to), Image.BILINEAR)

    margin = (resize_to - IMAGE_SIZE) // 2
    img = img.crop((margin, margin, margin + IMAGE_SIZE, margin + IMAGE_SIZE))

    # HWC float32 in [0, 1]
    arr = np.asarray(img, dtype=np.float32) / 255.0

    # ImageNet normalisation
    arr = (arr - IMAGENET_MEAN) / IMAGENET_STD

    # HWC → CHW, add batch dim
    arr = arr.transpose(2, 0, 1)[np.newaxis, ...]
    return arr


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(title="Orientation Detection Service")


@app.on_event("startup")
def startup():
    load_model()


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": ort_session is not None}


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    if ort_session is None:
        return {"error": "Model not loaded"}, 503

    image = Image.open(file.file)
    input_array = preprocess(image)

    input_name = ort_session.get_inputs()[0].name
    outputs = ort_session.run(None, {input_name: input_array})

    logits = outputs[0][0]  # shape: (4,)

    # Softmax for confidence
    exp_logits = np.exp(logits - np.max(logits))
    probs = exp_logits / exp_logits.sum()

    predicted_class = int(np.argmax(probs))
    confidence = float(probs[predicted_class])
    rotation = CLASS_TO_ROTATION[predicted_class]

    return {
        "rotation": rotation,
        "predicted_class": predicted_class,
        "confidence": round(confidence, 4),
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("ORIENTATION_SERVICE_PORT", "8100"))
    uvicorn.run(app, host="0.0.0.0", port=port)
