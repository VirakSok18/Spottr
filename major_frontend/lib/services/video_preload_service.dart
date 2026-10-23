import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoPreloadService {
  static final VideoPreloadService _instance = VideoPreloadService._internal();
  static VideoPreloadService get instance => _instance;

  final Map<String, YoutubePlayerController> _controllers = {};

  VideoPreloadService._internal();

  /// Preloads a video by creating a controller if it doesn't exist.
  YoutubePlayerController preload(String videoId) {
    if (_controllers.containsKey(videoId)) {
      return _controllers[videoId]!;
    }

    final controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: true,
        loop: true,
        hideControls: true,
        disableDragSeek: true,
      ),
    );
    _controllers[videoId] = controller;
    return controller;
  }

  /// Returns an existing controller or creates a new one.
  YoutubePlayerController getController(String videoId) {
    return preload(videoId);
  }

  /// Checks if a controller exists for the given video ID.
  bool hasController(String videoId) {
    return _controllers.containsKey(videoId);
  }

  /// Disposes a specific controller.
  void disposeController(String videoId) {
    if (_controllers.containsKey(videoId)) {
      _controllers[videoId]?.dispose();
      _controllers.remove(videoId);
    }
  }

  /// Disposes all controllers (e.g., on logout).
  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
}
