# Dockerfile for ndugelo/zr-studio-gpu:vhunambi-v1
# Reuses existing ndugelo/zr-studio-gpu:latest layers (CUDA, PyTorch, ACE-Step 1.5)
ARG BASE_IMAGE=ndugelo/zr-studio-gpu:latest
FROM ${BASE_IMAGE}

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    HF_HOME=/tmp/hf_cache \
    HUGGINGFACE_HUB_CACHE=/tmp/hf_cache/hub

# Ensure ffmpeg and libsndfile1 are present for 320 kbps MP3 encoding & audio I/O
RUN if ! command -v ffmpeg >/dev/null 2>&1 || ! dpkg -s libsndfile1 >/dev/null 2>&1; then \
        apt-get update && apt-get install -y --no-install-recommends \
            ffmpeg \
            libsndfile1 \
            git \
            curl \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# Install lightweight delta DSP/audio/cloud dependencies without rebuilding PyTorch
COPY requirements.txt .
RUN pip install --no-cache-dir \
    "pedalboard>=0.9.0" \
    "pyloudnorm>=0.1.1" \
    "boto3>=1.34.0" \
    "runpod>=1.7.0" \
    "requests>=2.31.0" \
    "soundfile>=0.12.1" \
    "librosa>=0.10.1" \
    "demucs>=4.0.0"

# Pre-download Demucs htdemucs model weights if not already cached in base layers
RUN python -c "from demucs.pretrained import get_model; get_model('htdemucs')"

# Copy Vhunambi Phase 25-66 Python worker modules
COPY model_utils.py .
COPY mmo_extractor.py .
COPY stem_mastering_worker.py .
COPY seed_vc_worker.py .
COPY handler.py .

# RunPod entrypoint
CMD [ "python", "-u", "/app/handler.py" ]
