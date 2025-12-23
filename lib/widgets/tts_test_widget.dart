import 'package:flutter/material.dart';
import '../services/local_tts_service.dart';

class TtsTestWidget extends StatefulWidget {
  const TtsTestWidget({super.key});

  @override
  State<TtsTestWidget> createState() => _TtsTestWidgetState();
}

class _TtsTestWidgetState extends State<TtsTestWidget> {
  final TextEditingController _textController = TextEditingController(
    text: "Hello World",
  );
  bool _isServiceAvailable = false;
  bool _isLoading = false;
  Map<String, dynamic> _cacheStats = {};

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _loadCacheStats();
  }

  Future<void> _checkServiceStatus() async {
    setState(() => _isLoading = true);
    try {
      final isAvailable = await LocalTtsService.instance
          .isFlaskServiceAvailable();
      setState(() => _isServiceAvailable = isAvailable);
    } catch (e) {
      debugPrint('Error checking TTS service: $e');
      setState(() => _isServiceAvailable = false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCacheStats() async {
    try {
      final stats = await LocalTtsService.instance.getCacheStats();
      setState(() => _cacheStats = stats);
    } catch (e) {
      debugPrint('Error loading cache stats: $e');
    }
  }

  Future<void> _testSpeak() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await LocalTtsService.instance.speakChildFriendly(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully played: "$text"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await _loadCacheStats(); // Refresh stats
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);
    try {
      await LocalTtsService.instance.clearCache();
      await _loadCacheStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  size: 28,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 12),
                const Text(
                  'TTS Service Test',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _checkServiceStatus,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Service Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isServiceAvailable
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isServiceAvailable ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isServiceAvailable ? Icons.check_circle : Icons.error,
                    color: _isServiceAvailable ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isServiceAvailable
                        ? 'TTS Flask Service: Available'
                        : 'TTS Flask Service: Unavailable (127.0.0.1:8080)',
                    style: TextStyle(
                      color: _isServiceAvailable
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Test Input
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Text to speak',
                border: OutlineInputBorder(),
                hintText: 'Enter text to test TTS...',
              ),
            ),
            const SizedBox(height: 12),

            // Test Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _testSpeak,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Test Speak'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cache Stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cache Statistics',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Files: ${_cacheStats['fileCount'] ?? 0}'),
                  Text('Size: ${_cacheStats['totalSizeMB'] ?? '0.00'} MB'),
                  if (_cacheStats.containsKey('error'))
                    Text(
                      'Error: ${_cacheStats['error']}',
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Clear Cache Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _clearCache,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Clear Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Setup Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Start gTTS Flask service on 127.0.0.1:8080'),
                  const Text(
                    '2. Test endpoint: GET /speak?text=hello&format=mp3&lang=en',
                  ),
                  const Text('3. Uses Indian English accent (child-friendly)'),
                  const Text('4. Audio will be cached for reuse'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
