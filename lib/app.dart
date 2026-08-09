import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/protection/application/intervention_controller.dart';
import 'features/protection/presentation/block_overlay.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

class SayNOApp extends ConsumerWidget {
  const SayNOApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    // Warm up the intervention controller to start listening to detection changes
    ref.watch(interventionStateProvider);

    return MaterialApp.router(
      title: 'SayNO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const Positioned.fill(
              child: BlockOverlay(),
            ),
          ],
        );
      },
    );
  }
}
