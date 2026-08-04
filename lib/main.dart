import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/state.dart';

/// `Firebase.initializeApp`이 이 시간 안에 끝나지 않으면 기기 내 진행으로
/// 시작한다. 네트워크가 막힌 환경에서 첫 화면이 무한정 늦어지는 것을 막는다.
const _firebaseInitTimeout = Duration(seconds: 5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  var firebaseStartupIssue = FirebaseStartupIssue.none;
  Future<void>? onlineAuthReady;
  if (!DefaultFirebaseOptions.hasRequiredConfiguration) {
    firebaseStartupIssue = FirebaseStartupIssue.missingWebConfiguration;
  } else {
    try {
      // 초기화는 로컬 작업이라 빠르지만, 플러그인 채널이 막히는 경우까지
      // 감안해 상한을 둔다.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(_firebaseInitTimeout);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      // 익명 로그인은 네트워크 왕복이라 첫 프레임을 붙잡아서는 안 된다.
      // 여기서는 시작만 시키고, 결과는 서버를 처음 부르는 쪽에서 기다린다.
      onlineAuthReady = _signInAnonymouslyIfNeeded();
      // User progress writes are handled by the authenticated backend, so the
      // client only needs Firebase initialization and authentication here.
      firebaseReady = true;
      unawaited(_setUpCrashReporting());
    } on Object {
      firebaseStartupIssue = FirebaseStartupIssue.initializationFailed;
      firebaseReady = false;
      onlineAuthReady = null;
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(firebaseReady),
        firebaseStartupIssueProvider.overrideWithValue(firebaseStartupIssue),
        onlineAuthReadyProvider.overrideWithValue(onlineAuthReady),
      ],
      child: const MasilPetApp(),
    ),
  );
}

Future<void> _signInAnonymouslyIfNeeded() async {
  if (FirebaseAuth.instance.currentUser != null) {
    return;
  }
  await FirebaseAuth.instance.signInAnonymously();
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
