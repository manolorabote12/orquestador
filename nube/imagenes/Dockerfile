# Endpoint de imagenes de Orquestador (RunPod serverless con GPU). La construye GitHub Actions.
# Contexto de construccion: la raiz del repositorio.
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1 PIP_BREAK_SYSTEM_PACKAGES=1
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip git wget ca-certificates libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 1 - ComfyUI. Fija COMFY_REF a un commit probado para que nada cambie solo.
#     Z-Image, FLUX.2 klein y Qwen-Image-Edit 2511 necesitan una version de 2026.
ARG COMFY_REF=master
RUN git clone https://github.com/comfyanonymous/ComfyUI /comfyui \
    && cd /comfyui && git checkout ${COMFY_REF} \
    && pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 \
    && pip3 install --no-cache-dir -r /comfyui/requirements.txt runpod

# 2 - Los modelos NO van en la imagen: estan en el volumen de red (/runpod-volume/models).
COPY nube/imagenes/extra_model_paths.yaml /comfyui/extra_model_paths.yaml
COPY fabrica/arte/comfy.py /app/comfy.py
COPY nube/imagenes/handler.py nube/imagenes/modelos.json /app/

CMD ["python3", "-u", "/app/handler.py"]
