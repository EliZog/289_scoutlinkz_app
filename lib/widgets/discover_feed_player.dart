import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class DiscoverVideoPlayer extends StatefulWidget {
  final String videoId;
  const DiscoverVideoPlayer({super.key, required this.videoId});

  @override
  State<DiscoverVideoPlayer> createState() => _DiscoverVideoPlayerState();
}

class _DiscoverVideoPlayerState extends State<DiscoverVideoPlayer> {
  late YoutubePlayerController _controller;
  String? _parsedId;

  String _extractVideoId(String urlOrId) {
    if (!urlOrId.contains('youtube') && !urlOrId.contains('youtu.be')) return urlOrId;
    final RegExp regex = RegExp(r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})');
    final match = regex.firstMatch(urlOrId);
    return match?.group(1) ?? urlOrId;
  }

  @override
  void initState() {
    super.initState();
    _parsedId = _extractVideoId(widget.videoId);
    
    _controller = YoutubePlayerController.fromVideoId(
      videoId: _parsedId ?? 'dQw4w9WgXcQ',
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: false,
        mute: false, 
        showFullscreenButton: false,
        loop: true,
        pointerEvents: PointerEvents.none, 
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_parsedId == null || _parsedId!.isEmpty) {
      return Container(color: Colors.black);
    }
    
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: 1600,
              height: 900,
              child: YoutubePlayer(
                controller: _controller,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
