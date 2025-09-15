#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=${PROJECT_ID:?Set PROJECT_ID}
REGION=${REGION:-asia-northeast1}
SERVICE=${SERVICE:-comfyui-gpu}
REPO=${REPO:-comfy}
IMAGE_TAG=${IMAGE_TAG:-prod}
CPU=${CPU:-8}
MEMORY=${MEMORY:-32Gi}
CONCURRENCY=${CONCURRENCY:-1}
TIMEOUT=${TIMEOUT:-3600}
SERVICE_ACCOUNT_NAME=${SERVICE_ACCOUNT_NAME:-sa-comfy-gpu}
MODELS_BUCKET=${MODELS_BUCKET:-${PROJECT_ID}-comfy-models}
OUTPUTS_BUCKET=${OUTPUTS_BUCKET:-${PROJECT_ID}-comfy-outputs}
CUSTOM_NODES_BUCKET=${CUSTOM_NODES_BUCKET:-}

IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/comfyui:${IMAGE_TAG}"

echo "[info] deploying ${SERVICE} with image ${IMAGE}"

CMD=(gcloud run deploy "${SERVICE}"
  --image="${IMAGE}"
  --region="${REGION}"
  --gpu=1 --accelerator=nvidia-l4
  --cpu="${CPU}" --memory="${MEMORY}"
  --concurrency="${CONCURRENCY}"
  --timeout="${TIMEOUT}"
  --service-account="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
  --no-allow-unauthenticated
  --ingress=internal-and-cloud-load-balancing
  --add-volume=name=models,type=cloud-storage,bucket=${MODELS_BUCKET},readonly
  --add-volume-mount=volume=models,mount-path=/models
  --add-volume=name=outputs,type=cloud-storage,bucket=${OUTPUTS_BUCKET}
  --add-volume-mount=volume=outputs,mount-path=/output)

if [[ -n "${CUSTOM_NODES_BUCKET}" ]]; then
  echo "[info] mounting custom nodes from gs://${CUSTOM_NODES_BUCKET}"
  CMD+=(--add-volume=name=customnodes,type=cloud-storage,bucket=${CUSTOM_NODES_BUCKET},readonly)
  CMD+=(--add-volume-mount=volume=customnodes,mount-path=/app/ComfyUI/custom_nodes)
fi

"${CMD[@]}"

URL=$(gcloud run services describe "${SERVICE}" --region "${REGION}" --format='value(status.url)')
echo "[ok] deployed ${SERVICE} at ${URL}"


