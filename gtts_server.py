#!/usr/bin/env python3
"""
gTTS Flask Service for AI Reading Assistant
Provides Indian English text-to-speech for Android devices
"""

from flask import Flask, request, send_file
from flask_cors import CORS
from gtts import gTTS
import tempfile
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

@app.route('/speak', methods=['GET'])
def speak():
    text = request.args.get('text', '')
    format = request.args.get('format', 'mp3')
    lang = request.args.get('lang', 'en-in')
    
    print(f'🎯 TTS Request: text="{text}", lang={lang}, format={format}')
    
    if not text:
        print('❌ No text provided')
        return 'No text provided', 400
    
    try:
        print(f'🔄 Generating audio for: "{text}"')
        tts = gTTS(text=text, lang=lang, slow=False)
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.mp3')
        tts.save(temp_file.name)
        
        print(f'✅ Audio generated successfully for: "{text}"')
        
        response = send_file(temp_file.name, as_attachment=False, mimetype='audio/mpeg')
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = '*'
        response.call_on_close(lambda: os.unlink(temp_file.name))
        return response
        
    except Exception as e:
        print(f'❌ Error generating audio: {e}')
        return f'Error: {str(e)}', 500

@app.route('/health', methods=['GET'])
def health():
    from flask import jsonify
    response = jsonify({'status': 'healthy', 'service': 'gTTS Flask', 'language': 'en-in'})
    response.headers['Access-Control-Allow-Origin'] = '*'
    return response

if __name__ == '__main__':
    print('🎤 gTTS Flask Service Starting...')
    print('🌐 Server: http://192.168.31.137:8080')  
    print('🎯 Language: Indian English (en-in)')
    print('📱 Ready for Android device connections!')
    print('🔥 Service is running - use CTRL+C to stop')
    print()
    
    try:
        app.run(host='0.0.0.0', port=8080, debug=True, use_reloader=False)
    except KeyboardInterrupt:
        print('\n🛑 Service stopped by user')
    except Exception as e:
        print(f'\n❌ Service crashed with error: {e}')
        import traceback
        traceback.print_exc()
