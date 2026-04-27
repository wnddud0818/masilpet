import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

class UserProgressSnapshot {
  const UserProgressSnapshot({
    required this.activePetId,
    required this.pets,
    required this.eggs,
    required this.checkIns,
  });

  final String activePetId;
  final List<Pet> pets;
  final List<Egg> eggs;
  final List<CheckIn> checkIns;
}

class FirestoreUserRepository {
  FirestoreUserRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<UserProgressSnapshot?> loadProgress() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    if (!userDoc.exists) {
      return null;
    }

    final petsSnapshot = await userRef.collection('pets').get();
    final eggsSnapshot = await userRef.collection('eggs').get();
    final checkInsSnapshot = await userRef
        .collection('checkins')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return UserProgressSnapshot(
      activePetId: userDoc.data()?['activePetId'] as String? ?? '',
      pets: petsSnapshot.docs.map((doc) => _petFromDoc(doc.id, doc.data())).toList(),
      eggs: eggsSnapshot.docs.map((doc) => _eggFromDoc(doc.id, doc.data())).toList(),
      checkIns: checkInsSnapshot.docs.map((doc) => _checkInFromDoc(doc.id, doc.data())).toList(),
    );
  }
}

Pet _petFromDoc(String id, Map<String, dynamic> data) {
  return Pet(
    id: id,
    templateId: data['templateId'] as String? ?? 'wave-naru',
    name: data['name'] as String? ?? '마실펫',
    stage: _petStageFromName(data['stage'] as String?),
    level: (data['level'] as num? ?? 1).toInt(),
    stats: _statsFromMap(Map<String, dynamic>.from(data['stats'] as Map? ?? const {})),
    originRegionId: data['originRegionId'] as String? ?? 'busan',
    hatchedAt: _dateFromValue(data['hatchedAt']),
    lastInteractedAt: data['lastInteractedAt'] == null ? null : _dateFromValue(data['lastInteractedAt']),
  );
}

Egg _eggFromDoc(String id, Map<String, dynamic> data) {
  return Egg(
    id: id,
    templateId: data['templateId'] as String? ?? 'wave-naru',
    originRegionId: data['originRegionId'] as String? ?? 'busan',
    progress: (data['progress'] as num? ?? 0).toInt(),
    requiredSteps: (data['requiredSteps'] as num? ?? 3500).toInt(),
    status: _eggStatusFromName(data['status'] as String?),
    createdAt: _dateFromValue(data['createdAt']),
  );
}

CheckIn _checkInFromDoc(String id, Map<String, dynamic> data) {
  return CheckIn(
    id: id,
    poiId: data['poiId'] as String? ?? '',
    regionId: data['regionId'] as String? ?? 'busan',
    category: _categoryFromName(data['category'] as String?),
    createdAt: _dateFromValue(data['createdAt']),
    distanceMeters: (data['distanceMeters'] as num? ?? 0).toDouble(),
    rewardApplied: data['rewardApplied'] == true,
  );
}

GrowthStats _statsFromMap(Map<String, dynamic> map) {
  return GrowthStats(
    exp: (map['exp'] as num? ?? 0).toInt(),
    mood: (map['mood'] as num? ?? 0).toInt(),
    knowledge: (map['knowledge'] as num? ?? 0).toInt(),
    affinity: (map['affinity'] as num? ?? 0).toInt(),
  );
}

PetStage _petStageFromName(String? name) {
  return PetStage.values.firstWhere(
    (stage) => stage.name == name,
    orElse: () => PetStage.baby,
  );
}

EggStatus _eggStatusFromName(String? name) {
  return EggStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => EggStatus.incubating,
  );
}

PoiCategory _categoryFromName(String? name) {
  return PoiCategory.values.firstWhere(
    (category) => category.name == name,
    orElse: () => PoiCategory.other,
  );
}

DateTime _dateFromValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.now();
}
