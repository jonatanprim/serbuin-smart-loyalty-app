@echo off
echo ========================================================
echo Deploying Serbuin Backend to Google Cloud Run...
echo Project: serbuin-smart-loyalty-app
echo ========================================================

if "%GEMINI_API_KEY%"=="" (
  echo [INFO] Loading GEMINI_API_KEY from .env if present...
  if exist .env (
    for /f "tokens=1,2 delims==" %%G in (.env) do (
      if "%%G"=="GEMINI_API_KEY" set GEMINI_API_KEY=%%H
    )
  )
)

if "%GEMINI_API_KEY%"=="" (
  echo [ERROR] GEMINI_API_KEY environment variable is not set.
  echo Please run: set GEMINI_API_KEY=your_key_here
  exit /b 1
)

gcloud run deploy serbuin-backend ^
  --source . ^
  --region us-central1 ^
  --project serbuin-smart-loyalty-app ^
  --set-env-vars GEMINI_API_KEY=%GEMINI_API_KEY%,PROJECT_ID=serbuin-smart-loyalty-app,PROJECT_NUMBER=398979153007,GEMINI_MODEL=gemini-3.8-flash ^
  --allow-unauthenticated

echo ========================================================
echo Deployment finished! Copy the Service URL above.
echo ========================================================
pause
