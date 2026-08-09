import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/identity_provider.dart';
import '../domain/entities/user_identity.dart';

class IdentitySetupScreen extends ConsumerWidget {
  const IdentitySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIdentityAsync = ref.watch(activeIdentityProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Who do you want to become?'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: activeIdentityAsync.when(
        data: (activeIdentity) => FutureBuilder<List<UserIdentity>>(
          future: ref.read(identityRepositoryProvider).getAvailableIdentities(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final identities = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: identities.length,
              itemBuilder: (context, index) {
                final identity = identities[index];
                final isSelected = activeIdentity?.id == identity.id;

                return Card(
                  color: isSelected ? Colors.grey[900] : Colors.grey[850],
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      identity.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        identity.description,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    onTap: () async {
                      await ref
                          .read(activeIdentityProvider.notifier)
                          .setIdentity(identity.id);
                      if (context.mounted) {
                        context.pop();
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
