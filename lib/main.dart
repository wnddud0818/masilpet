import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/data/firestore_bootstrap.dart';
import 'src/app.dart';
import 'src/state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    try {
      await FirebaseBootstrapService().ensureUserBootstrap();
    } on Object {
      // The demo app can still run if Firestore is not configured yet.
    }
    firebaseReady = true;
  } on Object {
    firebaseReady = false;
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const MasilPetApp(),
    ),
  );
}
