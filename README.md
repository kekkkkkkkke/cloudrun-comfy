# ComfyUI on Cloud Run (GPU + GCS Volumes)

## Build

```bash
PROJECT_ID="your-gcp-project"
REGION="asia-northeast1"

docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/comfy/comfyui:prod .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/comfy/comfyui:prod
```

## Deploy

```bash
gcloud run deploy comfyui-gpu \
  --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/comfy/comfyui:prod \
  --region=${REGION} \
  --gpu=1 --accelerator=nvidia-l4 \
  --cpu=8 --memory=32Gi \
  --concurrency=1 \
  --timeout=3600 \
  --service-account=sa-comfy-gpu@${PROJECT_ID}.iam.gserviceaccount.com \
  --no-allow-unauthenticated \
  --ingress=internal-and-cloud-load-balancing \
  --add-volume=name=models,type=cloud-storage,bucket=${PROJECT_ID}-comfy-models,readonly \
  --add-volume-mount=volume=models,mount-path=/models \
  --add-volume=name=outputs,type=cloud-storage,bucket=${PROJECT_ID}-comfy-outputs \
  --add-volume-mount=volume=outputs,mount-path=/output
```

## Notes

- Models are read from `/models` (GCS FUSE). Outputs written to `/output`.
- `extra_model_paths.yaml` maps ComfyUI model search paths to `/models`.
- Container runs as non-root UID/GID 65532 and exposes `PORT` (default 8000).

## CI/CD with Cloud Build

1. Create Artifact Registry repo (first time):
```bash
PROJECT_ID="your-gcp-project"
REGION="asia-northeast1"
REPO="comfy"
gcloud artifacts repositories create "${REPO}" \
  --repository-format=docker --location="${REGION}"
```
2. Add a Cloud Build trigger connected to your GitHub repo (branch: `main`). Use the provided `cloudbuild.yaml`.
3. Push to `main` → Cloud Build builds and pushes:
   - `${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/comfyui:$COMMIT_SHA`
   - `${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/comfyui:prod`

## Optional: Custom Nodes from GCS

- Recommended for reproducibility: bake custom nodes via `nodes.lock` at image build.
- If you prefer to manage node code in GCS, set `CUSTOM_NODES_BUCKET` and the deploy script will mount it read-only at `/app/ComfyUI/custom_nodes`:
```bash
export PROJECT_ID="your-gcp-project"
export CUSTOM_NODES_BUCKET="${PROJECT_ID}-comfy-custom-nodes"
./scripts/deploy.sh
```
Note: Python dependencies required by those nodes must already be installed in the image. Keep `nodes.lock` installing their `requirements.txt` for safety.

## GCP Setup Helper

```bash
export PROJECT_ID="your-gcp-project"
./scripts/setup_gcp.sh
```


# cloudrun-comfy
