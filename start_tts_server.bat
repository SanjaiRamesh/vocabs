@echo off
echo ============================================
echo AI Reading Assistant - TTS Server Startup
echo ============================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python from https://python.org
    pause
    exit /b 1
)

echo Python found!
echo.

REM Check if pip packages are installed
echo Checking dependencies...
pip show flask >nul 2>&1
if errorlevel 1 (
    echo Installing required packages...
    pip install -r requirements.txt
    if errorlevel 1 (
        echo ERROR: Failed to install packages
        pause
        exit /b 1
    )
) else (
    echo Dependencies already installed!
)

echo.
echo Starting TTS server...
echo Server will be available at: http://localhost:8080
echo.
echo To test the server, use this command in another terminal:
echo curl -X POST http://localhost:8080/speak -H "Content-Type: application/json" -d "{\"text\": \"Hello World\"}" --output test.wav
echo.
echo Press Ctrl+C to stop the server
echo ============================================
echo.

REM Start the server
python simple_tts_server.py

echo.
echo Server stopped.
pause
