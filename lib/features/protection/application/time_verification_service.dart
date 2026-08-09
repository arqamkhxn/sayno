import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'protection_controller.dart';
import '../data/protection_platform_service.dart';

class NoNetworkException implements Exception {
  final String message;
  NoNetworkException(this.message);
  @override
  String toString() => 'NoNetworkException: $message';
}

class TimeDriftException implements Exception {
  final String message;
  TimeDriftException(this.message);
  @override
  String toString() => 'TimeDriftException: $message';
}

class IntegrityCompromisedException implements Exception {
  final String message;
  IntegrityCompromisedException(this.message);
  @override
  String toString() => 'IntegrityCompromisedException: $message';
}

final timeVerificationServiceProvider = Provider<TimeVerificationService>((ref) {
  final platformService = ref.watch(protectionPlatformServiceProvider);
  return TimeVerificationService(platformService);
});

class TimeVerificationService {
  final ProtectionPlatformService _platformService;

  TimeVerificationService(this._platformService);

  /// Verifies time integrity against native boot manipulation, network presence, and clock skew.
  Future<void> verifyTimeIntegrity() async {
    // 1. Check native hardware integrity
    final clockManipulated = await _platformService.isClockManipulated();
    if (clockManipulated) {
      throw IntegrityCompromisedException('Hardware/monotonic clock rollback or drift detected.');
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.openUrl('HEAD', Uri.parse('https://www.google.com'));
      final response = await request.close();

      final dateHeader = response.headers.value(HttpHeaders.dateHeader);
      if (dateHeader == null) {
        throw NoNetworkException('Google date header missing.');
      }

      final parsedDate = HttpDate.parse(dateHeader);
      final epochSeconds = parsedDate.millisecondsSinceEpoch ~/ 1000;

      // Sync verified time to native side (native side clears drift overlays if delta < 30)
      await _platformService.updateVerifiedTime(epochSeconds);

      final localEpochSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final drift = (localEpochSeconds - epochSeconds).abs();
      if (drift >= 30) {
        throw TimeDriftException('Local clock skew exceeds allowed limit (drift: $drift seconds).');
      }
    } on SocketException catch (e) {
      throw NoNetworkException('No network connection or host unreachable: $e');
    } on HandshakeException catch (e) {
      throw NoNetworkException('Secure handshake failed: $e');
    } on TimeDriftException {
      rethrow;
    } catch (e) {
      throw NoNetworkException('Failed to complete time synchronization: $e');
    } finally {
      client.close();
    }
  }

  /// Queries a highly available and synchronized server (Google) to fetch the true UTC date,
  /// validates it, and syncs the validated epoch seconds to the native Android layer.
  Future<bool> syncTime() async {
    try {
      await verifyTimeIntegrity();
      return true;
    } catch (e) {
      // Gracefully capture failure without crashing the app bootstrap
      return false;
    }
  }
}
