import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/session_controller.dart';
import '../application/isolated_credit_controller.dart';
import '../application/exit_handler.dart';
import '../domain/usecases/submit_reflection_use_case.dart';
import '../application/session_providers.dart';

class ReflectionScreen extends ConsumerStatefulWidget {
  const ReflectionScreen({super.key});

  @override
  ConsumerState<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends ConsumerState<ReflectionScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleExit(bool submitted) async {
    final session = ref.read(sessionControllerProvider);
    if (session == null) {
      context.go('/dashboard');
      return;
    }

    if (submitted) {
      final repo = ref.read(sessionRepositoryProvider);
      final useCase = SubmitReflectionUseCase(repo);
      await useCase.execute(session.id, _controller.text);
      
      // Award credits
      await ref.read(isolatedCreditControllerProvider.notifier).rewardReflection();
    }

    final exitHandler = ref.read(exitHandlerProvider);
    final route = await exitHandler.determineExitRoute(
      hasReflected: submitted,
      sessionDuration: session.durationSeconds,
    );

    if (!mounted) return;

    if (route.name == 'showSummary') {
      context.go('/replacement/exit_summary');
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Reflection (Optional)'),
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What did you learn?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Take a moment to write down one takeaway. Earning fake credits reinforces your intentional identity.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your reflection here...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _handleExit(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Submit & Earn Credits'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _handleExit(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                ),
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
