import 'package:flutter/widgets.dart';
import '../services/practice_usage_service.dart';

class PracticeTimeTracker with WidgetsBindingObserver {
  final String userLocalId;
  final String date; // Format: YYYY-MM-DD
  final Stopwatch _stopwatch = Stopwatch();
  int _accumulatedSeconds = 0;
  bool _isStarted = false;

  PracticeTimeTracker({required this.userLocalId, required this.date});

  void start() {
    if (_isStarted) return;
    WidgetsBinding.instance.addObserver(this);
    _stopwatch.start();
    _isStarted = true;
  }

  Future<void> stop() async {
    if (!_isStarted) return;
    _stopwatch.stop();
    _accumulatedSeconds += _stopwatch.elapsed.inSeconds;
    await PracticeUsageService().addOrUpdatePracticeTime(
      date,
      userLocalId,
      _accumulatedSeconds,
    );
    WidgetsBinding.instance.removeObserver(this);
    _isStarted = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _stopwatch.stop();
      _accumulatedSeconds += _stopwatch.elapsed.inSeconds;
      _stopwatch.reset();
      await PracticeUsageService().addOrUpdatePracticeTime(
        date,
        userLocalId,
        _accumulatedSeconds,
      );
    } else if (state == AppLifecycleState.resumed) {
      _stopwatch.start();
    }
  }
}
