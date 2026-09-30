import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service to detect device shake gestures and trigger callbacks.
class ShakeDetectorService {
  final VoidCallback onShake;
  final double shakeThreshold;
  final Duration cooldownDuration;

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  DateTime _lastShakeTime = DateTime.fromMillisecondsSinceEpoch(0);

  ShakeDetectorService({
    required this.onShake,
    this.shakeThreshold = 18.0,
    this.cooldownDuration = const Duration(milliseconds: 1400),
  });

  void startListening() {
    _subscription?.cancel();
    try {
      _subscription = userAccelerometerEventStream().listen((event) {
        final g = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        if (g > shakeThreshold) {
          final now = DateTime.now();
          if (now.difference(_lastShakeTime) > cooldownDuration) {
            _lastShakeTime = now;
            HapticFeedback.mediumImpact();
            onShake();
          }
        }
      }, onError: (err) {
        debugPrint('ShakeDetectorService error: $err');
      });
    } catch (e) {
      debugPrint('ShakeDetectorService init failed: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopListening();
  }
}
