@echo off
echo ========================================================
echo Deploying Serbuin Backend to Google Cloud Run...
echo Project: serbuin-smart-loyalty-app
echo ========================================================

gcloud run deploy serbuin-backend ^
  --source . ^
  --region us-central1 ^
  --project serbuin-smart-loyalty-app ^
  --set-env-vars GEMINI_API_KEY=AQ.Ab8RN6JpgjFHpvfeK2HelMrcVJNt9V_olUftdlX1Btw30u1qeg,PROJECT_ID=serbuin-smart-loyalty-app,PROJECT_NUMBER=398979153007 ^
  --allow-unauthenticated

echo ========================================================
echo Deployment finished! Copy the Service URL above.
echo ========================================================
pause
