import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'video_player_screen.dart';

class InlineVideoPostPlayer extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final bool showPageIndicator;
  final String pageProgress;

  const InlineVideoPostPlayer({
    Key? key,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.showPageIndicator = false,
    this.pageProgress = '',
  }) : super(key: key);

  @override
  State<InlineVideoPostPlayer> createState() => _InlineVideoPostPlayerState();
}

class _InlineVideoPostPlayerState extends State<InlineVideoPostPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initializePlayer() async {
    if (_controller != null) return;
    
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
      
      _controller!.addListener(() {
        if (_controller!.value.position == _controller!.value.duration) {
          setState(() {
            _isPlaying = false;
            _showControls = true;
          });
        }
      });
    } catch (e) {
      print('Error initializing inline video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_isInitialized) {
      _initializePlayer();
      return;
    }

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
        _showControls = true;
      } else {
        _controller!.play();
        _isPlaying = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isPlaying) {
            setState(() => _showControls = false);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video or Thumbnail
          _isInitialized
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              : Image.network(
                  widget.thumbnailUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 250,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.black26),
                ),

          // Play/Pause Overlay
          if (!_isPlaying || _showControls)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),

          // Full Screen Button
          Positioned(
            bottom: 12,
            left: 12,
            child: GestureDetector(
              onTap: () {
                _controller?.pause();
                setState(() => _isPlaying = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      mediaUrl: widget.videoUrl,
                      mediaType: 'video',
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),

          // Page Indicator
          if (widget.showPageIndicator)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.pageProgress,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // VIDEO Label
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'VIDEO',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
