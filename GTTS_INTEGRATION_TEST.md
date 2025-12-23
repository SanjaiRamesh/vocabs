# gTTS Flask Service Integration Test

## Test Your Flask Service

Before using with the Flutter app, test your gTTS Flask service directly:

### PowerShell (Windows):
```powershell
# Test basic functionality
Invoke-WebRequest -Uri "http://127.0.0.1:8080/speak?text=Hello World&format=mp3&lang=en" -OutFile "test.mp3"

# Test health check
Invoke-WebRequest -Uri "http://127.0.0.1:8080/health"

# Test with different languages
Invoke-WebRequest -Uri "http://127.0.0.1:8080/speak?text=नमस्ते&format=mp3&lang=hi" -OutFile "test_hindi.mp3"
Invoke-WebRequest -Uri "http://127.0.0.1:8080/speak?text=வணக்கம்&format=mp3&lang=ta" -OutFile "test_tamil.mp3"
```

### Curl (Linux/Mac):
```bash
# Test basic functionality
curl "http://127.0.0.1:8080/speak?text=Hello World&format=mp3&lang=en" --output test.mp3

# Test health check
curl "http://127.0.0.1:8080/health"

# Test with different languages
curl "http://127.0.0.1:8080/speak?text=नमस्ते&format=mp3&lang=hi" --output test_hindi.mp3
curl "http://127.0.0.1:8080/speak?text=வணக்கம்&format=mp3&lang=ta" --output test_tamil.mp3
```

## Integration Details

### What Changed:
1. **LocalTtsService** now uses GET requests instead of POST
2. **URL Format**: `http://127.0.0.1:8080/speak?text=word&format=mp3&lang=en`
3. **Child-Friendly**: Uses MP3 format with Indian English accent for better clarity
4. **Caching**: Audio files are cached with format-specific filenames

### Default Settings for Children:
- **Format**: MP3 (Indian English accent via Google TTS)
- **Language**: English (en)
- **Codec**: MP3 codec for playback
- **Cache**: Format-specific caching (`.mp3` extension)

### Flutter App Usage:
1. Start your gTTS Flask service on `127.0.0.1:8080`
2. Open the Flutter app
3. Go to Progress screen → TTS Test button (🎤)
4. Test with sample text to verify connection
5. Use Auditory Practice mode - words will be spoken with Indian English accent

### Service Check:
The app automatically checks if your Flask service is available at startup and shows a warning if it's not accessible.

### Error Handling:
- Service unavailable: Shows user-friendly message
- Network errors: Graceful fallback
- Cache management: Automatic file cleanup options

### Performance:
- **First request**: Downloads and caches audio (~500ms-2s)
- **Subsequent requests**: Instant playback from cache (~50ms)
- **Cache location**: App documents directory under `tts_cache/`

Your gTTS Flask integration is now ready! 🚀
