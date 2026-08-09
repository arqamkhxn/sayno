import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubeMediaProvider extends StatefulWidget {
  final String videoId;
  
  const YoutubeMediaProvider({super.key, required this.videoId});

  @override
  State<YoutubeMediaProvider> createState() => _YoutubeMediaProviderState();
}

class _YoutubeMediaProviderState extends State<YoutubeMediaProvider> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
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
    return YoutubePlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
    );
  }
}
