import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/session_controller.dart';
import 'widgets/youtube_media_provider.dart';


class IntentionalContentScreen extends ConsumerStatefulWidget {
  final String videoId;
  final String title;

  const IntentionalContentScreen({
    super.key,
    required this.videoId,
    required this.title,
  });

  @override
  ConsumerState<IntentionalContentScreen> createState() => _IntentionalContentScreenState();
}

class _IntentionalContentScreenState extends ConsumerState<IntentionalContentScreen> {
  bool _sessionActive = false;

  @override
  void initState() {
    super.initState();
    // Start session when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final success = await ref.read(sessionControllerProvider.notifier).startSession(widget.videoId);
      if (success) {
        setState(() => _sessionActive = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Daily replacement limit reached.')),
          );
          context.pop();
        }
      }
    });
  }

  @override
  void dispose() {
    // Session is cleaned up in controller if needed, but let's call end
    // to be safe if user just hits back natively.
    // However, riverpod notifier lifecycle usually handles its own timers.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    
    // Auto-eject if session completes via timer
    if (_sessionActive && session?.completedAt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/replacement/reflection');
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(sessionControllerProvider.notifier).endSession();
            context.go('/replacement/reflection');
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _sessionActive 
                    ? YoutubeMediaProvider(videoId: widget.videoId)
                    : const CircularProgressIndicator(),
              ),
            ),
            if (session != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[900],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Session Time:',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    Text(
                      '${session.durationSeconds ~/ 60}:${(session.durationSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
