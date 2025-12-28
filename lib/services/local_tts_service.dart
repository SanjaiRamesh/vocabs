// Export the correct implementation based on platform
export 'local_tts_service_io.dart'
    if (dart.library.html) 'local_tts_service_web.dart';
