#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=${PROJECT_ID:?Set PROJECT_ID}
REGION=${REGION:-asia-northeast1}
REPO=${REPO:-comfy}
SERVICE_ACCOUNT_NAME=${SERVICE_ACCOUNT_NAME:-sa-comfy-gpu}

echo "[info] project=${PROJECT_ID} region=${REGION} repo=${REPO} sa=${SERVICE_ACCOUNT_NAME}"

# Artifact Registry repo
if ! gcloud artifacts repositories describe "${REPO}" --location="${REGION}" >/dev/null 2>&1; then
  gcloud artifacts repositories create "${REPO}" \
    --repository-format=docker --location="${REGION}"
else
  echo "[ok] artifact repo exists"
fi

# Buckets
MODELS_BUCKET="gs://${PROJECT_ID}-comfy-models"
OUTPUTS_BUCKET="gs://${PROJECT_ID}-comfy-outputs"

gsutil ls -b "${MODELS_BUCKET}" >/dev/null 2>&1 || gsutil mb -l "${REGION}" "${MODELS_BUCKET}"
gsutil ls -b "${OUTPUTS_BUCKET}" >/dev/null 2>&1 || gsutil mb -l "${REGION}" "${OUTPUTS_BUCKET}"

# Service Account
if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
    --display-name="ComfyUI GPU Runtime"
else
  echo "[ok] service account exists"
fi

# IAM for buckets
gcloud storage buckets add-iam-policy-binding "${MODELS_BUCKET}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer" || true

gcloud storage buckets add-iam-policy-binding "${OUTPUTS_BUCKET}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin" || true

echo "[done] setup complete"


