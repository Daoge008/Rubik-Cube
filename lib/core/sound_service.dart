import 'package:audioplayers/audioplayers.dart';

/// Singleton that manages Rubik's Cube sound effects.
///
/// Call [CubeSoundService.instance.playClick()] whenever a face or slice turn
/// is triggered. The service lazily initialises its internal [AudioPlayer] on
/// first use and reuses it for low-latency playback.
class CubeSoundService {
  CubeSoundService._();
  static final CubeSoundService instance = CubeSoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  /// Whether sound effects are active. Toggle to mute.
  bool get enabled => _enabled;
  set enabled(bool v) => _enabled = v;

  /// Play the mechanical click/snap sound for a cube turn.
  Future<void> playClick() async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(
        AssetSource('sounds/cube_click.wav'),
        volume: 0.85,
      );
    } catch (_) {
      // Silently ignore audio errors — never crash the app for a missing sound.
    }
  }

  /// Release resources. Called on app dispose if needed.
  Future<void> dispose() => _player.dispose();
}
