import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../replacement/presentation/widgets/youtube_media_provider.dart';

class FeedVideoPlayerScreen extends StatelessWidget {
  final String videoId;
  final String title;

  const FeedVideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: YoutubeMediaProvider(videoId: videoId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
