import 'package:audioplayers/audioplayers.dart';

/// Singleton that manages Rubik's Cube sound effects.
///
/// Call [CubeSoundService.instance.playTurnSound()] whenever a face or slice turn
/// is triggered. Plays an authentic mechanical gear rotation ratchet sound.
class CubeSoundService {
  CubeSoundService._();
  static final CubeSoundService instance = CubeSoundService._();

  final AudioPlayer _player = AudioPlayer();

  /// Whether sound effects are active. Toggle to mute.
  bool enabled = true;

  /// Play the mechanical gear rotation sound for a cube turn.
  Future<void> playGearTurn() async {
    if (!enabled) return;
    try {
      await _player.stop();
      await _player.play(
        AssetSource('sounds/gear_turn.wav'),
        volume: 0.90,
      );
    } catch (_) {
      // Silently ignore audio errors — never crash the app for a missing sound.
    }
  }

  /// Backward-compatible alias for [playGearTurn].
  Future<void> playClick() => playGearTurn();
  Future<void> playTurn() => playGearTurn();
  Future<void> playComplete() => playGearTurn();

  /// Release resources. Called on app dispose if needed.
  Future<void> dispose() => _player.dispose();
}
