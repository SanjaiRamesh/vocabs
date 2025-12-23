# TTS Container Setup Guide

This guide helps you set up a local Text-to-Speech (TTS) container service for the AI Reading Assistant app.

## Quick Start

### Option 1: Using Docker with TTS API

1. **Pull and run a TTS container** (example using Coqui TTS):
```bash
# Pull the container
docker pull coqui/tts

# Run the container with API server
docker run -it --rm -p 8080:5002 coqui/tts \
  --model_name "tts_models/en/ljspeech/tacotron2-DDC" \
  --server_port 5002
```

### Option 2: Custom TTS API Container

Create a simple Python Flask TTS API:

**Dockerfile:**
```dockerfile
FROM python:3.9-slim

WORKDIR /app

RUN pip install flask pyttsx3 flask-cors

COPY tts_server.py .

EXPOSE 8080

CMD ["python", "tts_server.py"]
```

**tts_server.py:**
```python
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import pyttsx3
import io
import tempfile
import os

app = Flask(__name__)
CORS(app)

# Initialize TTS engine
tts_engine = pyttsx3.init()
tts_engine.setProperty('rate', 150)  # Slower speech for children
tts_engine.setProperty('volume', 0.9)

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy"}), 200

@app.route('/speak', methods=['POST'])
def speak():
    try:
        data = request.get_json()
        text = data.get('text', '')
        
        if not text:
            return jsonify({"error": "No text provided"}), 400
        
        # Create temporary file for audio
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
            temp_path = tmp_file.name
        
        # Generate speech
        tts_engine.save_to_file(text, temp_path)
        tts_engine.runAndWait()
        
        # Return the audio file
        def remove_file():
            try:
                os.unlink(temp_path)
            except:
                pass
        
        return send_file(
            temp_path,
            mimetype='audio/wav',
            as_attachment=True,
            download_name='speech.wav'
        )
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
```

**Build and run:**
```bash
# Build the container
docker build -t local-tts-api .

# Run the container
docker run -p 8080:8080 local-tts-api
```

## Testing the Service

### Using PowerShell (Windows):
```powershell
$headers = @{'Content-Type' = 'application/json'}
$body = '{"text": "Hello, this is a test"}'
Invoke-WebRequest -Uri "http://localhost:8080/speak" -Method POST -Headers $headers -Body $body -OutFile "test.wav"
```

### Using curl (Linux/Mac):
```bash
curl -X POST http://localhost:8080/speak \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, this is a test"}' \
  --output test.wav
```

## App Integration

Once your TTS container is running on `localhost:8080`:

1. Open the AI Reading Assistant app
2. Go to Progress → TTS Test button (microphone icon)
3. Test the connection and functionality
4. Cache will be created automatically for reused audio

## Features

- **Audio Caching**: First-time conversion with local storage for reuse
- **Child-Friendly**: Optimized speech rate and clarity
- **Error Handling**: Graceful fallbacks when service is unavailable
- **Performance**: Minimal latency after initial caching

## Troubleshooting

### Container not starting:
- Check if port 8080 is available
- Verify Docker is running
- Check container logs: `docker logs <container_id>`

### App shows "TTS service unavailable":
- Verify container is running on localhost:8080
- Test the endpoint manually using curl/PowerShell
- Check network connectivity

### Audio not playing:
- Verify audio file permissions
- Check device audio settings
- Ensure adequate storage space for cache

## Production Considerations

For production deployment:
- Use HTTPS endpoints
- Implement authentication
- Add rate limiting
- Use dedicated TTS services (Azure Speech, Google TTS, etc.)
- Configure proper error monitoring
