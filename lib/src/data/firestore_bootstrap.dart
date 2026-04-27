import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseBootstrapService {
  FirebaseBootstrapService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> ensureUserBootstrap() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (snapshot.exists) {
        transaction.set(
          userRef,
          {'lastLoginAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        return;
      }

      transaction.set(userRef, {
        'activePetId': 'pet-starter-wave-naru',
        'createdAt': FieldValue.serverTimestamp(),
        'displayName': '부산 여행자',
        'homeTheme': 'busan-basic',
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      transaction.set(userRef.collection('pets').doc('pet-starter-wave-naru'), {
        'templateId': 'wave-naru',
        'name': '파도나루',
        'stage': 'baby',
        'level': 1,
        'stats': {
          'exp': 20,
          'mood': 20,
          'knowledge': 5,
          'affinity': 8,
        },
        'originRegionId': 'busan',
        'hatchedAt': FieldValue.serverTimestamp(),
        'lastInteractedAt': null,
      });
      transaction.set(userRef.collection('eggs').doc('egg-harbor-maru'), {
        'templateId': 'harbor-maru',
        'originRegionId': 'busan',
        'progress': 1200,
        'requiredSteps': 3500,
        'status': 'incubating',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
