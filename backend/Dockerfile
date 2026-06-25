# CPU-friendly base image. Swap to nvidia/cuda base + torch CUDA wheels
# if you're deploying to a GPU instance for faster inference.
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Place your exported model weights at backend/models/polyp_model.pth
# before building, or mount them as a volume at runtime.
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
