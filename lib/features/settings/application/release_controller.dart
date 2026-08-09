import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../protection/application/session_controller.dart';
import '../../protection/application/protection_controller.dart';
import '../../protection/application/time_verification_service.dart';
import '../../protection/application/notification_service.dart';
import '../data/release_repository.dart';
import '../data/sqlite_release_repository.dart';
import '../domain/release_request.dart';
import '../domain/partnership.dart';
import 'partner_controller.dart';

class ReleaseState {
  final ReleaseRequest? activeRequest;
  final Duration? remainingTime;
  final bool isLoading;
  final String? errorMessage;

  ReleaseState({
    this.activeRequest,
    this.remainingTime,
    this.isLoading = false,
    this.errorMessage,
  });

  ReleaseState copyWith({
    ReleaseRequest? activeRequest,
    Duration? remainingTime,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ReleaseState(
      activeRequest: activeRequest ?? this.activeRequest,
      remainingTime: remainingTime ?? this.remainingTime,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final releaseControllerProvider =
    StateNotifierProvider<ReleaseController, ReleaseState>((ref) {
  return ReleaseController(ref);
});

class ReleaseController extends StateNotifier<ReleaseState> {
  final Ref ref;
  Timer? _timer;
  StreamSubscription? _firestoreSubscription;

  ReleaseController(this.ref) : super(ReleaseState(isLoading: true)) {
    loadActiveRequest();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadActiveRequest() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final repository = ref.read(releaseRepositoryProvider);
      final active = await repository.getActiveReleaseRequest();
      if (active != null) {
        state = ReleaseState(activeRequest: active);
        if (active.status == ReleaseStatus.pending_approval) {
          _listenToFirestoreRequest(active);
        } else {
          _startTimer(active);
        }
      } else {
        state = ReleaseState(activeRequest: null, remainingTime: null);
      }
    } catch (e) {
      state = ReleaseState(activeRequest: null, remainingTime: null, errorMessage: e.toString());
    }
  }

  void _startTimer(ReleaseRequest request) {
    _timer?.cancel();
    _tick(request);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick(request);
    });
  }

  void _listenToFirestoreRequest(ReleaseRequest request) {
    _firestoreSubscription?.cancel();
    final isFirebase = ref.read(firebaseInitializedProvider);
    if (!isFirebase) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('release_requests')
          .doc(request.id.toString());

      _firestoreSubscription = docRef.snapshots().listen((snapshot) async {
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data == null) return;

        final remoteStatus = data['status'] as String?;
        if (remoteStatus == 'grace_window' &&
            state.activeRequest?.status == ReleaseStatus.pending_approval) {
          // Partner approved!
          final approvedAtStr = data['partnerApprovedAtUtc'] as String?;
          final approvedAt = approvedAtStr != null
              ? DateTime.parse(approvedAtStr).toUtc()
              : getSystemTime().toUtc();

          // Scale grace window for testing if cooldown was <= 60s
          final graceDurationSeconds = request.cooldownDurationSeconds <= 60 ? 60 : 86400;
          final expiresAt = approvedAt.add(Duration(seconds: graceDurationSeconds));

          final updated = state.activeRequest!.copyWith(
            status: ReleaseStatus.grace_window,
            partnerApprovedAtUtc: approvedAt,
            graceWindowExpiresAtUtc: expiresAt,
          );

          final repository = ref.read(releaseRepositoryProvider);
          await repository.updateReleaseRequest(updated);

          _logTelemetry("Release Approved", {
            "approved_at": approvedAt.toIso8601String(),
            "request_id": request.id,
          });
          _logTelemetry("Grace Window Started", {
            "started_at": approvedAt.toIso8601String(),
            "expires_at": expiresAt.toIso8601String(),
            "request_id": request.id,
          });

          // Notify partner of grace window start
          ref.read(notificationServiceProvider).sendNotificationToPartner(
            title: 'SayNO Protection Alert',
            body: 'Release request approved. Cooldown grace window has started.',
          );

          state = state.copyWith(activeRequest: updated);
          _startTimer(updated);
        } else if (remoteStatus == 'canceled' &&
            (state.activeRequest?.status == ReleaseStatus.cooldown ||
             state.activeRequest?.status == ReleaseStatus.pending_approval ||
             state.activeRequest?.status == ReleaseStatus.grace_window)) {
          await cancelRelease();
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to Firestore release request: $e');
    }
  }

  Future<void> _tick(ReleaseRequest request) async {
    final now = getSystemTime().toUtc();

    if (request.status == ReleaseStatus.cooldown) {
      final endTime = request.requestedAtUtc.add(Duration(seconds: request.cooldownDurationSeconds));
      final difference = endTime.difference(now);

      if (difference <= Duration.zero) {
        _timer?.cancel();
        state = state.copyWith(isLoading: true);

        try {
          await ref.read(timeVerificationServiceProvider).verifyTimeIntegrity();

          final partnerState = ref.read(partnerControllerProvider);
          final isPartnerLinked = partnerState.partnership != null &&
              partnerState.partnership!.status == PartnershipStatus.active;

          final repository = ref.read(releaseRepositoryProvider);

          if (isPartnerLinked) {
            final updated = request.copyWith(status: ReleaseStatus.pending_approval);
            await repository.updateReleaseRequest(updated);

            final isFirebase = ref.read(firebaseInitializedProvider);
            if (isFirebase) {
              await FirebaseFirestore.instance
                  .collection('release_requests')
                  .doc(request.id.toString())
                  .update({'status': 'pending_approval'});
            }

            // Notify partner of pending approval
            ref.read(notificationServiceProvider).sendNotificationToPartner(
              title: 'SayNO Protection Alert',
              body: 'Release request is pending your approval.',
            );

            state = ReleaseState(
              activeRequest: updated,
              remainingTime: Duration.zero,
            );
            _listenToFirestoreRequest(updated);
          } else {
            // Auto approved (no partner linked)
            final updated = request.copyWith(status: ReleaseStatus.completed);
            await repository.updateReleaseRequest(updated);

            _logTelemetry("Release Completed", {
              "completed_at": now.toIso8601String(),
              "request_id": request.id,
            });

            await ref.read(protectionPlatformServiceProvider).updateReleaseAuthorization(true);

            state = ReleaseState(
              activeRequest: updated,
              remainingTime: Duration.zero,
            );
          }
        } catch (e) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: e.toString().replaceAll('Exception: ', ''),
          );
        }
      } else {
        state = state.copyWith(
          activeRequest: request,
          remainingTime: difference,
        );
      }
    } else if (request.status == ReleaseStatus.grace_window) {
      final endTime = request.graceWindowExpiresAtUtc ?? getSystemTime().toUtc();
      final difference = endTime.difference(now);

      if (difference <= Duration.zero) {
        _timer?.cancel();
        state = state.copyWith(isLoading: true);

        try {
          await ref.read(timeVerificationServiceProvider).verifyTimeIntegrity();

          final repository = ref.read(releaseRepositoryProvider);
          final updated = request.copyWith(status: ReleaseStatus.completed);
          await repository.updateReleaseRequest(updated);

          final isFirebase = ref.read(firebaseInitializedProvider);
          if (isFirebase) {
            await FirebaseFirestore.instance
                .collection('release_requests')
                .doc(request.id.toString())
                .update({'status': 'completed'});
          }

          _logTelemetry("Release Completed", {
            "completed_at": now.toIso8601String(),
            "request_id": request.id,
          });

          await ref.read(protectionPlatformServiceProvider).updateReleaseAuthorization(true);

          state = ReleaseState(
            activeRequest: updated,
            remainingTime: Duration.zero,
          );
        } catch (e) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: e.toString().replaceAll('Exception: ', ''),
          );
        }
      } else {
        state = state.copyWith(
          activeRequest: request,
          remainingTime: difference,
        );
      }
    }
  }

  Future<void> initiateRelease({int durationSeconds = 86400}) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final now = getSystemTime().toUtc();
      final partnerState = ref.read(partnerControllerProvider);
      final isPartnerLinked = partnerState.partnership != null &&
          partnerState.partnership!.status == PartnershipStatus.active;

      final request = ReleaseRequest(
        requestedAtUtc: now,
        cooldownDurationSeconds: durationSeconds,
        status: ReleaseStatus.cooldown,
      );

      final repository = ref.read(releaseRepositoryProvider);
      await repository.createReleaseRequest(request);

      final inserted = await repository.getActiveReleaseRequest();
      if (inserted == null) throw Exception("Failed to retrieve active request.");

      _logTelemetry("Release Initiated", {
        "requested_at": now.toIso8601String(),
        "duration_seconds": durationSeconds,
        "request_id": inserted.id,
      });

      if (isPartnerLinked) {
        final isFirebase = ref.read(firebaseInitializedProvider);
        if (isFirebase) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('release_requests')
                .doc(inserted.id.toString())
                .set({
              'userId': user.uid,
              'requestedAtUtc': now.toIso8601String(),
              'cooldownDurationSeconds': durationSeconds,
              'partnerApprovedAtUtc': null,
              'graceWindowExpiresAtUtc': null,
              'status': 'cooldown',
              'partnerEmail': partnerState.partnership!.partnerEmail,
            });
          }
        }
        ref.read(notificationServiceProvider).sendNotificationToPartner(
          title: 'SayNO Protection Alert',
          body: 'User has requested protection release.',
        );
      }

      await ref.read(protectionPlatformServiceProvider).updateReleaseAuthorization(false);
      await loadActiveRequest();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> cancelRelease() async {
    final active = state.activeRequest;
    if (active == null || active.id == null) return;

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      _timer?.cancel();
      _firestoreSubscription?.cancel();

      final repository = ref.read(releaseRepositoryProvider);
      await repository.updateReleaseRequestStatus(active.id!, ReleaseStatus.canceled);

      final partnerState = ref.read(partnerControllerProvider);
      final isPartnerLinked = partnerState.partnership != null &&
          partnerState.partnership!.status == PartnershipStatus.active;
      if (isPartnerLinked) {
        ref.read(notificationServiceProvider).sendNotificationToPartner(
          title: 'SayNO Protection Alert',
          body: 'User has canceled the protection release request.',
        );
      }

      final isFirebase = ref.read(firebaseInitializedProvider);
      if (isFirebase) {
        try {
          await FirebaseFirestore.instance
              .collection('release_requests')
              .doc(active.id.toString())
              .update({'status': 'canceled'});
        } catch (e) {
          debugPrint('Error canceling release request on Firestore: $e');
        }
      }

      _logTelemetry("Release Cancelled", {
        "cancelled_at": getSystemTime().toUtc().toIso8601String(),
        "request_id": active.id,
      });

      await ref.read(protectionPlatformServiceProvider).updateReleaseAuthorization(false);
      state = ReleaseState(activeRequest: null, remainingTime: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void _logTelemetry(String eventName, Map<String, dynamic> data) {
    final payload = {
      'event': eventName,
      'timestamp': getSystemTime().toUtc().toIso8601String(),
      ...data,
    };
    print('TELEMETRY_LOG: ${jsonEncode(payload)}');
  }
}
