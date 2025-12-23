#!/usr/bin/env python3
"""
Simple gTTS Flask Service - Minimal version
"""

from flask import Flask, request, send_file, jsonify
import tempfile
import os
import sys

# Try to import gTTS, if it fails we'll know
try:
    from gtts import gTTS
    print("✅ gTTS imported successfully")
except ImportError as e:
    print(f"❌ Failed to import gTTS: {e}")
    sys.exit(1)

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy', 
        'service': 'gTTS Flask', 
        'language': 'en-in',
        'message': 'Service is running'
    })

@app.route('/speak')
def speak():
    text = request.args.get('text', '')
    format_param = request.args.get('format', 'mp3')
    lang = request.args.get('lang', 'en-in')
    
    print(f'📨 TTS Request: text="{text}", lang={lang}, format={format_param}')
    
    if not text:
        print('⚠️ No text provided')
        return 'No text provided', 400
    
    try:
        print(f'🔄 Generating audio for: "{text}"')
        
        # Create gTTS object
        tts = gTTS(text=text, lang=lang, slow=False)
        
        # Create temporary file
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.mp3')
        temp_file.close()  # Close the file so gTTS can write to it
        
        # Save to temp file
        tts.save(temp_file.name)
        
        print(f'✅ Audio generated: "{text}"')
        
        # Send file and schedule cleanup
        def cleanup():
            try:
                os.unlink(temp_file.name)
                print(f'🗑️ Cleaned up temp file')
            except:
                pass
        
        response = send_file(temp_file.name, 
                           as_attachment=False, 
                           mimetype='audio/mpeg')
        response.call_on_close(cleanup)
        return response
        
    except Exception as e:
        print(f'❌ Error: {e}')
        return f'Error: {str(e)}', 500

if __name__ == '__main__':
    print('🚀 Starting Simple gTTS Flask Service...')
    print('🌐 URL: http://192.168.31.137:8080')  
    print('🎯 Language: Indian English (en-in)')
    print('📱 Ready for Android connections!')
    print('=' * 50)
    
    app.run(host='0.0.0.0', port=8080, debug=False)
