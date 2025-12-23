#!/usr/bin/env python3
"""
Simple TTS API Server for AI Reading Assistant
Requirements: pip install flask pyttsx3 flask-cors

Usage: python simple_tts_server.py
Server will start on http://localhost:8080
"""

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import pyttsx3
import tempfile
import os
import logging
from threading import Lock

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Global TTS engine with thread safety
tts_lock = Lock()
tts_engine = None

def init_tts_engine():
    """Initialize TTS engine with child-friendly settings"""
    global tts_engine
    try:
        tts_engine = pyttsx3.init()
        
        # Get available voices
        voices = tts_engine.getProperty('voices')
        
        # Try to set a female voice (often more child-friendly)
        for voice in voices:
            if 'female' in voice.name.lower() or 'woman' in voice.name.lower():
                tts_engine.setProperty('voice', voice.id)
                break
        
        # Set child-friendly speech parameters
        tts_engine.setProperty('rate', 120)    # Slower speech (default ~200)
        tts_engine.setProperty('volume', 0.9)  # High volume
        
        logger.info("TTS engine initialized successfully")
        logger.info(f"Using voice: {tts_engine.getProperty('voice')}")
        
    except Exception as e:
        logger.error(f"Failed to initialize TTS engine: {e}")
        raise

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "TTS API Server",
        "version": "1.0.0"
    }), 200

@app.route('/speak', methods=['POST'])
def speak():
    """Convert text to speech and return WAV file"""
    try:
        # Get text from request
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
            
        text = data.get('text', '').strip()
        if not text:
            return jsonify({"error": "No text provided"}), 400
        
        # Validate text length (prevent abuse)
        if len(text) > 500:
            return jsonify({"error": "Text too long (max 500 characters)"}), 400
        
        logger.info(f"Converting text to speech: '{text[:50]}{'...' if len(text) > 50 else ''}'")
        
        # Create temporary file for audio
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
            temp_path = tmp_file.name
        
        # Generate speech with thread safety
        with tts_lock:
            tts_engine.save_to_file(text, temp_path)
            tts_engine.runAndWait()
        
        # Verify file was created
        if not os.path.exists(temp_path) or os.path.getsize(temp_path) == 0:
            return jsonify({"error": "Failed to generate audio"}), 500
        
        logger.info(f"Audio file generated: {temp_path} ({os.path.getsize(temp_path)} bytes)")
        
        # Return the audio file
        return send_file(
            temp_path,
            mimetype='audio/wav',
            as_attachment=False,
            download_name='speech.wav',
            conditional=False
        )
        
    except Exception as e:
        logger.error(f"Error in speak endpoint: {e}")
        return jsonify({"error": f"Internal server error: {str(e)}"}), 500
    
    finally:
        # Clean up temporary file after a delay
        if 'temp_path' in locals():
            try:
                # Note: Flask will handle the file, we can't delete it immediately
                # In production, you'd want a cleanup task
                pass
            except:
                pass

@app.route('/voices', methods=['GET'])
def get_voices():
    """Get available TTS voices"""
    try:
        with tts_lock:
            voices = tts_engine.getProperty('voices')
            voice_list = []
            for voice in voices:
                voice_list.append({
                    'id': voice.id,
                    'name': voice.name,
                    'languages': getattr(voice, 'languages', []),
                    'gender': getattr(voice, 'gender', 'unknown')
                })
        
        current_voice = tts_engine.getProperty('voice')
        
        return jsonify({
            "voices": voice_list,
            "current_voice": current_voice,
            "count": len(voice_list)
        }), 200
        
    except Exception as e:
        logger.error(f"Error getting voices: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/settings', methods=['GET', 'POST'])
def settings():
    """Get or update TTS settings"""
    try:
        if request.method == 'GET':
            with tts_lock:
                return jsonify({
                    "rate": tts_engine.getProperty('rate'),
                    "volume": tts_engine.getProperty('volume'),
                    "voice": tts_engine.getProperty('voice')
                }), 200
        
        elif request.method == 'POST':
            data = request.get_json()
            with tts_lock:
                if 'rate' in data:
                    rate = max(50, min(300, int(data['rate'])))  # Clamp between 50-300
                    tts_engine.setProperty('rate', rate)
                
                if 'volume' in data:
                    volume = max(0.0, min(1.0, float(data['volume'])))  # Clamp between 0-1
                    tts_engine.setProperty('volume', volume)
                
                if 'voice' in data:
                    tts_engine.setProperty('voice', data['voice'])
            
            return jsonify({"status": "settings updated"}), 200
            
    except Exception as e:
        logger.error(f"Error in settings endpoint: {e}")
        return jsonify({"error": str(e)}), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    try:
        print("=" * 50)
        print("AI Reading Assistant - TTS API Server")
        print("=" * 50)
        print("Initializing TTS engine...")
        
        init_tts_engine()
        
        print("✓ TTS engine ready")
        print("✓ Starting server on http://localhost:8080")
        print("✓ Health check: http://localhost:8080/health")
        print("✓ Test endpoint: POST http://localhost:8080/speak")
        print("\nPress Ctrl+C to stop the server")
        print("=" * 50)
        
        # Run the Flask app
        app.run(
            host='0.0.0.0', 
            port=8080, 
            debug=False,  # Set to True for development
            threaded=True
        )
        
    except KeyboardInterrupt:
        print("\n\nServer stopped by user")
    except Exception as e:
        print(f"\nFailed to start server: {e}")
        print("\nTroubleshooting:")
        print("1. Install required packages: pip install flask pyttsx3 flask-cors")
        print("2. Check if port 8080 is available")
        print("3. Ensure TTS engine is supported on your system")
