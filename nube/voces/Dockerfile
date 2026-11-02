# Endpoint de voces de Orquestador (RunPod serverless con GPU): Chatterbox Multilingual (MIT).
# Imagen aparte de la de ComfyUI porque Chatterbox fija su propia version de PyTorch.
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1 \
    HF_HOME=/runpod-volume/hf
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip ffmpeg libsndfile1 \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir chatterbox-tts==0.1.7 runpod huggingface_hub

COPY nube/voces/handler.py /app/handler.py
CMD ["python3", "-u", "/app/handler.py"]
