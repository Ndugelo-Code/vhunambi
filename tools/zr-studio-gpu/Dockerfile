# Dockerfile for ndugelo/zr-studio-gpu:v2
FROM pytorch/pytorch:2.2.1-cuda12.1-cudnn8-runtime

WORKDIR /workspace

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download Demucs htdemucs model weights so cold starts are instant
RUN python -c "from demucs.pretrained import get_model; get_model('htdemucs')"

# Copy application code
COPY mmo_extractor.py .
COPY stem_mastering_worker.py .
COPY seed_vc_worker.py .
COPY handler.py .

# RunPod entrypoint
CMD [ "python", "-u", "handler.py" ]
