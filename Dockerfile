# syntax=docker/dockerfile:1.6
FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_SYSTEM_PYTHON=1 \
    PIP_NO_CACHE_DIR=1 \
    TZ=Asia/Tokyo

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl tini libglib2.0-0 libgl1 && \
    rm -rf /var/lib/apt/lists/*

RUN addgroup --system --gid 65532 app && \
    adduser --system --uid 65532 --ingroup app --home /home/app app

WORKDIR /app
COPY --chown=app:app requirements-pin.txt extra_model_paths.yaml start.sh ./
RUN chmod +x /app/start.sh

RUN pip install --no-cache-dir uv

ARG COMFYUI_COMMIT=8f3d8f5f7c38b0b8c9c2d0f9e9f3f1c6a1b2c3d4
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    git checkout ${COMFYUI_COMMIT}

# Place extra_model_paths.yaml where ComfyUI expects it
RUN cp /app/extra_model_paths.yaml /app/ComfyUI/extra_model_paths.yaml

RUN cd /app/ComfyUI && uv pip install -r requirements.txt

RUN uv pip install "torch==2.6.*+cu124" "torchvision==0.21.*+cu124" "torchaudio==2.6.*+cu124" \
    --index-url https://download.pytorch.org/whl/cu124

COPY --chown=app:app nodes.lock /app/nodes.lock
RUN set -ex; \
    mkdir -p /app/ComfyUI/custom_nodes; \
    while read -r url commit; do \
      name=$(basename "$url" .git); \
      git clone "$url" "/app/ComfyUI/custom_nodes/$name"; \
      cd "/app/ComfyUI/custom_nodes/$name"; \
      git checkout "$commit"; \
      if [ -f requirements.txt ]; then uv pip install -r requirements.txt; fi; \
    done < /app/nodes.lock

RUN if [ -s /app/requirements-pin.txt ]; then uv pip install -r /app/requirements-pin.txt; fi

# Ensure non-root user has access to working tree
RUN chown -R 65532:65532 /app/ComfyUI

USER 65532:65532
EXPOSE 8000
ENV PORT=8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8081/healthz || exit 1

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/app/start.sh"]


