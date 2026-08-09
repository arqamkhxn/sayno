import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayno/features/settings/domain/partnership.dart';
import 'package:sayno/features/settings/data/partnership_repository.dart';
import 'package:sayno/features/settings/data/sqlite_partnership_repository.dart';
import 'package:sayno/features/settings/application/partner_controller.dart';

class MockPartnershipRepository implements PartnershipRepository {
  Partnership? localPartnership;
  final Map<String, Map<String, dynamic>> firestorePartnerships = {};

  @override
  Future<Partnership?> getLocalPartnership() async {
    return localPartnership;
  }

  @override
  Future<void> invitePartner({
    required String userEmail,
    required String userId,
    required String partnerEmail,
    required String verificationToken,
  }) async {
    localPartnership = Partnership(
      partnerEmail: partnerEmail,
      partnerUid: null,
      status: PartnershipStatus.pending,
    );
    firestorePartnerships[verificationToken] = {
      'userId': userId,
      'userEmail': userEmail,
      'partnerEmail': partnerEmail,
      'partnerId': null,
      'status': 'pending',
      'verificationToken': verificationToken,
    };
  }

  @override
  Future<void> acceptInvitation({
    required String token,
    required String partnerEmail,
    required String partnerUid,
  }) async {
    final doc = firestorePartnerships[token];
    if (doc == null || doc['partnerEmail'] != partnerEmail || doc['status'] != 'pending') {
      throw Exception('Invalid verification token or email mismatch.');
    }

    doc['partnerId'] = partnerUid;
    doc['status'] = 'active';

    localPartnership = Partnership(
      partnerEmail: doc['userEmail'] as String,
      partnerUid: doc['userId'] as String,
      status: PartnershipStatus.active,
    );
  }

  @override
  Future<Partnership?> syncPartnership(String userId) async {
    if (localPartnership != null && localPartnership!.status == PartnershipStatus.pending) {
      // Find matching remote token
      for (final doc in firestorePartnerships.values) {
        if (doc['userId'] == userId && doc['partnerEmail'] == localPartnership!.partnerEmail) {
          if (doc['status'] == 'active') {
            localPartnership = localPartnership!.copyWith(
              status: PartnershipStatus.active,
              partnerUid: doc['partnerId'] as String?,
            );
          }
        }
      }
    }
    return localPartnership;
  }

  @override
  Future<void> clearLocalPartnership() async {
    localPartnership = null;
  }
}

void main() {
  late MockPartnershipRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockPartnershipRepository();
  });

  tearDown(() {
    container.dispose();
  });

  ProviderContainer createContainer({bool isFirebaseInitialized = false}) {
    container = ProviderContainer(
      overrides: [
        partnershipRepositoryProvider.overrideWithValue(mockRepository),
        firebaseInitializedProvider.overrideWithValue(isFirebaseInitialized),
      ],
    );
    return container;
  }

  test('Initial state loads empty local partnership', () async {
    createContainer();
    final controller = container.read(partnerControllerProvider.notifier);

    await controller.loadPartnership();

    final state = container.read(partnerControllerProvider);
    expect(state.partnership, isNull);
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('Firebase unavailable prevents inviting partner', () async {
    createContainer(isFirebaseInitialized: false);
    final controller = container.read(partnerControllerProvider.notifier);

    await controller.invitePartner('partner@example.com');

    final state = container.read(partnerControllerProvider);
    expect(state.partnership, isNull);
    expect(state.errorMessage, contains('unavailable'));
  });

  test('Unlinking / signing out clears local database cache state', () async {
    createContainer();
    final controller = container.read(partnerControllerProvider.notifier);

    // Seed local database partnership
    mockRepository.localPartnership = const Partnership(
      partnerEmail: 'partner@example.com',
      partnerUid: 'partner123',
      status: PartnershipStatus.active,
    );

    await controller.loadPartnership();
    expect(container.read(partnerControllerProvider).partnership, isNotNull);

    await controller.signOut();
    expect(container.read(partnerControllerProvider).partnership, isNull);
    expect(mockRepository.localPartnership, isNull);
  });
}
