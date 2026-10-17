@echo off
echo ========================================================
echo Deploying Serbuin to Firebase Hosting & Firestore
echo Project: serbuin-smart-loyalty-app
echo ========================================================
echo.
echo Step 1: Verifying Flutter Web build...
if not exist "build\web\index.html" (
    echo Building Flutter Web release bundle...
    call flutter build web --release
)

echo.
echo Step 2: Deploying Hosting & Firestore Rules...
cmd /c "npx --yes firebase-tools deploy --project serbuin-smart-loyalty-app"

echo.
echo ========================================================
echo Done! If you encountered permission errors, run:
echo   cmd /c "npx firebase-tools login --reauth"
echo to sign in with the Google account owning this project.
echo ========================================================
pause
