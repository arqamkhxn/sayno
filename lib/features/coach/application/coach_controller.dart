import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/uce_api_config.dart';
import '../../identity/application/identity_controller.dart';
import '../../contract/application/contract_controller.dart';
import '../../health/application/health_controller.dart';
import '../../protection/application/session_controller.dart';
import '../../protection/domain/monitored_apps.dart';

class ChatMessage {
  final String role;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };
}

final coachControllerProvider =
    StateNotifierProvider<CoachController, AsyncValue<List<ChatMessage>>>((ref) {
  return CoachController(ref);
});

class CoachController extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final Ref _ref;

  CoachController(this._ref) : super(const AsyncData([])) {
    // Add initial greeting
    state = AsyncData([
      ChatMessage(
        role: 'model',
        text: 'Welcome back. How are you managing your digital habits today?',
        timestamp: DateTime.now(),
      )
    ]);
  }

  Future<void> sendMessage(String message) async {
    final currentHistory = state.value ?? [];
    if (message.trim().isEmpty) return;

    final userMessage = ChatMessage(
      role: 'user',
      text: message,
      timestamp: DateTime.now(),
    );

    // Optimistically add user message and set to loading state so UI can show spinner
    state = AsyncLoading<List<ChatMessage>>().copyWithPrevious(
      AsyncData([...currentHistory, userMessage]),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      // Gather context
      final identityData = _ref.read(identityControllerProvider).value;
      final contractData = _ref.read(activeContractProvider).value;
      final weeklySummary = _ref.read(weeklySummaryProvider).value;
      final todayUsageData = _ref.read(todayAppUsageProvider);

      String todayUsageStr = 'No data';
      if (todayUsageData.isNotEmpty) {
        todayUsageStr = todayUsageData.entries
            .where((e) => e.value.inMinutes > 0)
            .map((e) => '${monitoredAppsRegistry[e.key] ?? e.key}: ${e.value.inMinutes}m')
            .join(', ');
        if (todayUsageStr.isEmpty) todayUsageStr = '0m across all apps';
      }

      String identityStr = 'Not set';
      if (identityData != null && identityData.identities.isNotEmpty) {
        final topIdentity = identityData.identities.first;
        identityStr = '${topIdentity.profile.label} (Goals: ${topIdentity.selectedGoals.join(", ")})';
      }

      String restrictedAppsStr = 'None';
      if (contractData != null && contractData.isActive) {
        restrictedAppsStr = contractData.apps
            .map((a) => monitoredAppsRegistry[a.packageName] ?? a.packageName)
            .join(", ");
        if (restrictedAppsStr.isEmpty) restrictedAppsStr = 'None';
      }

      final contextPayload = {
        'identity': identityStr,
        'activeCommitment': contractData?.isActive == true ? 'Active Locked-In Contract' : 'None',
        'restrictedApps': restrictedAppsStr,
        'usage': todayUsageStr,
        'weeklyProgress': weeklySummary != null
            ? 'Total ${weeklySummary.totalHours.toStringAsFixed(1)}h this week. Avg ${weeklySummary.dailyAvgMinutes}m/day.'
            : 'No data',
      };

      // Only send a bounded history window (last 10 messages)
      final historyToSend = currentHistory
          .take(10)
          .map((m) => {'role': m.role, 'text': m.text})
          .toList();

      final response = await http.post(
        Uri.parse(UceApiConfig.coachChatUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'context': contextPayload,
          'history': historyToSend,
          'message': message,
        }),
      );

      if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Take a deep breath and try again in a minute.');
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to connect to Coach (${response.statusCode})');
      }

      final data = jsonDecode(response.body);
      final reply = data['response'] ?? 'I had trouble thinking of a response.';

      final coachMessage = ChatMessage(
        role: 'model',
        text: reply,
        timestamp: DateTime.now(),
      );

      state = AsyncData([...currentHistory, userMessage, coachMessage]);
    } catch (e) {
      // Add error message as a system/model message temporarily
      final errorMessage = ChatMessage(
        role: 'model',
        text: 'Error: ${e.toString().replaceAll("Exception: ", "")}',
        timestamp: DateTime.now(),
      );
      state = AsyncData([...currentHistory, userMessage, errorMessage]);
    }
  }
}
