import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/catalog_provider.dart';
import '../application/identity_provider.dart';

class GatewayScreen extends ConsumerWidget {
  const GatewayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curatedTopicsAsync = ref.watch(curatedTopicsProvider);
    final activeIdentityAsync = ref.watch(activeIdentityProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Blocked.',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose a better path.',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              activeIdentityAsync.when(
                data: (identity) {
                  if (identity == null) {
                    return ElevatedButton(
                      onPressed: () => context.push('/replacement/identity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Setup Identity'),
                    );
                  }
                  return Text(
                    'Topics for the ${identity.label}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: curatedTopicsAsync.when(
                  data: (topics) {
                    if (topics.isEmpty) {
                      return Center(
                        child: Text(
                          'No topics found.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: topics.length,
                      itemBuilder: (context, index) {
                        final topic = topics[index];
                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              topic.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${topic.durationSeconds ~/ 60} mins',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                color: Colors.white54, size: 16),
                            onTap: () {
                              context.push(
                                '/replacement/content',
                                extra: {'videoId': topic.sourceId, 'title': topic.title},
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Error: $error')),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  // Leave phone -> Return to dashboard or close app
                  context.go('/dashboard');
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[400],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Leave Phone',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
