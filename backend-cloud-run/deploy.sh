#!/bin/bash
set -e

echo "========================================================"
echo "Deploying Serbuin Backend to Google Cloud Run..."
echo "Project: serbuin-smart-loyalty-app"
echo "========================================================"

if [ -z "$GEMINI_API_KEY" ] && [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

if [ -z "$GEMINI_API_KEY" ]; then
  echo "[ERROR] GEMINI_API_KEY is not set."
  echo "Please run: export GEMINI_API_KEY=your_key_here"
  exit 1
fi

gcloud run deploy serbuin-backend \
  --source . \
  --region us-central1 \
  --project serbuin-smart-loyalty-app \
  --set-env-vars GEMINI_API_KEY="$GEMINI_API_KEY",PROJECT_ID=serbuin-smart-loyalty-app,PROJECT_NUMBER=398979153007,GEMINI_MODEL=gemini-3.8-flash \
  --allow-unauthenticated

echo "========================================================"
echo "Deployment finished! Copy the Service URL above."
echo "========================================================"
