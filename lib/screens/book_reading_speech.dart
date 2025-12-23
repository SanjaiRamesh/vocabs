// Speech and reading logic for BookReadingScreen
import 'package:flutter/material.dart';
import 'child_speech_recognition_service.dart';

mixin BookReadingSpeechMixin<T extends StatefulWidget> on State<T> {
  // Place speech/reading related methods here
  // Example: _startReadingMode, _startListeningForReading, _stopListening, _processSpeechResult, etc.
  void startReadingMode() async {
    // ...method body from _startReadingMode...
  }

  void startListeningForReading() async {
    // ...method body from _startListeningForReading...
  }

  Future<void> stopListening() async {
    // ...method body from _stopListening...
  }

  void processSpeechResult(String spokenText, String expectedText) async {
    // ...method body from _processSpeechResult...
  }

  void handleSuccessfulReading(double accuracy) {
    // ...method body from _handleSuccessfulReading...
  }

  void handleRetryNeeded(double accuracy) {
    // ...method body from _handleRetryNeeded...
  }

  void handleMaxAttemptsReached() {
    // ...method body from _handleMaxAttemptsReached...
  }

  void handleSpeechTimeout() {
    // ...method body from _handleSpeechTimeout...
  }

  void handleSpeechError(String error) {
    // ...method body from _handleSpeechError...
  }

  void showMessage(String message, Color color) {
    // ...method body from _showMessage...
  }
}
