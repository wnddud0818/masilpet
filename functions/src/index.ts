import {initializeApp} from 'firebase-admin/app';
import {FieldValue, Timestamp, getFirestore} from 'firebase-admin/firestore';
import type {DocumentReference, Transaction} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {logger} from 'firebase-functions';
import {defineSecret} from 'firebase-functions/params';

initializeApp();

const db = getFirestore();
const functionRegion = 'asia-northeast3';
const checkInRadiusMeters = 150;
const maxDailyCheckIns = 20;
const maxStepDeltaPerCall = 3000;
const maxDailyStepDelta = 12000;
const tourApiKey = defineSecret('TOUR_API_KEY');
const starterPetId = 'pet-starter-wave-naru';
const starterEggId = 'egg-harbor-maru';

type PoiCategory =
  | 'nature'
  | 'food'
  | 'festival'
  | 'culture'
  | 'history'
  | 'shopping'
  | 'other';

type GrowthStats = {
  exp: number;
  mood: number;
  knowledge: number;
  affinity: number;
};

type PoiDoc = {
  title: string;
  regionId: string;
  category: PoiCategory;
  lat: number;
  lng: number;
  tourApiContentId?: string;
};

type PetStage = 'baby' | 'grown' | 'evolved';

type PetDoc = {
  templateId: string;
  name: string;
  stage: PetStage;
  level: number;
  stats: GrowthStats;
  originRegionId: string;
};

type EggDoc = {
  templateId: string;
  originRegionId: string;
  progress: number;
  requiredSteps: number;
  status: 'incubating' | 'hatchable' | 'hatched';
};

const busanRegionSeed = {
  name: '부산광역시',
  areaCode: '6',
  center: {lat: 35.1796, lng: 129.0756},
  pilotEnabled: true,
};

const busanPoiSeed: Array<PoiDoc & {id: string; shortDescription: string}> = [
  {
    id: 'busan-haeundae-beach',
    tourApiContentId: 'seed-001',
    title: '해운대 해수욕장',
    regionId: 'busan',
    category: 'nature',
    lat: 35.1587,
    lng: 129.1604,
    shortDescription: '부산의 바다 경험을 대표하는 자연 POI',
  },
  {
    id: 'busan-gwangalli',
    tourApiContentId: 'seed-002',
    title: '광안리 해변',
    regionId: 'busan',
    category: 'nature',
    lat: 35.1532,
    lng: 129.1187,
    shortDescription: '광안대교를 배경으로 걷는 부산 야경 코스',
  },
  {
    id: 'busan-gamcheon',
    tourApiContentId: 'seed-003',
    title: '감천문화마을',
    regionId: 'busan',
    category: 'culture',
    lat: 35.0975,
    lng: 129.0107,
    shortDescription: '골목, 색채, 지역 이야기를 담은 문화 POI',
  },
  {
    id: 'busan-biff',
    tourApiContentId: 'seed-004',
    title: 'BIFF 광장',
    regionId: 'busan',
    category: 'culture',
    lat: 35.0985,
    lng: 129.0286,
    shortDescription: '영화 도시 부산의 상징적인 문화 거점',
  },
  {
    id: 'busan-jagalchi',
    tourApiContentId: 'seed-005',
    title: '자갈치시장',
    regionId: 'busan',
    category: 'food',
    lat: 35.0969,
    lng: 129.0305,
    shortDescription: '부산 식문화와 시장 활기를 만나는 음식 POI',
  },
  {
    id: 'busan-gukje-market',
    tourApiContentId: 'seed-006',
    title: '국제시장',
    regionId: 'busan',
    category: 'shopping',
    lat: 35.1016,
    lng: 129.0284,
    shortDescription: '오래된 상권과 골목 탐험이 연결되는 시장 POI',
  },
  {
    id: 'busan-beomeosa',
    tourApiContentId: 'seed-007',
    title: '범어사',
    regionId: 'busan',
    category: 'history',
    lat: 35.2836,
    lng: 129.0686,
    shortDescription: '역사와 산책 동선을 함께 담은 역사 POI',
  },
  {
    id: 'busan-museum',
    tourApiContentId: 'seed-008',
    title: '부산박물관',
    regionId: 'busan',
    category: 'culture',
    lat: 35.1282,
    lng: 129.092,
    shortDescription: '부산의 역사와 문화를 학습하는 문화시설',
  },
  {
    id: 'busan-cinema-center',
    tourApiContentId: 'seed-009',
    title: '영화의전당',
    regionId: 'busan',
    category: 'culture',
    lat: 35.171,
    lng: 129.127,
    shortDescription: '영화제와 지역 문화 이벤트의 중심지',
  },
  {
    id: 'busan-fireworks',
    tourApiContentId: 'seed-010',
    title: '부산불꽃축제',
    regionId: 'busan',
    category: 'festival',
    lat: 35.1532,
    lng: 129.1187,
    shortDescription: '기분 지표 보상에 특화된 축제 POI',
  },
  {
    id: 'busan-spa-land',
    tourApiContentId: 'seed-011',
    title: '해운대 온천권',
    regionId: 'busan',
    category: 'other',
    lat: 35.1632,
    lng: 129.1636,
    shortDescription: '휴식과 회복 콘셉트의 기타 POI',
  },
  {
    id: 'busan-dongbaek',
    tourApiContentId: 'seed-012',
    title: '동백섬',
    regionId: 'busan',
    category: 'nature',
    lat: 35.1527,
    lng: 129.1522,
    shortDescription: '해안 산책과 재방문 친밀도에 적합한 자연 POI',
  },
];

const busanPetTemplateSeed = [
  {
    id: 'wave-naru',
    name: '파도나루',
    regionId: 'busan',
    rarity: 'common',
    primaryCategory: 'nature',
    basePersonality: '바다 산책을 좋아하고 새로운 길을 먼저 살핀다.',
    colorValue: 0x0ea5e9,
    initials: 'PN',
    assetKey: 'red_scarf_dori',
  },
  {
    id: 'harbor-maru',
    name: '항구마루',
    regionId: 'busan',
    rarity: 'common',
    primaryCategory: 'food',
    basePersonality: '시장과 골목의 소리에 민감하고 먹거리 이야기에 밝다.',
    colorValue: 0xf97316,
    initials: 'HM',
    assetKey: 'bandana_tanuki',
  },
  {
    id: 'film-bori',
    name: '필름보리',
    regionId: 'busan',
    rarity: 'rare',
    primaryCategory: 'culture',
    basePersonality: '장면과 대사를 기억하며 문화 공간에서 활발해진다.',
    colorValue: 0x7c3aed,
    initials: 'FB',
    assetKey: 'wink_yellow_pup',
  },
  {
    id: 'spring-dami',
    name: '온천다미',
    regionId: 'busan',
    rarity: 'rare',
    primaryCategory: 'other',
    basePersonality: '차분하고 회복을 좋아하며 긴 산책 뒤에 힘을 낸다.',
    colorValue: 0x14b8a6,
    initials: 'OD',
    assetKey: 'flower_mint_buddy',
  },
  {
    id: 'story-goun',
    name: '설화고운',
    regionId: 'busan',
    rarity: 'epic',
    primaryCategory: 'history',
    basePersonality: '오래된 장소의 이름과 이야기를 차근차근 알려준다.',
    colorValue: 0x8b5cf6,
    initials: 'SG',
    assetKey: 'autumn_leaf_sprite',
  },
];

const dialogueSeed = [
  {
    id: 'wave-naru-default',
    templateId: 'wave-naru',
    trigger: 'default',
    text: '오늘 바람은 해운대 쪽에서 불어와. 가까운 산책길부터 살펴보자.',
  },
  {
    id: 'wave-naru-nature',
    templateId: 'wave-naru',
    trigger: 'nature',
    text: '바다 근처를 걸으니 몸이 가벼워졌어. 다음엔 동백섬 길도 좋겠다.',
  },
  {
    id: 'wave-naru-food',
    templateId: 'wave-naru',
    trigger: 'food',
    text: '시장 골목을 지나면 파도 소리와 다른 활기가 느껴져. 오늘 기분이 든든해.',
  },
  {
    id: 'wave-naru-festival',
    templateId: 'wave-naru',
    trigger: 'festival',
    text: '축제 불빛이 물결처럼 번졌어. 부산의 밤길은 걸을수록 반짝인다.',
  },
  {
    id: 'wave-naru-culture',
    templateId: 'wave-naru',
    trigger: 'culture',
    text: '문화 공간을 지나오니 길의 표정이 달라졌어. 오늘 본 장면을 기억해둘게.',
  },
  {
    id: 'wave-naru-history',
    templateId: 'wave-naru',
    trigger: 'history',
    text: '오래된 길에도 바람길이 있구나. 조용히 걸으니 부산의 시간이 들려.',
  },
  {
    id: 'wave-naru-shopping',
    templateId: 'wave-naru',
    trigger: 'shopping',
    text: '상점 사이를 지나니 발걸음이 빨라졌어. 다음 골목도 함께 살펴보자.',
  },
  {
    id: 'wave-naru-other',
    templateId: 'wave-naru',
    trigger: 'other',
    text: '잠깐 쉬어가는 길도 산책의 일부야. 숨을 고르고 다시 움직여보자.',
  },
  {
    id: 'harbor-maru-default',
    templateId: 'harbor-maru',
    trigger: 'default',
    text: '시장 냄새가 나는 길은 그냥 지나치기 어렵지. 오늘도 한 바퀴 돌아보자.',
  },
  {
    id: 'harbor-maru-nature',
    templateId: 'harbor-maru',
    trigger: 'nature',
    text: '바다 바람을 맡으니 배가 더 고파졌어. 산책 뒤에는 따뜻한 간식이 좋겠다.',
  },
  {
    id: 'harbor-maru-food',
    templateId: 'harbor-maru',
    trigger: 'food',
    text: '자갈치 쪽은 늘 활기가 있어. 기분이 확 올라간다.',
  },
  {
    id: 'harbor-maru-festival',
    templateId: 'harbor-maru',
    trigger: 'festival',
    text: '축제 길에는 먹거리 냄새도 같이 따라와. 오늘은 기분 보상이 넉넉하겠어.',
  },
  {
    id: 'harbor-maru-culture',
    templateId: 'harbor-maru',
    trigger: 'culture',
    text: '영화와 전시 이야기를 들으니 시장 소리도 장면처럼 들려. 꽤 멋진 하루야.',
  },
  {
    id: 'harbor-maru-history',
    templateId: 'harbor-maru',
    trigger: 'history',
    text: '오래된 장소 근처엔 오래된 가게도 많지. 오늘 기억은 천천히 익어갈 거야.',
  },
  {
    id: 'harbor-maru-shopping',
    templateId: 'harbor-maru',
    trigger: 'shopping',
    text: '국제시장 같은 골목은 발걸음마다 이야기가 달라져. 잘 따라와.',
  },
  {
    id: 'harbor-maru-other',
    templateId: 'harbor-maru',
    trigger: 'other',
    text: '온천권처럼 쉬어가는 곳도 필요해. 기분을 데우고 다시 움직이자.',
  },
  {
    id: 'film-bori-default',
    templateId: 'film-bori',
    trigger: 'default',
    text: '부산의 길은 장면처럼 이어져. 오늘은 어떤 장소를 기록할까?',
  },
  {
    id: 'film-bori-nature',
    templateId: 'film-bori',
    trigger: 'nature',
    text: '해변의 빛은 매번 다른 컷 같아. 오늘 장면은 오래 남을 거야.',
  },
  {
    id: 'film-bori-food',
    templateId: 'film-bori',
    trigger: 'food',
    text: '시장 장면은 대사가 많아. 사람들 목소리까지 기록하고 싶어졌어.',
  },
  {
    id: 'film-bori-festival',
    templateId: 'film-bori',
    trigger: 'festival',
    text: '축제는 클라이맥스 같아. 음악과 불빛이 한 번에 지나갔어.',
  },
  {
    id: 'film-bori-culture',
    templateId: 'film-bori',
    trigger: 'culture',
    text: '문화 공간을 다녀오니 기억할 장면이 늘었어. 지식도 조금 자란 것 같아.',
  },
  {
    id: 'film-bori-history',
    templateId: 'film-bori',
    trigger: 'history',
    text: '역사 장소는 긴 다큐멘터리 같아. 천천히 보면 놓친 장면이 보여.',
  },
  {
    id: 'film-bori-shopping',
    templateId: 'film-bori',
    trigger: 'shopping',
    text: '상점 간판들이 화면 전환처럼 이어졌어. 다음 컷도 기대된다.',
  },
  {
    id: 'film-bori-other',
    templateId: 'film-bori',
    trigger: 'other',
    text: '쉬어가는 장면이 있어야 다음 장면이 더 선명해져. 잠깐 호흡을 맞추자.',
  },
  {
    id: 'spring-dami-default',
    templateId: 'spring-dami',
    trigger: 'default',
    text: '천천히 걸어도 괜찮아. 오래 머무는 만큼 부산과 가까워질 수 있어.',
  },
  {
    id: 'spring-dami-nature',
    templateId: 'spring-dami',
    trigger: 'nature',
    text: '바닷바람이 기분을 씻어주는 것 같아. 오늘 산책은 몸에 잘 맞아.',
  },
  {
    id: 'spring-dami-food',
    templateId: 'spring-dami',
    trigger: 'food',
    text: '따뜻한 음식 냄새가 지나가니 마음이 놓여. 천천히 에너지를 채우자.',
  },
  {
    id: 'spring-dami-festival',
    templateId: 'spring-dami',
    trigger: 'festival',
    text: '축제 길은 조금 북적이지만 괜찮아. 즐거운 소리가 기분을 올려줘.',
  },
  {
    id: 'spring-dami-culture',
    templateId: 'spring-dami',
    trigger: 'culture',
    text: '전시와 공연 이야기는 마음을 차분하게 해. 오늘 배운 걸 오래 간직하자.',
  },
  {
    id: 'spring-dami-history',
    templateId: 'spring-dami',
    trigger: 'history',
    text: '오래된 장소는 천천히 봐야 해. 숨을 고르면 더 많은 이야기가 보여.',
  },
  {
    id: 'spring-dami-shopping',
    templateId: 'spring-dami',
    trigger: 'shopping',
    text: '골목을 둘러보는 속도도 우리답게 맞추면 돼. 필요한 만큼만 걸어보자.',
  },
  {
    id: 'spring-dami-other',
    templateId: 'spring-dami',
    trigger: 'other',
    text: '휴식 장소를 찾은 건 좋은 선택이야. 회복도 탐험의 중요한 보상이니까.',
  },
  {
    id: 'story-goun-default',
    templateId: 'story-goun',
    trigger: 'default',
    text: '오래된 이름에는 이유가 있어. 오늘 방문한 곳의 이야기도 찾아보자.',
  },
  {
    id: 'story-goun-nature',
    templateId: 'story-goun',
    trigger: 'nature',
    text: '해안길의 이름에도 오래된 기억이 숨어 있어. 바람이 먼저 알려주네.',
  },
  {
    id: 'story-goun-food',
    templateId: 'story-goun',
    trigger: 'food',
    text: '시장 음식은 사람들의 생활사를 품고 있어. 한 입의 이야기도 가볍지 않아.',
  },
  {
    id: 'story-goun-festival',
    templateId: 'story-goun',
    trigger: 'festival',
    text: '축제는 도시가 기억을 함께 나누는 방식이야. 오늘의 소리도 기록해두자.',
  },
  {
    id: 'story-goun-culture',
    templateId: 'story-goun',
    trigger: 'culture',
    text: '문화 공간에는 지금의 부산이 남기는 문장이 있어. 지식이 또 깊어졌어.',
  },
  {
    id: 'story-goun-history',
    templateId: 'story-goun',
    trigger: 'history',
    text: '역사 명소를 걸으면 기억이 깊어진다. 내 지식도 함께 자랐어.',
  },
  {
    id: 'story-goun-shopping',
    templateId: 'story-goun',
    trigger: 'shopping',
    text: '오래된 상권은 도시의 생활 기록이야. 간판 하나도 허투루 보이지 않아.',
  },
  {
    id: 'story-goun-other',
    templateId: 'story-goun',
    trigger: 'other',
    text: '쉬어가는 장소에도 이름의 이유가 있어. 잠시 멈춰서 들어보자.',
  },
];

export const seedStarterRegionData = onCall({region: functionRegion}, async (request) => {
  requireOperator(request.auth?.uid, request.auth?.token);

  const batch = db.batch();
  batch.set(db.collection('regions').doc('busan'), busanRegionSeed, {merge: true});

  for (const poi of busanPoiSeed) {
    const {id, ...data} = poi;
    batch.set(db.collection('pois').doc(id), data, {merge: true});
  }

  for (const template of busanPetTemplateSeed) {
    const {id, ...data} = template;
    batch.set(db.collection('petTemplates').doc(id), data, {merge: true});
  }

  for (const dialogue of dialogueSeed) {
    const {id, ...data} = dialogue;
    batch.set(db.collection('dialogueSets').doc(id), data, {merge: true});
  }

  await batch.commit();
  return {
    regionCount: 1,
    poiCount: busanPoiSeed.length,
    petTemplateCount: busanPetTemplateSeed.length,
    dialogueCount: dialogueSeed.length,
  };
});

export const ensureUserBootstrap = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const userRef = db.collection('users').doc(uid);
  const now = Timestamp.now();

  await db.runTransaction(async (transaction) => {
    const userSnap = await transaction.get(userRef);
    if (userSnap.exists) {
      transaction.set(userRef, {lastLoginAt: now}, {merge: true});
      return;
    }

    setStarterUser(transaction, userRef, now);
  });

  return {success: true};
});

export const deleteUserProgress = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const userRef = db.collection('users').doc(uid);

  await db.recursiveDelete(userRef);
  logger.info('Deleted MasilPet user progress');
  return {success: true};
});

export const syncBusanPois = onCall({region: functionRegion, secrets: [tourApiKey]}, async (request) => {
  requireOperator(request.auth?.uid, request.auth?.token);

  const serviceKey = tourApiKey.value();
  if (!serviceKey) {
    throw new HttpsError('failed-precondition', 'TOUR_API_KEY is not configured.');
  }

  const url = new URL('https://apis.data.go.kr/B551011/KorService2/areaBasedList2');
  url.searchParams.set('serviceKey', serviceKey);
  url.searchParams.set('MobileOS', 'ETC');
  url.searchParams.set('MobileApp', 'MasilPet');
  url.searchParams.set('_type', 'json');
  url.searchParams.set('areaCode', '6');
  url.searchParams.set('numOfRows', '100');
  url.searchParams.set('pageNo', '1');

  const response = await fetch(url);
  if (!response.ok) {
    throw new HttpsError('unavailable', `TourAPI request failed: ${response.status}`);
  }

  const payload = (await response.json()) as TourApiResponse;
  const items = normalizeTourApiItems(payload);
  const batch = db.batch();
  let count = 0;

  for (const item of items) {
    if (!item.contentid || !item.title || !item.mapx || !item.mapy) {
      continue;
    }
    const poiRef = db.collection('pois').doc(`tourapi-${item.contentid}`);
    batch.set(
      poiRef,
      {
        tourApiContentId: item.contentid,
        title: item.title,
        regionId: 'busan',
        category: mapTourCategory(item.cat1, item.contenttypeid),
        lat: Number(item.mapy),
        lng: Number(item.mapx),
        sourceUpdatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    count += 1;
  }

  await batch.commit();
  logger.info('Synced Busan POIs', {count});
  return {count};
});

export const getNearbyPois = onCall({region: functionRegion}, async (request) => {
  requireAuth(request.auth?.uid);
  const lat = Number(request.data?.lat);
  const lng = Number(request.data?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new HttpsError('invalid-argument', 'lat and lng are required.');
  }

  const snapshot = await db
    .collection('pois')
    .where('regionId', '==', 'busan')
    .limit(250)
    .get();

  const pois = snapshot.docs
    .map((doc) => ({id: doc.id, ...(doc.data() as PoiDoc)}))
    .map((poi) => ({
      ...poi,
      distanceMeters: distanceMeters(lat, lng, poi.lat, poi.lng),
    }))
    .sort((left, right) => left.distanceMeters - right.distanceMeters)
    .slice(0, 30);

  return {pois};
});

export const attemptCheckIn = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const poiId = String(request.data?.poiId ?? '');
  const lat = Number(request.data?.lat);
  const lng = Number(request.data?.lng);
  if (!poiId || !Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new HttpsError('invalid-argument', 'poiId, lat and lng are required.');
  }

  const poiRef = db.collection('pois').doc(poiId);
  const poiSnap = await poiRef.get();
  if (!poiSnap.exists) {
    throw new HttpsError('not-found', 'POI not found.');
  }

  const poi = poiSnap.data() as PoiDoc;
  const distance = distanceMeters(lat, lng, poi.lat, poi.lng);
  if (distance > checkInRadiusMeters) {
    throw new HttpsError('failed-precondition', 'User is outside check-in radius.', {
      distanceMeters: Math.round(distance),
    });
  }

  const now = Timestamp.now();
  const today = new Date();
  const dayStart = startOfKoreanDay(today);
  const dayKey = koreanDayKey(today);
  const checkinsRef = db.collection('users').doc(uid).collection('checkins');
  const checkinRef = checkinsRef.doc(checkInDocumentId(poiId, dayKey));

  const reward = rewardFor(poi.category);
  const eggProgress = eggProgressFor(poi.category);
  const userRef = db.collection('users').doc(uid);
  let updatedPet: {id: string; stats: GrowthStats; level: number; stage: PetStage} | null = null;

  await db.runTransaction(async (transaction) => {
    const duplicateSnap = await transaction.get(checkinRef);
    if (duplicateSnap.exists) {
      throw new HttpsError('already-exists', 'Already checked in to this POI today.');
    }

    const userSnap = await transaction.get(userRef);
    let activePetId = String(userSnap.data()?.activePetId ?? starterPetId);
    if (!activePetId) {
      activePetId = starterPetId;
    }
    let activePetRef = userRef.collection('pets').doc(activePetId);
    const activePetSnap = await transaction.get(activePetRef);
    const openEggs = await transaction.get(
      userRef.collection('eggs').where('status', 'in', ['incubating', 'hatchable']).limit(3),
    );
    const todayCheckins = await transaction.get(
      checkinsRef.where('createdAt', '>=', Timestamp.fromDate(dayStart)).limit(maxDailyCheckIns),
    );
    if (todayCheckins.size >= maxDailyCheckIns) {
      throw new HttpsError('failed-precondition', 'Daily check-in limit reached.');
    }

    const needsStarterBootstrap = !userSnap.exists || !activePetSnap.exists;
    if (needsStarterBootstrap) {
      activePetId = starterPetId;
      activePetRef = userRef.collection('pets').doc(starterPetId);
      setStarterUser(transaction, userRef, now);
    }

    transaction.set(checkinRef, {
      poiId,
      regionId: poi.regionId,
      category: poi.category,
      lat,
      lng,
      distanceMeters: distance,
      rewardApplied: true,
      createdAt: now,
    });

    if (activePetId && activePetRef) {
      const pet = needsStarterBootstrap
        ? starterPetRuntimeDoc()
        : activePetSnap.data() as PetDoc;
      const stats = addStats(pet.stats, reward);
      const level = levelFor(stats);
      const stage = stageFor(level, stats, pet.stage);
      transaction.set(
        activePetRef,
        {
          stats,
          level,
          stage,
          lastInteractedAt: now,
        },
        {merge: true},
      );
      updatedPet = {id: activePetId, stats, level, stage};
    }

    for (const egg of openEggs.docs) {
      const eggData = egg.data() as EggDoc;
      if (eggData.status === 'hatchable') {
        continue;
      }
      const progress = Math.min(eggData.requiredSteps, eggData.progress + eggProgress);
      transaction.set(
        egg.ref,
        {
          progress,
          status: progress >= eggData.requiredSteps ? 'hatchable' : 'incubating',
        },
        {merge: true},
      );
    }

    if (needsStarterBootstrap && openEggs.empty) {
      const starterEgg = starterEggRuntimeDoc();
      const progress = Math.min(starterEgg.requiredSteps, starterEgg.progress + eggProgress);
      transaction.set(
        userRef.collection('eggs').doc(starterEggId),
        {
          ...starterEggData(now),
          progress,
          status: progress >= starterEgg.requiredSteps ? 'hatchable' : 'incubating',
        },
        {merge: true},
      );
    }

    if (!needsStarterBootstrap && openEggs.empty &&
      (todayCheckins.empty || poi.category === 'history' || poi.category === 'festival')) {
      const templateId = templateForCategory(poi.category);
      transaction.set(userRef.collection('eggs').doc(`egg-${templateId}-${now.toMillis()}`), {
        templateId,
        originRegionId: poi.regionId,
        progress: 0,
        requiredSteps: 3500,
        status: 'incubating',
        createdAt: now,
      });
    }

    transaction.set(
      userRef,
      {
        lastCheckInAt: now,
        updatedAt: now,
      },
      {merge: true},
    );
  });

  return {
    success: true,
    distanceMeters: Math.round(distance),
    reward,
    eggProgress,
    updatedPet,
  };
});

export const hatchEgg = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const eggId = String(request.data?.eggId ?? '');
  if (!eggId) {
    throw new HttpsError('invalid-argument', 'eggId is required.');
  }

  const userRef = db.collection('users').doc(uid);
  const eggRef = userRef.collection('eggs').doc(eggId);
  const now = Timestamp.now();
  let hatchedPetId = '';

  await db.runTransaction(async (transaction) => {
    const eggSnap = await transaction.get(eggRef);
    if (!eggSnap.exists) {
      throw new HttpsError('not-found', 'Egg not found.');
    }

    const egg = eggSnap.data() as EggDoc;
    if (egg.status !== 'hatchable') {
      throw new HttpsError('failed-precondition', 'Egg is not hatchable yet.');
    }

    const template = busanPetTemplateSeed.find((item) => item.id === egg.templateId);
    if (!template) {
      throw new HttpsError('failed-precondition', 'Pet template not found.');
    }

    hatchedPetId = `pet-${egg.templateId}-${now.toMillis()}`;
    transaction.set(userRef.collection('pets').doc(hatchedPetId), {
      templateId: egg.templateId,
      name: template.name,
      stage: 'baby',
      level: 1,
      stats: {exp: 10, mood: 15, knowledge: 5, affinity: 10},
      originRegionId: egg.originRegionId,
      hatchedAt: now,
      lastInteractedAt: null,
    });
    transaction.delete(eggRef);
    transaction.set(
      userRef,
      {
        activePetId: hatchedPetId,
        updatedAt: now,
      },
      {merge: true},
    );
  });

  return {petId: hatchedPetId};
});

export const applyStepProgress = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const requestedStepDelta = Number(request.data?.stepDelta ?? 0);
  if (!Number.isInteger(requestedStepDelta) || requestedStepDelta <= 0) {
    throw new HttpsError('invalid-argument', 'stepDelta must be positive.');
  }
  if (requestedStepDelta > maxStepDeltaPerCall) {
    throw new HttpsError('invalid-argument', `stepDelta must be ${maxStepDeltaPerCall} or less.`);
  }

  const userRef = db.collection('users').doc(uid);
  const now = Timestamp.now();
  const dayKey = koreanDayKey(new Date());
  let hatchableCount = 0;
  let appliedStepDelta = 0;

  await db.runTransaction(async (transaction) => {
    const userSnap = await transaction.get(userRef);
    const needsStarterBootstrap = !userSnap.exists;
    const userData = userSnap.data() ?? {};
    const usedToday = userData.stepCreditDay === dayKey
      ? Number(userData.stepCreditToday ?? 0)
      : 0;
    const remainingToday = Math.max(0, maxDailyStepDelta - usedToday);
    if (remainingToday <= 0) {
      throw new HttpsError('failed-precondition', 'Daily step progress limit reached.');
    }

    appliedStepDelta = Math.min(requestedStepDelta, remainingToday);
    const eggs = await transaction.get(userRef.collection('eggs'));

    if (needsStarterBootstrap) {
      setStarterUser(transaction, userRef, now);
    }

    for (const egg of eggs.docs) {
      const data = egg.data();
      if (data.status === 'hatched') {
        continue;
      }
      const requiredSteps = Number(data.requiredSteps ?? 3500);
      const progress = Math.min(requiredSteps, Number(data.progress ?? 0) + appliedStepDelta);
      const status = progress >= requiredSteps ? 'hatchable' : 'incubating';
      if (status === 'hatchable') {
        hatchableCount += 1;
      }
      transaction.update(egg.ref, {progress, status});
    }

    if (needsStarterBootstrap && eggs.empty) {
      const starterEgg = starterEggRuntimeDoc();
      const progress = Math.min(starterEgg.requiredSteps, starterEgg.progress + appliedStepDelta);
      const status = progress >= starterEgg.requiredSteps ? 'hatchable' : 'incubating';
      if (status === 'hatchable') {
        hatchableCount += 1;
      }
      transaction.set(
        userRef.collection('eggs').doc(starterEggId),
        {
          ...starterEggData(now),
          progress,
          status,
        },
        {merge: true},
      );
    }

    transaction.set(
      userRef,
      {
        stepCreditDay: dayKey,
        stepCreditToday: usedToday + appliedStepDelta,
        updatedAt: now,
      },
      {merge: true},
    );
  });

  return {hatchableCount, appliedStepDelta};
});

export const interactWithPet = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const petId = String(request.data?.petId ?? '');
  const actionType = String(request.data?.actionType ?? '');
  if (!petId || !['talk', 'feed'].includes(actionType)) {
    throw new HttpsError('invalid-argument', 'petId and valid actionType are required.');
  }

  const reward = actionType === 'talk'
    ? {exp: 2, mood: 4, knowledge: 0, affinity: 1}
    : {exp: 3, mood: 8, knowledge: 0, affinity: 2};

  const userRef = db.collection('users').doc(uid);
  const petRef = userRef.collection('pets').doc(petId);
  let updatedPet: {id: string; stats: GrowthStats; level: number; stage: PetStage} | null = null;

  await db.runTransaction(async (transaction) => {
    const userSnap = await transaction.get(userRef);
    const petSnap = await transaction.get(petRef);
    const needsStarterBootstrap = !userSnap.exists || !petSnap.exists;
    if (!petSnap.exists && petId !== starterPetId) {
      throw new HttpsError('not-found', 'Pet not found.');
    }
    if (needsStarterBootstrap) {
      setStarterUser(transaction, userRef, FieldValue.serverTimestamp());
    }

    const pet = needsStarterBootstrap
      ? starterPetRuntimeDoc()
      : petSnap.data() as PetDoc;
    const stats = addStats(pet.stats, reward);
    const level = levelFor(stats);
    const stage = stageFor(level, stats, pet.stage);
    transaction.set(
      petRef,
      {
        stats,
        level,
        stage,
        lastInteractedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    updatedPet = {id: petId, stats, level, stage};
  });

  return {reward, updatedPet};
});

function setStarterUser(
  transaction: Transaction,
  userRef: DocumentReference,
  now: Timestamp | FieldValue,
): void {
  transaction.set(userRef, {
    activePetId: starterPetId,
    createdAt: now,
    displayName: '부산 여행자',
    homeTheme: 'busan-basic',
    lastLoginAt: now,
  }, {merge: true});
  transaction.set(userRef.collection('pets').doc(starterPetId), starterPetData(now), {merge: true});
  transaction.set(userRef.collection('eggs').doc(starterEggId), starterEggData(now), {merge: true});
}

function starterPetData(now: Timestamp | FieldValue) {
  return {
    ...starterPetRuntimeDoc(),
    hatchedAt: now,
    lastInteractedAt: null,
  };
}

function starterEggData(now: Timestamp | FieldValue) {
  return {
    ...starterEggRuntimeDoc(),
    createdAt: now,
  };
}

function starterPetRuntimeDoc(): PetDoc {
  return {
    templateId: 'wave-naru',
    name: '파도나루',
    stage: 'baby',
    level: 1,
    stats: {exp: 20, mood: 20, knowledge: 5, affinity: 8},
    originRegionId: 'busan',
  };
}

function starterEggRuntimeDoc(): EggDoc {
  return {
    templateId: 'harbor-maru',
    originRegionId: 'busan',
    progress: 1200,
    requiredSteps: 3500,
    status: 'incubating',
  };
}

function requireAuth(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  return uid;
}

function requireOperator(uid: string | undefined, token: unknown): string {
  const authenticatedUid = requireAuth(uid);
  const claims = token as {operator?: unknown} | undefined;
  if (claims?.operator !== true) {
    throw new HttpsError('permission-denied', 'Operator permission is required.');
  }
  return authenticatedUid;
}

function rewardFor(category: PoiCategory): GrowthStats {
  switch (category) {
    case 'food':
      return {exp: 18, mood: 16, knowledge: 1, affinity: 5};
    case 'festival':
      return {exp: 24, mood: 22, knowledge: 3, affinity: 8};
    case 'culture':
      return {exp: 20, mood: 5, knowledge: 18, affinity: 6};
    case 'history':
      return {exp: 22, mood: 4, knowledge: 22, affinity: 8};
    case 'nature':
      return {exp: 18, mood: 8, knowledge: 4, affinity: 12};
    case 'shopping':
      return {exp: 16, mood: 10, knowledge: 4, affinity: 6};
    case 'other':
      return {exp: 14, mood: 8, knowledge: 4, affinity: 5};
  }
}

function eggProgressFor(category: PoiCategory): number {
  switch (category) {
    case 'festival':
      return 820;
    case 'history':
      return 760;
    case 'culture':
      return 700;
    case 'nature':
      return 680;
    case 'food':
      return 620;
    case 'shopping':
      return 600;
    case 'other':
      return 540;
  }
}

function templateForCategory(category: PoiCategory): string {
  const matched = busanPetTemplateSeed.find((template) => template.primaryCategory === category);
  return matched?.id ?? 'wave-naru';
}

function addStats(left: GrowthStats, right: GrowthStats): GrowthStats {
  return {
    exp: Number(left.exp ?? 0) + right.exp,
    mood: Number(left.mood ?? 0) + right.mood,
    knowledge: Number(left.knowledge ?? 0) + right.knowledge,
    affinity: Number(left.affinity ?? 0) + right.affinity,
  };
}

function levelFor(stats: GrowthStats): number {
  return Math.max(1, Math.floor(stats.exp / 100) + 1);
}

function stageFor(level: number, stats: GrowthStats, currentStage: PetStage): PetStage {
  if (level >= 5 && stats.affinity >= 100 && stats.knowledge >= 50) {
    return 'evolved';
  }
  if (level >= 3) {
    return 'grown';
  }
  return currentStage;
}

function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const radius = 6371000;
  const dLat = radians(lat2 - lat1);
  const dLng = radians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(radians(lat1)) *
      Math.cos(radians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  return radius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function radians(degrees: number): number {
  return degrees * Math.PI / 180;
}

function startOfKoreanDay(date: Date): Date {
  const offsetMs = 9 * 60 * 60 * 1000;
  const shifted = new Date(date.getTime() + offsetMs);
  const startOfShiftedDay = Date.UTC(
    shifted.getUTCFullYear(),
    shifted.getUTCMonth(),
    shifted.getUTCDate(),
  );
  return new Date(startOfShiftedDay - offsetMs);
}

function koreanDayKey(date: Date): string {
  const offsetMs = 9 * 60 * 60 * 1000;
  return new Date(date.getTime() + offsetMs).toISOString().slice(0, 10);
}

function checkInDocumentId(poiId: string, dayKey: string): string {
  return `${poiId}_${dayKey}`;
}

function mapTourCategory(cat1?: string, contentTypeId?: string): PoiCategory {
  if (contentTypeId === '39') {
    return 'food';
  }
  if (contentTypeId === '15') {
    return 'festival';
  }
  if (contentTypeId === '14') {
    return 'culture';
  }
  if (contentTypeId === '38') {
    return 'shopping';
  }
  if (cat1 === 'A01') {
    return 'nature';
  }
  if (cat1 === 'A02') {
    return 'history';
  }
  return 'other';
}

function normalizeTourApiItems(payload: TourApiResponse): TourApiItem[] {
  const items = payload.response?.body?.items?.item;
  if (!items) {
    return [];
  }
  return Array.isArray(items) ? items : [items];
}

type TourApiResponse = {
  response?: {
    body?: {
      items?: {
        item?: TourApiItem[] | TourApiItem;
      };
    };
  };
};

type TourApiItem = {
  contentid?: string;
  contenttypeid?: string;
  title?: string;
  cat1?: string;
  mapx?: string;
  mapy?: string;
};
