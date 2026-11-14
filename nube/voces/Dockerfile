# Endpoint de voces de Orquestador (RunPod serverless con GPU): Chatterbox Multilingual (MIT).
# Imagen aparte de la de ComfyUI porque Chatterbox fija su propia version de PyTorch.
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1 \
    HF_HOME=/runpod-volume/hf
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip ffmpeg libsndfile1 \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir chatterbox-tts==0.1.7 runpod huggingface_hub

# Qwen3-TTS VoiceDesign (Apache-2.0) en su propio entorno: pide un PyTorch y transformers mas nuevos.
# Por pasos (si falla, se ve cual) y sin gradio (la demo web de qwen-tts, que aqui no hace falta).
RUN apt-get update && apt-get install -y --no-install-recommends python3-venv sox && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv /opt/qwen && /opt/qwen/bin/pip install --no-cache-dir -U pip setuptools wheel
RUN /opt/qwen/bin/pip install --no-cache-dir torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
RUN /opt/qwen/bin/pip install --no-cache-dir transformers==4.57.3 accelerate==1.12.0 librosa soundfile sox onnxruntime einops numpy \
    && /opt/qwen/bin/pip install --no-cache-dir --no-deps qwen-tts \
    && /opt/qwen/bin/python -c "import qwen_tts; print('qwen-tts ok')"

COPY nube/voces/handler.py nube/voces/qwen_servidor.py /app/
CMD ["python3", "-u", "/app/handler.py"]
