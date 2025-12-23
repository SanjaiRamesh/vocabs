# AI Reading Assistant (RA)

An intelligent Flutter-based reading practice app designed for children aged 5-10. Features spaced repetition learning, visual and auditory practice modes, and gamification elements to make reading fun and effective.

## Features

### Core Functionality
- **Visual Practice Mode**: Display words for children to read and spell
- **Auditory Practice Mode**: Text-to-speech pronunciation with typing practice
- **Spaced Repetition**: Scientifically-backed learning algorithm for optimal retention
- **Progress Tracking**: Detailed analytics and performance monitoring
- **Gamification**: Coins, achievements, and rewards system
- **Multiple Subjects**: Support for English, Math, Science, Social Studies, etc.

### Text-to-Speech (TTS) Integration
- **Local TTS Container**: Uses containerized TTS service for audio generation
- **Audio Caching**: First-time conversion with local storage for reuse
- **Child-Friendly Voice**: Optimized speech rate and clarity for young learners
- **Offline Capability**: Cached audio works without internet connection

## Quick Start

### 1. Flutter App Setup
```bash
# Clone the repository
git clone <repository-url>
cd ra

# Install Flutter dependencies
flutter pub get

# Run the app
flutter run
```

### 2. TTS Service Setup

#### Option A: Quick Python Server
```bash
# Install Python dependencies
pip install -r requirements.txt

# Start the TTS server
python simple_tts_server.py
```

#### Option B: Docker Container
```bash
# Build and run the TTS container
docker build -t local-tts-api .
docker run -p 8080:8080 local-tts-api
```

### 3. Test TTS Integration
1. Open the app
2. Go to Progress screen → TTS Test button (🎤 icon)
3. Test the connection and audio generation
4. Start practicing with auditory mode

## Project Structure

```
lib/
├── models/           # Data models (WordList, WordAttempt, etc.)
├── services/         # Business logic and data services
│   ├── local_tts_service.dart     # TTS container integration
│   ├── word_list_service.dart     # Word list management
│   ├── spaced_repetition_service.dart # Learning algorithm
│   └── gamification_service.dart  # Rewards and achievements
├── screens/          # UI screens
│   ├── practice_screen.dart       # Main practice interface
│   ├── todays_practice_screen.dart # Daily review
│   └── progress_screen.dart       # Analytics and testing
├── widgets/          # Reusable UI components
└── navigation/       # App routing and navigation
```

## TTS Architecture

### Local Container Service
- **Endpoint**: `http://localhost:8080/speak`
- **Method**: POST
- **Payload**: `{"text": "word to speak"}`
- **Response**: WAV audio file

### Caching Strategy
1. Text input → Check local cache
2. If not cached → Request from TTS container
3. Save audio file to local storage
4. Play cached audio for future requests

### Benefits
- **Performance**: Instant playback after first generation
- **Reliability**: Works offline after initial caching
- **Cost-Effective**: No recurring TTS API costs
- **Privacy**: All processing happens locally

## Development

### Dependencies
- **Flutter**: Cross-platform mobile framework
- **SQLite**: Local database for progress tracking
- **HTTP**: TTS container communication
- **Flutter Sound**: Audio playback
- **Speech Recognition**: Voice input (future feature)

### Key Services
- `LocalTtsService`: TTS container integration and caching
- `SpacedRepetitionService`: Learning algorithm implementation
- `WordListService`: Word list and subject management
- `GamificationService`: Achievement and reward system

### Testing TTS Integration
```bash
# Test TTS endpoint directly
curl -X POST http://localhost:8080/speak \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello World"}' \
  --output test.wav

# PowerShell (Windows)
$headers = @{'Content-Type' = 'application/json'}
$body = '{"text": "Hello World"}'
Invoke-WebRequest -Uri "http://localhost:8080/speak" -Method POST -Headers $headers -Body $body -OutFile "test.wav"
```

## Deployment

### Production TTS Setup
For production environments, consider:
- **Cloud TTS Services**: Azure Speech, Google TTS, AWS Polly
- **HTTPS Endpoints**: Secure communication
- **Authentication**: API key protection
- **Rate Limiting**: Prevent abuse
- **CDN Caching**: Global audio distribution

### App Distribution
- **Android**: Build APK/AAB for Google Play Store
- **iOS**: Build IPA for Apple App Store
- **Web**: Flutter web build for browser access

## Documentation

- [TTS Setup Guide](TTS_SETUP_GUIDE.md) - Detailed TTS container setup
- [Spaced Repetition Logic](NEW_SPACED_REPETITION_LOGIC.md) - Learning algorithm details
- [Schedule Customization](SCHEDULE_CUSTOMIZATION_GUIDE.md) - Review scheduling

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test TTS integration
5. Submit a pull request

## License

This project is developed for educational purposes. Please ensure compliance with TTS engine licenses and data privacy regulations when deploying.
