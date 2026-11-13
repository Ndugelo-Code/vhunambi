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

# Install lightweight delta DSP/audio/cloud & ACE-Step runtime deps without rebuilding PyTorch 2.10
COPY requirements.txt .
RUN pip install --no-cache-dir \
    "pedalboard>=0.9.0" \
    "pyloudnorm>=0.1.1" \
    "boto3>=1.34.0" \
    "runpod>=1.7.0" \
    "requests>=2.31.0" \
    "soundfile>=0.12.1" \
    "librosa>=0.10.1" \
    "demucs>=4.0.0" \
    "torchvision==0.25.0" \
    "loguru>=0.7.3" \
    "pypinyin>=0.53.0" \
    "hangul-romanize>=0.1.0" \
    "num2words>=0.5.14" \
    "py3langid>=0.3.0" \
    "spacy>=3.8.0" \
    "cutlet>=0.4.0" \
    "fugashi>=1.3.0" \
    "unidic-lite>=1.0.8" \
    && pip install --no-cache-dir --no-deps "git+https://github.com/ace-step/ACE-Step.git"

# Pre-download Demucs htdemucs model weights, pin py3langid==0.3.0 (required for LanguageIdentifier.from_pickled_model), and verify ACE-Step init path
RUN pip install --no-cache-dir --force-reinstall "py3langid==0.3.0" && \
    python -c "from demucs.pretrained import get_model; get_model('htdemucs'); from acestep.pipeline_ace_step import ACEStepPipeline; from acestep.language_segmentation.LangSegment import LangSegment; from acestep.language_segmentation import language_filters; ls = LangSegment(); ls.setfilters(language_filters.default); from acestep.models.lyrics_utils.lyric_tokenizer import VoiceBpeTokenizer; VoiceBpeTokenizer(); import pedalboard, pyloudnorm; print('ZR GPU dependencies & ACE-Step tokenizer verified')"

# Copy Vhunambi Phase 25-66 Python worker modules
COPY model_utils.py .
COPY mmo_extractor.py .
COPY stem_mastering_worker.py .
COPY seed_vc_worker.py .
COPY handler.py .

# RunPod entrypoint
CMD [ "python", "-u", "/app/handler.py" ]
