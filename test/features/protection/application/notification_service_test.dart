import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayno/features/protection/application/notification_service.dart';
import 'package:sayno/features/settings/application/partner_controller.dart';
import 'package:sayno/features/settings/domain/partnership.dart';
import 'package:sayno/features/settings/data/partnership_repository.dart';
import 'package:sayno/features/settings/data/sqlite_partnership_repository.dart';

class MockPartnershipRepository implements PartnershipRepository {
  Partnership? partnership;
  MockPartnershipRepository(this.partnership);

  @override
  Future<Partnership?> getLocalPartnership() async => partnership;

  @override
  Future<Partnership?> syncPartnership(String userId) async => partnership;

  @override
  Future<void> invitePartner({
    required String userEmail,
    required String userId,
    required String partnerEmail,
    required String verificationToken,
  }) async {}

  @override
  Future<void> acceptInvitation({
    required String token,
    required String partnerEmail,
    required String partnerUid,
  }) async {}

  @override
  Future<void> clearLocalPartnership() async {
    partnership = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'initialize') {
        return true;
      }
      return null;
    });
  });

  test('NotificationService skips FCM initialization when Firebase is disabled', () async {
    final container = ProviderContainer(
      overrides: [
        firebaseInitializedProvider.overrideWithValue(false),
        partnershipRepositoryProvider.overrideWithValue(MockPartnershipRepository(null)),
      ],
    );

    final service = container.read(notificationServiceProvider);
    await service.initialize();

    // Verify it doesn't send notifications to partner since Firebase is disabled
    await service.sendNotificationToPartner(title: 'Test', body: 'Test');

    container.dispose();
  });
}
