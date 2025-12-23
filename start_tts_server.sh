#!/bin/bash

echo "============================================"
echo "AI Reading Assistant - TTS Server Startup"
echo "============================================"
echo

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python3 is not installed"
    echo "Please install Python3 from your package manager or https://python.org"
    exit 1
fi

echo "Python3 found!"
echo

# Check if pip packages are installed
echo "Checking dependencies..."
if ! python3 -c "import flask" &> /dev/null; then
    echo "Installing required packages..."
    pip3 install -r requirements.txt
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install packages"
        echo "You may need to run: sudo pip3 install -r requirements.txt"
        exit 1
    fi
else
    echo "Dependencies already installed!"
fi

echo
echo "Starting TTS server..."
echo "Server will be available at: http://localhost:8080"
echo
echo "To test the server, use this command in another terminal:"
echo 'curl -X POST http://localhost:8080/speak -H "Content-Type: application/json" -d '\''{"text": "Hello World"}'\'' --output test.wav'
echo
echo "Press Ctrl+C to stop the server"
echo "============================================"
echo

# Start the server
python3 simple_tts_server.py

echo
echo "Server stopped."
