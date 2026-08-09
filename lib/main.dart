import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'app.dart';
import 'features/protection/application/time_verification_service.dart';
import 'features/settings/application/partner_controller.dart';
import 'features/protection/application/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  bool isFirebaseInitialized = false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  final container = ProviderContainer(
    overrides: [
      firebaseInitializedProvider.overrideWithValue(isFirebaseInitialized),
    ],
  );

  // Initialize notification service (handles local notification setup and FCM)
  await container.read(notificationServiceProvider).initialize();

  try {
    // Perform baseline time verification on application launch
    await container.read(timeVerificationServiceProvider).syncTime();
  } catch (e) {
    // Gracefully handle network timeouts/failures on launch
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SayNOApp(),
    ),
  );
}
