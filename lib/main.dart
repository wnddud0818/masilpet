import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  var firebaseStartupIssue = FirebaseStartupIssue.none;
  if (!DefaultFirebaseOptions.hasRequiredConfiguration) {
    firebaseStartupIssue = FirebaseStartupIssue.missingWebConfiguration;
  } else {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      // User progress writes are handled by the authenticated backend, so the
      // client only needs Firebase initialization and authentication here.
      firebaseReady = true;
      await _setUpCrashReporting();
    } on Object {
      firebaseStartupIssue = FirebaseStartupIssue.initializationFailed;
      firebaseReady = false;
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(firebaseReady),
        firebaseStartupIssueProvider.overrideWithValue(firebaseStartupIssue),
      ],
      child: const MasilPetApp(),
    ),
  );
}

/// Crashlytics has no web SDK, so crash reporting only wires up on the
/// platforms that support it; the web build keeps Flutter's default
/// console error output.
Future<void> _setUpCrashReporting() async {
  if (kIsWeb) {
    return;
  }
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
