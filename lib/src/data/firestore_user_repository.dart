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
      activePetId: _stringFromValue(userDoc.data()?['activePetId']),
      pets: petsSnapshot.docs
          .map((doc) => _petFromDoc(doc.id, doc.data()))
          .toList(),
      eggs: eggsSnapshot.docs
          .map((doc) => _eggFromDoc(doc.id, doc.data()))
          .toList(),
      checkIns: checkInsSnapshot.docs
          .map((doc) => _checkInFromDoc(doc.id, doc.data()))
          .toList(),
    );
  }
}

Pet _petFromDoc(String id, Map<String, dynamic> data) {
  return Pet(
    id: id,
    templateId: _stringFromValue(data['templateId'], fallback: 'wave-naru'),
    name: _stringFromValue(data['name'], fallback: '마실펫'),
    stage: _petStageFromName(_stringFromValue(data['stage'])),
    level: _intFromValue(data['level']) ?? 1,
    stats: _statsFromMap(_mapFromValue(data['stats'])),
    originRegionId: _stringFromValue(data['originRegionId'], fallback: 'busan'),
    hatchedAt: _dateFromValue(data['hatchedAt']),
    lastInteractedAt: _nullableDateFromValue(data['lastInteractedAt']),
  );
}

Egg _eggFromDoc(String id, Map<String, dynamic> data) {
  return Egg(
    id: id,
    templateId: _stringFromValue(data['templateId'], fallback: 'wave-naru'),
    originRegionId: _stringFromValue(data['originRegionId'], fallback: 'busan'),
    progress: _intFromValue(data['progress']) ?? 0,
    requiredSteps: _intFromValue(data['requiredSteps']) ?? 3500,
    status: _eggStatusFromName(_stringFromValue(data['status'])),
    createdAt: _dateFromValue(data['createdAt']),
  );
}

CheckIn _checkInFromDoc(String id, Map<String, dynamic> data) {
  return CheckIn(
    id: id,
    poiId: _stringFromValue(data['poiId']),
    regionId: _stringFromValue(data['regionId'], fallback: 'busan'),
    category: _categoryFromName(_stringFromValue(data['category'])),
    createdAt: _dateFromValue(data['createdAt']),
    distanceMeters: _doubleFromValue(data['distanceMeters']) ?? 0,
    rewardApplied: data['rewardApplied'] == true,
    reward: _rewardFromMap(data['reward'], data['eggProgress']),
  );
}

CheckInReward? _rewardFromMap(Object? rewardValue, Object? eggProgressValue) {
  final rewardMap = _mapFromValue(rewardValue);
  if (rewardMap.isEmpty && eggProgressValue == null) {
    return null;
  }
  return CheckInReward(
    stats: _statsFromMap(rewardMap),
    eggProgress: _intFromValue(eggProgressValue) ?? 0,
  );
}

GrowthStats _statsFromMap(Map<String, dynamic> map) {
  return GrowthStats(
    exp: _intFromValue(map['exp']) ?? 0,
    mood: _intFromValue(map['mood']) ?? 0,
    knowledge: _intFromValue(map['knowledge']) ?? 0,
    affinity: _intFromValue(map['affinity']) ?? 0,
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

DateTime? _nullableDateFromValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

Map<String, dynamic> _mapFromValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }
  return const {};
}

String _stringFromValue(Object? value, {String fallback = ''}) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return fallback;
}

int? _intFromValue(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return null;
}

double? _doubleFromValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
