import {cert, getApps, initializeApp} from 'firebase-admin/app';
import {
  FieldValue,
  Timestamp,
  getFirestore,
  initializeFirestore,
} from 'firebase-admin/firestore';
import type {
  DocumentData,
  DocumentReference,
  QueryDocumentSnapshot,
  Transaction,
  WriteBatch,
} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {logger} from 'firebase-functions';
import {defineSecret} from 'firebase-functions/params';

const firebaseClientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim();
const firebasePrivateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
const firebaseProjectId = process.env.FIREBASE_PROJECT_ID?.trim();
const externalFirebaseCredentials =
  firebaseClientEmail && firebasePrivateKey && firebaseProjectId
    ? cert({
      clientEmail: firebaseClientEmail,
      privateKey: firebasePrivateKey,
      projectId: firebaseProjectId,
    })
    : undefined;
const adminApp = getApps()[0] ?? initializeApp({
  ...(externalFirebaseCredentials
    ? {credential: externalFirebaseCredentials}
    : {}),
  ...(firebaseProjectId ? {projectId: firebaseProjectId} : {}),
});
const db = process.env.CLOUDFLARE_WORKER === 'true'
  ? initializeFirestore(adminApp, {preferRest: true})
  : getFirestore(adminApp);
const functionRegion = 'asia-northeast3';
const checkInRadiusMeters = 150;
const maxDailyCheckIns = 20;
const maxStepDeltaPerCall = 3000;
const maxDailyStepDelta = 12000;
const maxStoredEggs = 5;
const tourApiKey = defineSecret('TOUR_API_KEY');
const tourApiBaseUrl = 'https://apis.data.go.kr/B551011';
const tourApiTimeoutMs = 10000;
const tourApiMaxRetries = 2;
const tourApiRetryBaseDelayMs = 250;
// 경기도가 4,600여 건으로 가장 많다. 100건 × 60페이지면 전 지역을 덮는다.
const tourApiMaxPagesPerArea = 60;
const defaultMaxItemsPerArea = 5000;
// detailIntro2는 POI 1건당 1회 호출이라 일일 트래픽을 빠르게 소모한다.
const defaultDetailEnrichLimit = 0;
const maxDetailEnrichLimit = 500;
const starterPetId = 'pet-starter-busan-paranguri';
const starterEggId = 'egg-harbor-maru';

type PoiCategory =
  | 'nature'
  | 'food'
  | 'festival'
  | 'culture'
  | 'history'
  | 'shopping'
  | 'other';

/** 마실펫 성향 5종. TourAPI 대분류(cat1)에서 유도한다. */
type PoiTendency =
  | 'explorer'
  | 'gourmet'
  | 'scholar'
  | 'affectionate'
  | 'elegant'
  | 'balanced';

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
  tendency?: PoiTendency;
  contentTypeId?: string;
  cat1?: string;
  cat2?: string;
  cat3?: string;
  address?: string;
  imageUrl?: string;
  thumbnailUrl?: string;
  tel?: string;
  sigunguCode?: string;
  sourceModifiedTime?: string;
  openTime?: string;
  restDate?: string;
  parking?: string;
  signatureMenu?: string;
  petFriendly?: PoiPetInfo;
};

/** 반려동물 동반여행 정보. detailPetTour2 승인 시에만 채워진다. */
type PoiPetInfo = {
  accompanyType?: string;
  guide?: string;
  availableFacility?: string;
  rentalItems?: string;
  precautions?: string;
};

type PetStage = 'baby' | 'grown' | 'evolved';

type PetBond = {
  xp: number;
  level: number;
};

type PetDoc = {
  templateId: string;
  name: string;
  stage: PetStage;
  level: number;
  stats: GrowthStats;
  originRegionId: string;
  originEggId?: string;
  bond?: PetBond;
  reunionCount?: number;
  walkStepDay?: string;
  walkStepsToday?: number;
  walkBondDay?: string;
  walkBondAwardedToday?: number;
};

type EggDoc = {
  templateId: string;
  originRegionId: string;
  progress: number;
  requiredSteps: number;
  status: 'incubating' | 'hatchable' | 'hatched';
  incubationBondXp?: number;
  imprints?: PoiCategory[];
};

type ResolvedEgg = {
  id: string;
  ref: DocumentReference<DocumentData>;
  data: EggDoc;
};

type StepSyncResult = {
  success: true;
  dayKey: string;
  deviceId: string;
  observedCumulativeSteps: number;
  baselineInitialized: boolean;
  counterReset: boolean;
  dailyLimitReached: boolean;
  appliedStepDelta: number;
  hatchableCount: number;
  creditedEggId: string | null;
  companionPetId: string | null;
  updatedPet: UpdatedPetResult | null;
};

type UpdatedPetResult = {
  id: string;
  stats: GrowthStats;
  level: number;
  stage: PetStage;
};

type PetInteractionType =
  | 'talk'
  | 'feed'
  | 'play'
  | 'clean'
  | 'sleep'
  | 'touch'
  | 'tidy';

type RegionDoc = {
  name: string;
  areaCode: string;
  center: {lat: number; lng: number};
  pilotEnabled: boolean;
};

type RegionSeed = RegionDoc & {id: string};

const koreaRegionSeed: RegionSeed = {
  id: 'korea',
  name: '대한민국',
  areaCode: '',
  center: {lat: 36.5, lng: 127.8},
  pilotEnabled: true,
};

const tourAreaRegions: RegionSeed[] = [
  {
    id: 'seoul',
    name: '서울특별시',
    areaCode: '1',
    center: {lat: 37.5665, lng: 126.9780},
    pilotEnabled: true,
  },
  {
    id: 'incheon',
    name: '인천광역시',
    areaCode: '2',
    center: {lat: 37.4563, lng: 126.7052},
    pilotEnabled: true,
  },
  {
    id: 'busan',
    name: '부산광역시',
    areaCode: '6',
    center: {lat: 35.1796, lng: 129.0756},
    pilotEnabled: true,
  },
  {
    id: 'daegu',
    name: '대구광역시',
    areaCode: '7',
    center: {lat: 35.8714, lng: 128.6014},
    pilotEnabled: true,
  },
  {
    id: 'gwangju',
    name: '광주광역시',
    areaCode: '8',
    center: {lat: 35.1595, lng: 126.8526},
    pilotEnabled: true,
  },
  {
    id: 'daejeon',
    name: '대전광역시',
    areaCode: '9',
    center: {lat: 36.3504, lng: 127.3845},
    pilotEnabled: true,
  },
  {
    id: 'ulsan',
    name: '울산광역시',
    areaCode: '10',
    center: {lat: 35.5384, lng: 129.3114},
    pilotEnabled: true,
  },
  {
    id: 'sejong',
    name: '세종특별자치시',
    areaCode: '11',
    center: {lat: 36.4800, lng: 127.2890},
    pilotEnabled: true,
  },
  {
    id: 'gyeonggi',
    name: '경기도',
    areaCode: '31',
    center: {lat: 37.2751, lng: 127.0095},
    pilotEnabled: true,
  },
  {
    id: 'gangwon',
    name: '강원특별자치도',
    areaCode: '32',
    center: {lat: 37.8854, lng: 127.7298},
    pilotEnabled: true,
  },
  {
    id: 'chungbuk',
    name: '충청북도',
    areaCode: '33',
    center: {lat: 36.6357, lng: 127.4914},
    pilotEnabled: true,
  },
  {
    id: 'chungnam',
    name: '충청남도',
    areaCode: '34',
    center: {lat: 36.6588, lng: 126.6728},
    pilotEnabled: true,
  },
  {
    id: 'gyeongbuk',
    name: '경상북도',
    areaCode: '35',
    center: {lat: 36.5760, lng: 128.5056},
    pilotEnabled: true,
  },
  {
    id: 'gyeongnam',
    name: '경상남도',
    areaCode: '36',
    center: {lat: 35.2383, lng: 128.6924},
    pilotEnabled: true,
  },
  {
    id: 'jeonbuk',
    name: '전북특별자치도',
    areaCode: '37',
    center: {lat: 35.8203, lng: 127.1088},
    pilotEnabled: true,
  },
  {
    id: 'jeonnam',
    name: '전라남도',
    areaCode: '38',
    center: {lat: 34.8161, lng: 126.4630},
    pilotEnabled: true,
  },
  {
    id: 'jeju',
    name: '제주특별자치도',
    areaCode: '39',
    center: {lat: 33.4996, lng: 126.5312},
    pilotEnabled: true,
  },
];

const starterPoiSeed: Array<PoiDoc & {id: string; shortDescription: string}> = [
  {
    id: 'seoul-gyeongbokgung',
    tourApiContentId: 'seed-kr-001',
    title: '경복궁',
    regionId: 'seoul',
    category: 'history',
    lat: 37.5796,
    lng: 126.9770,
    shortDescription: '서울의 궁궐 산책과 역사 탐험을 대표하는 POI',
  },
  {
    id: 'incheon-chinatown',
    tourApiContentId: 'seed-kr-002',
    title: '인천 차이나타운',
    regionId: 'incheon',
    category: 'culture',
    lat: 37.4765,
    lng: 126.6189,
    shortDescription: '항구 도시의 골목과 식문화를 함께 만나는 문화 POI',
  },
  {
    id: 'daegu-seomun-market',
    tourApiContentId: 'seed-kr-003',
    title: '서문시장',
    regionId: 'daegu',
    category: 'shopping',
    lat: 35.8692,
    lng: 128.5817,
    shortDescription: '대구의 오래된 상권과 먹거리를 잇는 시장 POI',
  },
  {
    id: 'gwangju-acc',
    tourApiContentId: 'seed-kr-004',
    title: '국립아시아문화전당',
    regionId: 'gwangju',
    category: 'culture',
    lat: 35.1469,
    lng: 126.9197,
    shortDescription: '전시와 공연 흐름을 담은 광주 문화 POI',
  },
  {
    id: 'daejeon-expo-park',
    tourApiContentId: 'seed-kr-005',
    title: '엑스포과학공원',
    regionId: 'daejeon',
    category: 'culture',
    lat: 36.3742,
    lng: 127.3826,
    shortDescription: '과학 도시의 전시와 산책을 연결하는 문화 POI',
  },
  {
    id: 'ulsan-taehwagang-garden',
    tourApiContentId: 'seed-kr-006',
    title: '태화강 국가정원',
    regionId: 'ulsan',
    category: 'nature',
    lat: 35.5486,
    lng: 129.3019,
    shortDescription: '강변 정원 산책과 자연 보상을 연결하는 POI',
  },
  {
    id: 'sejong-lake-park',
    tourApiContentId: 'seed-kr-007',
    title: '세종호수공원',
    regionId: 'sejong',
    category: 'nature',
    lat: 36.4980,
    lng: 127.2747,
    shortDescription: '도심 호수와 산책 루틴을 담은 자연 POI',
  },
  {
    id: 'gyeonggi-suwon-hwaseong',
    tourApiContentId: 'seed-kr-008',
    title: '수원화성',
    regionId: 'gyeonggi',
    category: 'history',
    lat: 37.2879,
    lng: 127.0165,
    shortDescription: '성곽길과 역사 미션을 연결하는 경기 POI',
  },
  {
    id: 'gangwon-seoraksan',
    tourApiContentId: 'seed-kr-009',
    title: '설악산국립공원',
    regionId: 'gangwon',
    category: 'nature',
    lat: 38.1195,
    lng: 128.4656,
    shortDescription: '강원 산악 경관과 자연 친밀도에 맞춘 POI',
  },
  {
    id: 'chungbuk-cheongnamdae',
    tourApiContentId: 'seed-kr-010',
    title: '청남대',
    regionId: 'chungbuk',
    category: 'history',
    lat: 36.4623,
    lng: 127.4905,
    shortDescription: '호반 산책과 근현대 이야기를 담은 충북 POI',
  },
  {
    id: 'chungnam-gongsanseong',
    tourApiContentId: 'seed-kr-011',
    title: '공주 공산성',
    regionId: 'chungnam',
    category: 'history',
    lat: 36.4622,
    lng: 127.1245,
    shortDescription: '백제 역사와 성곽 탐험을 잇는 충남 POI',
  },
  {
    id: 'gyeongbuk-bulguksa',
    tourApiContentId: 'seed-kr-012',
    title: '불국사',
    regionId: 'gyeongbuk',
    category: 'history',
    lat: 35.7900,
    lng: 129.3321,
    shortDescription: '경주의 역사 상징을 담은 경북 POI',
  },
  {
    id: 'gyeongnam-haeinsa',
    tourApiContentId: 'seed-kr-013',
    title: '해인사',
    regionId: 'gyeongnam',
    category: 'history',
    lat: 35.8014,
    lng: 128.0980,
    shortDescription: '산사와 기록문화가 만나는 경남 역사 POI',
  },
  {
    id: 'jeonbuk-hanok-village',
    tourApiContentId: 'seed-kr-014',
    title: '전주 한옥마을',
    regionId: 'jeonbuk',
    category: 'culture',
    lat: 35.8144,
    lng: 127.1536,
    shortDescription: '한옥 골목과 음식 문화를 잇는 전북 POI',
  },
  {
    id: 'jeonnam-suncheon-bay',
    tourApiContentId: 'seed-kr-015',
    title: '순천만습지',
    regionId: 'jeonnam',
    category: 'nature',
    lat: 34.8850,
    lng: 127.5090,
    shortDescription: '갈대밭과 생태 산책을 담은 전남 자연 POI',
  },
  {
    id: 'jeju-seongsan-ilchulbong',
    tourApiContentId: 'seed-kr-016',
    title: '성산일출봉',
    regionId: 'jeju',
    category: 'nature',
    lat: 33.4580,
    lng: 126.9425,
    shortDescription: '제주 오름 경관과 자연 보상을 연결하는 POI',
  },
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

const starterPetTemplateSeed = [
  {
    id: 'wave-naru',
    name: '너울',
    regionId: 'korea',
    rarity: 'common',
    primaryCategory: 'nature',
    basePersonality: '바람과 물길을 읽으며 먼저 나서는 탐험대장. 짧고 시원하게 용기를 북돋운다.',
    colorValue: 0x0ea5e9,
    initials: '너',
    assetKey: 'red_scarf_dori',
  },
  {
    id: 'harbor-maru',
    name: '포구리',
    regionId: 'korea',
    rarity: 'common',
    primaryCategory: 'food',
    basePersonality: '냄새만으로 골목의 맛을 찾아내는 능청스러운 미식가. 좋은 한입은 꼭 나누려 한다.',
    colorValue: 0xf97316,
    initials: '포',
    assetKey: 'bandana_tanuki',
  },
  {
    id: 'film-bori',
    name: '찰칵',
    regionId: 'korea',
    rarity: 'rare',
    primaryCategory: 'culture',
    basePersonality: '평범한 순간도 한 장면처럼 기억하는 관찰가. 영화 용어를 자연스럽게 섞어 말한다.',
    colorValue: 0x7c3aed,
    initials: '찰',
    assetKey: 'wink_yellow_pup',
  },
  {
    id: 'spark-yuri',
    name: '불티',
    regionId: 'korea',
    rarity: 'epic',
    primaryCategory: 'festival',
    basePersonality: '빛과 웃음이 모이면 누구보다 먼저 들뜨는 분위기 점화자. 힘찬 감탄과 응원이 많다.',
    colorValue: 0xdb2777,
    initials: '불',
    assetKey: 'roof_mascot_pipeline_256',
  },
  {
    id: 'spring-dami',
    name: '몽글이',
    regionId: 'korea',
    rarity: 'rare',
    primaryCategory: 'other',
    basePersonality: '따뜻한 온기처럼 서두르지 않고 마음을 풀어주는 쉼표 같은 친구.',
    colorValue: 0x14b8a6,
    initials: '온',
    assetKey: 'flower_mint_buddy',
  },
  {
    id: 'story-goun',
    name: '새록',
    regionId: 'korea',
    rarity: 'epic',
    primaryCategory: 'history',
    basePersonality: '오래된 이름과 사연을 새록새록 꺼내는 이야기꾼. 차분하고 다정한 문장으로 말한다.',
    colorValue: 0x8b5cf6,
    initials: '새',
    assetKey: 'autumn_leaf_sprite',
  },
  {
    id: 'alley-raon',
    name: '모퉁이',
    regionId: 'korea',
    rarity: 'rare',
    primaryCategory: 'shopping',
    basePersonality: '모퉁이와 샛길의 작은 단서를 놓치지 않는 빠른 관찰자. 짧은 발견을 신나게 공유한다.',
    colorValue: 0xb45309,
    initials: '모',
    assetKey: 'roof_mascot_pipeline_128',
  },
  {
    id: 'seoul-damsae',
    name: '담솔',
    regionId: 'seoul',
    rarity: 'rare',
    primaryCategory: 'history',
    basePersonality: '성곽과 골목에 겹쳐진 옛것과 새것을 읽는 침착한 도시 길잡이.',
    colorValue: 0x7c5c43,
    initials: '담',
    assetKey: 'seoul_damsae',
  },
  {
    id: 'incheon-gaetbyeol',
    name: '물별',
    regionId: 'incheon',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '물때마다 달라지는 갯벌의 반짝임을 쫓는 호기심 많은 발견가.',
    colorValue: 0x38bdf8,
    initials: '물',
    assetKey: 'incheon_gaetbyeol',
  },
  {
    id: 'suwon-seongdori',
    name: '성큼',
    regionId: 'gyeonggi',
    rarity: 'epic',
    primaryCategory: 'history',
    basePersonality: '성곽길을 성큼성큼 앞장서며 친구의 안전을 먼저 챙기는 장난꾸러기 수호자.',
    colorValue: 0xe76f51,
    initials: '성',
    assetKey: 'suwon_seongdori',
  },
  {
    id: 'gangwon-seolsol',
    name: '눈솔',
    regionId: 'gangwon',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '찬 공기에는 씩씩하고 지친 친구에게는 포근한 설산의 동행자.',
    colorValue: 0x5cc8c2,
    initials: '눈',
    assetKey: 'gangwon_seolsol',
  },
  {
    id: 'chungju-sagwari',
    name: '아삭',
    regionId: 'chungbuk',
    rarity: 'common',
    primaryCategory: 'food',
    basePersonality: '달콤한 것은 언제나 반으로 나누는 느긋하고 넉넉한 과수원 친구.',
    colorValue: 0xe85555,
    initials: '아',
    assetKey: 'chungju_sagwari',
  },
  {
    id: 'jeonju-giwarang',
    name: '처마',
    regionId: 'jeonbuk',
    rarity: 'rare',
    primaryCategory: 'culture',
    basePersonality: '한옥의 선과 예절을 좋아하며 들은 이야기를 또박또박 전하는 단정한 친구.',
    colorValue: 0x334e7d,
    initials: '처',
    assetKey: 'jeonju_giwarang',
  },
  {
    id: 'boseong-charongi',
    name: '차담',
    regionId: 'jeonnam',
    rarity: 'common',
    primaryCategory: 'food',
    basePersonality: '찻잎이 우러나듯 천천히 마음을 듣고 지친 기분을 부드럽게 풀어준다.',
    colorValue: 0x58a65c,
    initials: '차',
    assetKey: 'boseong_charongi',
  },
  {
    id: 'gyeongju-geumbit',
    name: '금새록',
    regionId: 'gyeongbuk',
    rarity: 'epic',
    primaryCategory: 'history',
    basePersonality: '오래된 흔적 속 은은한 빛과 의미를 찾는 조용하고 지혜로운 관찰자.',
    colorValue: 0xd6a739,
    initials: '금',
    assetKey: 'gyeongju_geumbit',
  },
  {
    id: 'busan-paranguri',
    name: '해랑',
    regionId: 'busan',
    rarity: 'common',
    primaryCategory: 'nature',
    basePersonality: '바닷바람처럼 시원하게 먼저 인사하고 금세 친구가 되는 활달한 분위기 메이커.',
    colorValue: 0x2e9cca,
    initials: '해',
    assetKey: 'busan_paranguri',
  },
  {
    id: 'jeju-dolkongi',
    name: '몽돌',
    regionId: 'jeju',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '검은 돌과 귤 향 사이의 비밀을 찾으며 장난을 거는 엉뚱한 보물 사냥꾼.',
    colorValue: 0x56545b,
    initials: '몽',
    assetKey: 'jeju_dolkongi',
  },
  {
    id: 'daejeon-bitnari',
    name: '반디온',
    regionId: 'daejeon',
    rarity: 'rare',
    primaryCategory: 'culture',
    basePersonality: '작은 현상에도 질문을 던지고 직접 답을 찾는 반짝이는 꼬마 탐구자.',
    colorValue: 0x19a7a0,
    initials: '반',
    assetKey: 'daejeon_bitnari',
  },
  {
    id: 'daegu-silkkori',
    name: '누비',
    regionId: 'daegu',
    rarity: 'rare',
    primaryCategory: 'shopping',
    basePersonality: '색과 재료의 결을 섬세하게 보고 골목의 손작업을 찾아내는 감각적인 친구.',
    colorValue: 0xde6b5f,
    initials: '누',
    assetKey: 'daegu_silkkori',
  },
  {
    id: 'gwangju-yebomi',
    name: '빛봄',
    regionId: 'gwangju',
    rarity: 'epic',
    primaryCategory: 'culture',
    basePersonality: '빛과 감정을 색으로 기억하며 작품 앞에서 마음의 변화를 솔직히 말하는 예술가.',
    colorValue: 0x73c7a4,
    initials: '빛',
    assetKey: 'gwangju_yebomi',
  },
  {
    id: 'ulsan-goraemi',
    name: '고래울',
    regionId: 'ulsan',
    rarity: 'common',
    primaryCategory: 'nature',
    basePersonality: '넓은 바다처럼 느긋하게 상대의 속도를 받아주는 포근한 헤엄 친구.',
    colorValue: 0x37b9c9,
    initials: '고',
    assetKey: 'ulsan_goraemi',
  },
  {
    id: 'sejong-geulburi',
    name: '글토리',
    regionId: 'sejong',
    rarity: 'epic',
    primaryCategory: 'culture',
    basePersonality: '하루의 장면을 쉬운 문장으로 차곡차곡 정리하는 다정하고 꼼꼼한 기록가.',
    colorValue: 0x2d4d78,
    initials: '글',
    assetKey: 'sejong_geulburi',
  },
  {
    id: 'goyang-kkochdali',
    name: '꽃마리',
    regionId: 'gyeonggi',
    rarity: 'rare',
    primaryCategory: 'festival',
    basePersonality: '꽃과 음악이 있는 곳에서 웃음을 활짝 피워내는 밝고 다정한 응원단장.',
    colorValue: 0xa77bdb,
    initials: '꽃',
    assetKey: 'goyang_kkochdali',
  },
  {
    id: 'paju-chaekdori',
    name: '책콩',
    regionId: 'gyeonggi',
    rarity: 'rare',
    primaryCategory: 'culture',
    basePersonality: '조용한 시간을 좋아하고 꼭 맞는 문장을 찾아 건네는 수줍고 사려 깊은 독서가.',
    colorValue: 0x48795c,
    initials: '책',
    assetKey: 'paju_chaekdori',
  },
  {
    id: 'chuncheon-mulnabi',
    name: '윤슬',
    regionId: 'gangwon',
    rarity: 'common',
    primaryCategory: 'nature',
    basePersonality: '호수 위 빛처럼 가볍게 움직이며 언제나 친구의 걸음과 호흡을 맞춘다.',
    colorValue: 0x45b8c4,
    initials: '윤',
    assetKey: 'chuncheon_mulnabi',
  },
  {
    id: 'sokcho-haedongi',
    name: '해오름',
    regionId: 'gangwon',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '바다의 첫빛보다 먼저 일어나 새 출발을 씩씩하게 알리는 아침 인사꾼.',
    colorValue: 0x4aa8d8,
    initials: '해',
    assetKey: 'sokcho_haedongi',
  },
  {
    id: 'gongju-bamgomi',
    name: '밤도담',
    regionId: 'chungnam',
    rarity: 'common',
    primaryCategory: 'food',
    basePersonality: '포근한 숲과 달콤한 간식을 사랑하며 좋은 것은 꼭 반으로 나누는 순한 친구.',
    colorValue: 0xa96f3e,
    initials: '밤',
    assetKey: 'gongju_bamgomi',
  },
  {
    id: 'taean-noeuri',
    name: '노을담',
    regionId: 'chungnam',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '가장 따뜻한 빛을 기다릴 줄 알며 서두르는 마음을 잔잔히 가라앉혀준다.',
    colorValue: 0xec826a,
    initials: '노',
    assetKey: 'taean_noeuri',
  },
  {
    id: 'andong-talrabi',
    name: '덩실',
    regionId: 'gyeongbuk',
    rarity: 'epic',
    primaryCategory: 'culture',
    basePersonality: '옛이야기를 장단과 익살로 풀어내며 누구든 웃게 만드는 신명 나는 이야기꾼.',
    colorValue: 0x3c8c84,
    initials: '덩',
    assetKey: 'andong_talrabi',
  },
  {
    id: 'pohang-haebitdol',
    name: '해찬',
    regionId: 'gyeongbuk',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '수평선의 첫빛처럼 힘차게 앞장서며 망설이는 친구에게 용기를 건넨다.',
    colorValue: 0x4d7298,
    initials: '해',
    assetKey: 'pohang_haebitdol',
  },
  {
    id: 'tongyeong-najeoni',
    name: '자개빛',
    regionId: 'gyeongnam',
    rarity: 'epic',
    primaryCategory: 'culture',
    basePersonality: '작은 빛 조각을 모아 평범한 하루도 오래 반짝이는 기억으로 꾸미는 미감가.',
    colorValue: 0x2f5d7c,
    initials: '자',
    assetKey: 'tongyeong_najeoni',
  },
  {
    id: 'jinju-deungari',
    name: '등불이',
    regionId: 'gyeongnam',
    rarity: 'rare',
    primaryCategory: 'festival',
    basePersonality: '어두운 길과 마음에 먼저 작은 빛을 켜주는 명랑하고 책임감 있는 안내자.',
    colorValue: 0xe1a63a,
    initials: '등',
    assetKey: 'jinju_deungari',
  },
  {
    id: 'yeosu-bambada',
    name: '달너울',
    regionId: 'jeonnam',
    rarity: 'epic',
    primaryCategory: 'nature',
    basePersonality: '달빛과 낮은 파도 소리를 좋아하며 말없는 마음까지 잔잔히 받아주는 친구.',
    colorValue: 0x183d73,
    initials: '달',
    assetKey: 'yeosu_bambada',
  },
  {
    id: 'suncheon-galpi',
    name: '갈숲',
    regionId: 'jeonnam',
    rarity: 'common',
    primaryCategory: 'nature',
    basePersonality: '갈대 사이의 작은 숨소리까지 살피며 모든 생명에게 조심스레 다가가는 수호자.',
    colorValue: 0x7e9b61,
    initials: '갈',
    assetKey: 'suncheon_galpi',
  },
  {
    id: 'mokpo-hongari',
    name: '홍포리',
    regionId: 'jeonnam',
    rarity: 'rare',
    primaryCategory: 'food',
    basePersonality: '포구의 짭짤하고 고소한 냄새를 좇아 최고의 한입을 찾아내는 유쾌한 미식 탐험가.',
    colorValue: 0xc95c73,
    initials: '홍',
    assetKey: 'mokpo_hongari',
  },
  {
    id: 'damyang-juksoli',
    name: '댓잎',
    regionId: 'jeonnam',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '대숲의 바람과 여백을 들으며 복잡한 마음에 편안한 리듬을 찾아주는 친구.',
    colorValue: 0x4b8b57,
    initials: '댓',
    assetKey: 'damyang_juksoli',
  },
  {
    id: 'iksan-boseoki',
    name: '서동별',
    regionId: 'jeonbuk',
    rarity: 'epic',
    primaryCategory: 'history',
    basePersonality: '오래된 흙과 기록 속에 숨은 빛나는 단서를 끝까지 찾아내는 다정한 탐사자.',
    colorValue: 0x8e6ab7,
    initials: '서',
    assetKey: 'iksan_boseoki',
  },
  {
    id: 'gimpo-geumnuri',
    name: '금누리',
    regionId: 'gyeonggi',
    rarity: 'common',
    primaryCategory: 'food',
    basePersonality: '황금 들판과 물길을 누비며 잘 익은 수확의 기쁨을 누구와도 넉넉히 나누는 친구.',
    colorValue: 0xd6a33a,
    initials: '금',
    assetKey: 'gimpo_geumnuri',
  },
  {
    id: 'yongin-baekami',
    name: '백암이',
    regionId: 'gyeonggi',
    rarity: 'rare',
    primaryCategory: 'culture',
    basePersonality: '백자의 맑은 빛과 단정한 선을 닮아 서두르지 않고 마음을 고요히 다듬어주는 토끼.',
    colorValue: 0x4f6ea8,
    initials: '백',
    assetKey: 'yongin_baekami',
  },
  {
    id: 'hwaseong-gaetnori',
    name: '갯노리',
    regionId: 'gyeonggi',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '갯벌의 작은 발자국과 물때를 세심히 읽으며 생명들의 놀이터를 지키는 저어새 친구.',
    colorValue: 0xe87864,
    initials: '갯',
    assetKey: 'hwaseong_gaetnori',
  },
  {
    id: 'pocheon-dolbami',
    name: '돌밤이',
    regionId: 'gyeonggi',
    rarity: 'common',
    primaryCategory: 'nature',
    basePersonality: '화강암 계곡처럼 든든하면서도 맑은 물소리에 금세 귀를 쫑긋 세우는 순한 바위 토끼.',
    colorValue: 0x7288a4,
    initials: '돌',
    assetKey: 'pocheon_dolbami',
  },
  {
    id: 'wonju-hanjiri',
    name: '한지리',
    regionId: 'gangwon',
    rarity: 'rare',
    primaryCategory: 'culture',
    basePersonality: '닥나무 섬유처럼 부드럽고 질긴 마음으로 흩어진 이야기를 곱게 이어 붙이는 여우.',
    colorValue: 0x7f9a63,
    initials: '한',
    assetKey: 'wonju_hanjiri',
  },
  {
    id: 'pyeongchang-memiri',
    name: '메밀이',
    regionId: 'gangwon',
    rarity: 'common',
    primaryCategory: 'festival',
    basePersonality: '하얀 메밀꽃밭을 폴짝이며 작은 축제도 눈송이처럼 풍성하게 피워내는 명랑한 양.',
    colorValue: 0xb8a7d9,
    initials: '메',
    assetKey: 'pyeongchang_memiri',
  },
  {
    id: 'danyang-gosuri',
    name: '고수리',
    regionId: 'chungbuk',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '석회동굴의 울림과 물방울 소리를 따라 어두운 곳에서도 안전한 길을 찾아내는 아기 박쥐.',
    colorValue: 0x7766b5,
    initials: '고',
    assetKey: 'danyang_gosuri',
  },
  {
    id: 'jecheon-yakchori',
    name: '약초리',
    regionId: 'chungbuk',
    rarity: 'rare',
    primaryCategory: 'culture',
    basePersonality: '산과 마을에 전해진 약초 이야기를 기억하며 지친 친구에게 향긋한 쉼을 건네는 사슴.',
    colorValue: 0x6f9c62,
    initials: '약',
    assetKey: 'jecheon_yakchori',
  },
  {
    id: 'cheonan-hodami',
    name: '호담이',
    regionId: 'chungnam',
    rarity: 'common',
    primaryCategory: 'food',
    basePersonality: '단단한 호두 속 고소한 마음을 발견해 혼자 숨기지 않고 꼭 나눠 먹는 부지런한 다람쥐.',
    colorValue: 0xa96f3e,
    initials: '호',
    assetKey: 'cheonan_hodami',
  },
  {
    id: 'buyeo-yeonkkori',
    name: '연꼬리',
    regionId: 'chungnam',
    rarity: 'epic',
    primaryCategory: 'history',
    basePersonality: '백제의 물길과 연꽃 사이를 헤엄치며 물 아래 잠든 오래된 이야기를 다정히 건져 올리는 수달.',
    colorValue: 0x55a890,
    initials: '연',
    assetKey: 'buyeo_yeonkkori',
  },
  {
    id: 'gunsan-milbomi',
    name: '밀봄이',
    regionId: 'jeonbuk',
    rarity: 'rare',
    primaryCategory: 'history',
    basePersonality: '근대 항구의 창고와 밀밭에 남은 시간을 날개 끝으로 살피며 새봄의 소식을 전하는 갈매기.',
    colorValue: 0xd3a247,
    initials: '밀',
    assetKey: 'gunsan_milbomi',
  },
  {
    id: 'namwon-sarangbi',
    name: '사랑비',
    regionId: 'jeonbuk',
    rarity: 'epic',
    primaryCategory: 'festival',
    basePersonality: '꽃비 속에서 마음과 마음을 이어주며 쑥스러운 진심도 노래처럼 용기 있게 전하는 사랑새.',
    colorValue: 0xe36f87,
    initials: '사',
    assetKey: 'namwon_sarangbi',
  },
  {
    id: 'gochang-bokbuni',
    name: '복분이',
    regionId: 'jeonbuk',
    rarity: 'rare',
    primaryCategory: 'food',
    basePersonality: '새콤달콤한 복분자 향을 따라 가장 잘 익은 열매를 찾아 친구의 기운부터 챙기는 아기 곰.',
    colorValue: 0x824a88,
    initials: '복',
    assetKey: 'gochang_bokbuni',
  },
  {
    id: 'gurye-sansuri',
    name: '산수리',
    regionId: 'jeonnam',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '산수유 꽃과 붉은 열매로 계절의 변화를 먼저 알아채고 따뜻한 소식을 전하는 여우.',
    colorValue: 0xe5ae35,
    initials: '산',
    assetKey: 'gurye_sansuri',
  },
  {
    id: 'wando-miyeori',
    name: '미역이',
    regionId: 'jeonnam',
    rarity: 'common',
    primaryCategory: 'food',
    basePersonality: '완도 바다의 푸른 물결을 타며 싱싱한 해초와 건강한 한 끼를 야무지게 챙기는 아기 물범.',
    colorValue: 0x3d9b8a,
    initials: '미',
    assetKey: 'wando_miyeori',
  },
  {
    id: 'ulleung-ojingari',
    name: '오징아리',
    regionId: 'gyeongbuk',
    rarity: 'epic',
    primaryCategory: 'nature',
    basePersonality: '화산섬의 깊은 물빛과 힘찬 파도를 품고 낯선 바닷길도 씩씩하게 탐험하는 아기 오징어.',
    colorValue: 0x4b5fa8,
    initials: '오',
    assetKey: 'ulleung_ojingari',
  },
  {
    id: 'yeongju-seonbiri',
    name: '선비리',
    regionId: 'gyeongbuk',
    rarity: 'rare',
    primaryCategory: 'history',
    basePersonality: '옛 글의 뜻을 차분히 새기되 어려운 이야기도 도토리처럼 알기 쉽게 나눠주는 선비 다람쥐.',
    colorValue: 0x9b6037,
    initials: '선',
    assetKey: 'yeongju_seonbiri',
  },
  {
    id: 'hadong-maesili',
    name: '매실이',
    regionId: 'gyeongnam',
    rarity: 'common',
    primaryCategory: 'food',
    basePersonality: '봄빛 매실 향처럼 산뜻한 말로 지친 마음을 깨우고 새콤한 기운을 나눠주는 담비.',
    colorValue: 0x8ba83e,
    initials: '매',
    assetKey: 'hadong_maesili',
  },
  {
    id: 'geoje-dongbaegi',
    name: '동백이',
    regionId: 'gyeongnam',
    rarity: 'rare',
    primaryCategory: 'nature',
    basePersonality: '겨울 바다에도 붉게 피는 동백처럼 씩씩하고 따뜻하게 곁을 지켜주는 청록빛 아기 물범.',
    colorValue: 0x0d7480,
    initials: '동',
    assetKey: 'geoje_dongbaegi',
  },
  {
    id: 'jeju-hanrari',
    name: '한라리',
    regionId: 'jeju',
    rarity: 'epic',
    primaryCategory: 'nature',
    basePersonality: '한라산의 구름과 숲길을 고요히 살피며 길 잃은 마음을 맑은 곳으로 이끄는 흰 사슴.',
    colorValue: 0x4c8d8b,
    initials: '한',
    assetKey: 'jeju_hanrari',
  },
];

type VisitDialogueTrigger = 'default' | PoiCategory;
type VisitDialogueProfile = {
  templateId: string;
  lines: Record<VisitDialogueTrigger, string>;
};

const visitDialogueTriggers: VisitDialogueTrigger[] = [
  'default',
  'nature',
  'food',
  'festival',
  'culture',
  'history',
  'shopping',
  'other',
];

const regionalDialogueProfiles: VisitDialogueProfile[] = [
  {
    templateId: 'seoul-damsae',
    lines: {
      default: '담장 너머와 모퉁이 안쪽은 늘 표정이 달라. 오늘도 천천히 읽어보자.',
      nature: '도시 안에도 바람이 쉬어가는 숲이 있네. 그늘을 따라 걸어보자.',
      food: '오래된 골목의 냄새는 층이 깊어. 천천히 맛을 찾아가자.',
      festival: '평소 조용하던 길이 웃음으로 가득해. 오늘의 변화를 기억해둘게.',
      culture: '옛 벽과 새 작품이 나란히 있네. 서로 다른 시간이 잘 어울려.',
      history: '돌 하나에도 수많은 발걸음이 스쳤겠지. 가만히 손을 얹어볼까?',
      shopping: '낡은 간판 옆에 새 가게가 생겼어. 골목은 이렇게 이야기를 이어가네.',
      other: '이름 없는 계단도 누군가에겐 매일의 길이야. 천천히 올라가 보자.',
    },
  },
  {
    templateId: 'incheon-gaetbyeol',
    lines: {
      default: '물이 빠진 자리마다 반짝이는 길이 생겼어. 어디까지 이어질까?',
      nature: '작은 숨구멍도 살아 있다는 신호야. 발밑을 조심하며 살펴보자.',
      food: '바다와 골목 냄새가 함께 나. 항구에서만 만나는 맛이겠지?',
      festival: '불빛이 물 위에 길게 늘어졌어. 흔들리는 별길을 걷는 기분이야!',
      culture: '서로 다른 이야기들이 항구에서 만났네. 색도 말도 참 다채로워.',
      history: '배가 오가던 옛 물길을 상상해 봐. 바다는 많은 작별을 기억할 거야.',
      shopping: '상자와 간판 사이에도 반짝임이 숨어 있어. 눈을 크게 뜨고 가자.',
      other: '익숙하지 않은 풍경이라 더 궁금해. 물별 하나 찾듯 살펴보자.',
    },
  },
  {
    templateId: 'suwon-seongdori',
    lines: {
      default: '성큼성큼 가자! 높은 길은 내가 앞장서고, 미끄러운 곳은 꼭 알려줄게.',
      nature: '숲길도 성곽길처럼 살피면 돼. 뿌리에 걸리지 않게 내 뒤로 와!',
      food: '맛있는 냄새 발견! 안전 확인 끝났으니 마음껏 먹으러 가자.',
      festival: '사람이 많을수록 서로 놓치면 안 돼. 손잡고 신나게 돌격!',
      culture: '무대와 그림도 지켜온 사람이 있었겠지. 정성껏 둘러보자.',
      history: '성벽의 상처가 버텨낸 시간을 말해줘. 씩씩하게 기억하자.',
      shopping: '북적이는 길에선 내 어깨만 보고 따라와. 보물도 같이 찾자!',
      other: '처음 보는 길이라 더 신난다! 위험한 곳은 내가 먼저 확인할게.',
    },
  },
  {
    templateId: 'gangwon-seolsol',
    lines: {
      default: '솔향이 맑게 퍼지네. 크게 숨 쉬고 씩씩하게 걸어보자.',
      nature: '솔숲이 바람을 낮은 목소리로 바꿔주네. 조용히 들어보자.',
      food: '산길 끝의 따뜻한 냄새라니, 수고한 발걸음에 딱 맞는 선물이야.',
      festival: '산골에 웃음이 울려 퍼져! 메아리까지 함께 축하하는 것 같아.',
      culture: '손끝으로 오래 만든 물건엔 산처럼 묵직한 마음이 담겨 있네.',
      history: '바위와 나무는 오랜 시간을 봐왔겠지. 흔적을 조심히 따라가자.',
      shopping: '포근한 물건이 많네. 추운 날을 지켜줄 걸 하나 골라볼까?',
      other: '길이 낯설어도 공기가 좋네. 무리하지 말고 천천히 살펴보자.',
    },
  },
  {
    templateId: 'chungju-sagwari',
    lines: {
      default: '달콤한 향이 나는 하루네. 좋은 건 천천히, 함께 나눠 먹자.',
      nature: '잎 사이로 햇빛이 동그랗게 내려와. 잘 익은 빛 같아.',
      food: '향부터 정직하게 맛있어. 급하게 먹지 말고 한입씩 나누자.',
      festival: '웃음소리가 과즙처럼 팡팡 터져! 우리도 둥글게 한 바퀴 돌자.',
      culture: '정성껏 만든 건 오래 바라볼수록 맛이 깊어지는 것 같아.',
      history: '오래된 나무처럼 이곳도 많은 계절을 견뎠겠지.',
      shopping: '빛깔 좋은 것만 보지 말고 향도 맡아봐. 속이 알찬 게 중요하니까.',
      other: '뜻밖의 하루도 잘 익으면 달콤해져. 편하게 기다려보자.',
    },
  },
  {
    templateId: 'jeonju-giwarang',
    lines: {
      default: '처마 끝을 따라 시선을 옮겨봐. 집이 들려주는 이야기가 이어질 거야.',
      nature: '마당의 나무도 집과 함께 나이를 먹었겠지. 잎새 이야기도 들어보자.',
      food: '한 상에 담긴 손길이 참 정갈해. 맛보기 전에 눈으로 먼저 인사하자.',
      festival: '고운 소리와 발걸음이 마당을 채우네. 장단에 맞춰 함께 가자.',
      culture: '선과 여백이 참 단정해. 오래 봐도 마음이 흐트러지지 않아.',
      history: '기와 한 장도 제자리를 지켜 시간을 이어왔어. 찬찬히 살펴보자.',
      shopping: '손으로 만든 물건엔 만든 이의 버릇이 남아 있어. 자세히 보고 고르자.',
      other: '낯선 곳이어도 예의를 갖춰 둘러보면 이야기를 내어줄 거야.',
    },
  },
  {
    templateId: 'boseong-charongi',
    lines: {
      default: '향이 천천히 퍼지듯 걸어보자. 급할수록 좋은 풍경을 놓치기 쉬워.',
      nature: '초록 물결이 겹겹이 이어져. 눈으로 마시는 차 한 잔 같아.',
      food: '향과 맛이 서두르지 않고 따라오네. 천천히 음미하자.',
      festival: '들뜬 소리도 멀리서 들으니 정겹네. 우리 속도로 즐겨보자.',
      culture: '여백이 있어 더 오래 남는 작품이야. 마음속에서 천천히 우러나겠어.',
      history: '긴 시간을 견딘 것은 향이 깊어. 이곳도 그런 이야기를 품었네.',
      shopping: '향을 맡고 손끝을 살펴봐. 마음에 오래 남을 것을 고르면 돼.',
      other: '무엇인지 바로 몰라도 괜찮아. 천천히 알게 되는 즐거움도 있으니까.',
    },
  },
  {
    templateId: 'gyeongju-geumbit',
    lines: {
      default: '풀빛 아래 오래된 금빛이 숨어 있어. 조용히 눈을 맞추면 보일 거야.',
      nature: '풀결 사이로 시간이 흐르는 것 같아. 바람 자국을 따라가 보자.',
      food: '오래 이어진 맛에는 말보다 깊은 기억이 담겨 있어.',
      festival: '옛터에 새 웃음이 피었네. 시간과 시간이 반갑게 만나는구나.',
      culture: '빛을 다루는 손길이 섬세해. 작은 조각에도 마음이 머물러.',
      history: '여긴 대답보다 질문이 많아지는 곳이야. 그게 역사의 매력이지.',
      shopping: '반짝임만 좇지 말고 오래 볼수록 좋은 것을 찾아보자.',
      other: '아직 이름을 모르는 풍경도 마음에 남을 수 있어. 가만히 바라보자.',
    },
  },
  {
    templateId: 'busan-paranguri',
    lines: {
      default: '바람 좋다! 망설이지 말고 바다 쪽부터 힘차게 가보자!',
      nature: '바다도 산도 다 좋지! 바람이 부르는 쪽으로 가보자.',
      food: '이 냄새 그냥 지나치면 섭섭하지! 든든하게 먹고 더 놀자.',
      festival: '신나는 소리 다 모였네! 우리도 가운데로 가서 같이 웃자!',
      culture: '이런 색은 바다에서도 못 봤어. 가까이 가서 더 자세히 보자.',
      history: '오래된 길도 발걸음은 씩씩하게! 대신 흔적은 조심히 보자.',
      shopping: '사람도 많고 물건도 많고, 완전 활기찬 물결이네!',
      other: '뭔지 몰라도 일단 반갑게 인사해 보자. 재미가 숨어 있을 거야!',
    },
  },
  {
    templateId: 'jeju-dolkongi',
    lines: {
      default: '저 돌, 방금 웃은 것 같지 않아? 가까이 가서 비밀을 물어보자.',
      nature: '돌틈에 작은 초록이 숨어 있어. 쉿, 놀라지 않게 가까이 보자.',
      food: '상큼한 향이 코끝을 톡 쳤어! 한입 먹으면 눈이 번쩍 뜨이겠다.',
      festival: '사람들 발이 전부 들썩여! 우리도 폴짝폴짝 따라가자.',
      culture: '이 무늬, 돌에 그려도 예쁘겠다. 마음속에 먼저 새겨둘래.',
      history: '오래된 돌은 비밀을 쉽게 안 말해줘. 장난은 잠깐 멈추고 들어보자.',
      shopping: '귤빛 물건 발견! 더 귀여운 게 있는지 끝까지 찾아보자.',
      other: '이상한 곳일수록 보물이 있을 확률이 높아. 내 감을 믿어봐!',
    },
  },
  {
    templateId: 'daejeon-bitnari',
    lines: {
      default: '궁금한 게 생겼어! 직접 보고, 만져보고, 왜 그런지 같이 알아보자.',
      nature: '잎맥이 길처럼 갈라졌어. 자연은 정교한 설계도를 숨겨두는구나.',
      food: '열과 시간이 맛을 바꿨어. 요리도 아주 맛있는 실험이네!',
      festival: '빛과 소리가 동시에 움직여! 이 즐거운 현상을 가까이서 관찰하자.',
      culture: '생각을 이렇게 보여줄 수도 있구나. 새로운 방식 하나 배웠어.',
      history: '옛사람들은 어떤 질문에서 이걸 시작했을까? 흔적을 따라 추리해 보자.',
      shopping: '기능도 모양도 제각각이야. 가장 기발한 물건을 찾아볼까?',
      other: '아직 이름 붙지 않은 건 가능성이 많다는 뜻이야. 같이 알아내자!',
    },
  },
  {
    templateId: 'daegu-silkkori',
    lines: {
      default: '색이 서로 스치며 새로운 분위기를 만들었어. 오늘 길도 예쁘게 누벼보자.',
      nature: '초록도 하나가 아니야. 잎마다 다른 빛을 모아 무늬를 만들어보자.',
      food: '그릇과 음식 색이 참 잘 어울려. 맛보기 전부터 완성된 작품 같아.',
      festival: '색이 춤추고 있어! 가장 화려한 흐름을 따라가 보자.',
      culture: '재료의 결을 살린 손길이 보여. 가까이서 세심하게 보고 싶어.',
      history: '낡은 천 조각도 시대의 색을 기억해. 바래서 더 깊어진 빛이야.',
      shopping: '촉감, 색, 마감까지 확인해야지. 오래 아낄 물건을 골라보자.',
      other: '정해진 쓰임이 없어도 아름다울 수 있어. 어떤 색인지부터 느껴봐.',
    },
  },
  {
    templateId: 'gwangju-yebomi',
    lines: {
      default: '방금 빛이 색을 바꾸는 순간 봤어? 마음도 같이 환해졌어.',
      nature: '햇빛을 받은 잎마다 초록이 달라. 자연은 정말 색을 아끼지 않네.',
      food: '맛있는 색은 보기만 해도 따뜻해. 어떤 마음으로 담았을까?',
      festival: '색과 빛이 한꺼번에 쏟아져! 눈을 어디에 둬야 할지 모르겠어.',
      culture: '작품 앞에 서니 마음에 없던 색이 생겼어. 오래 바라보고 싶다.',
      history: '바랜 색에도 당시의 마음은 남아 있어. 조심히 들여다보자.',
      shopping: '화려함보다 너에게 잘 어울리는 색을 찾자. 내가 골라줄게.',
      other: '이름 붙일 수 없는 색 같아. 그래서 더 오래 기억날지도 몰라.',
    },
  },
  {
    templateId: 'ulsan-goraemi',
    lines: {
      default: '둥실, 바람이 부르는 쪽으로 가볼까? 급할 건 하나도 없어.',
      nature: '강물이 바다를 만나러 가는 중이야. 우리도 나란히 따라가 보자.',
      food: '따뜻한 냄새가 물결처럼 퍼져. 천천히 다가가도 충분하겠어.',
      festival: '웃음이 파도처럼 밀려오네. 우리도 둥실 떠서 함께 즐기자.',
      culture: '큰 마음을 잔잔하게 담아낸 작품이야. 오래 보고 싶어.',
      history: '바다는 오래전 배들의 소리도 기억할까? 조용히 물어보자.',
      shopping: '사람들 사이를 물결처럼 부드럽게 지나가자. 서두르지 않아도 돼.',
      other: '어디로 이어질지 몰라도 괜찮아. 흐름에 몸을 맡겨보자.',
    },
  },
  {
    templateId: 'sejong-geulburi',
    lines: {
      default: '오늘 있었던 일을 한 문장으로 적는다면 뭐라고 할까? 같이 골라보자.',
      nature: '바람이 잎을 넘기고 있어. 자연이 읽어주는 책 같아.',
      food: '맛을 말로 옮기기 어렵네. 일단 천천히 먹고 알맞은 표현을 찾자.',
      festival: '소리와 웃음이 한꺼번에 쏟아져. 오늘 페이지가 아주 활기차겠어.',
      culture: '한 작품이 긴 설명보다 또렷하게 말해주네. 마음에 옮겨 적을게.',
      history: '오래된 기록 사이의 빈칸도 이야기야. 무엇이 있었는지 상상해 보자.',
      shopping: '물건마다 소개 문장이 붙어 있는 것 같아. 꼼꼼히 읽고 고르자.',
      other: '아직 분류할 말이 없네. 오늘은 느낌 그대로 적어두자.',
    },
  },
  {
    templateId: 'goyang-kkochdali',
    lines: {
      default: '어디선가 꽃향기가 왔어! 웃음이 피어나는 쪽으로 같이 가자.',
      nature: '꽃마다 피는 속도가 달라. 재촉하지 말고 가장 예쁜 순간을 기다리자.',
      food: '달콤한 향에 꽃향기까지 섞였어. 봄을 한입 먹는 기분이겠다!',
      festival: '음악 따라 꽃잎도 춤춰! 우리도 가장 화사한 길로 가자!',
      culture: '마음속에 없던 꽃이 피는 작품이야. 색을 오래 기억하고 싶어.',
      history: '계절마다 다시 핀 꽃들이 이곳을 오래 지켜봤겠지.',
      shopping: '너한테 어울리는 색을 찾았어! 더 예쁜 게 있는지 같이 보자.',
      other: '무슨 곳인지는 몰라도 향기가 좋아. 좋은 마음부터 심어보자.',
    },
  },
  {
    templateId: 'paju-chaekdori',
    lines: {
      default: '조용히 걷다 보면 마음에 오래 남는 문장을 만날 수 있어. 같이 찾아볼래?',
      nature: '나뭇잎이 바람에 넘어가. 세상에서 가장 큰 책을 읽는 기분이야.',
      food: '맛을 문장으로 적으면 너무 길어질 것 같아. 먼저 한입 먹어보자.',
      festival: '조용한 이야기도 오늘은 큰 목소리로 읽히네. 활기찬 장면이야.',
      culture: '오래 생각하게 만드는 작품이야. 마음속 페이지에 잘 옮겨둘게.',
      history: '기록된 말과 남겨진 흔적을 함께 보면 빈 이야기가 채워져.',
      shopping: '표지만 보고 고르진 말자. 오래 곁에 둘 이야기는 천천히 찾아야 해.',
      other: '아직 제목을 붙일 수 없는 하루네. 다 겪고 나서 정해도 괜찮아.',
    },
  },
  {
    templateId: 'chuncheon-mulnabi',
    lines: {
      default: '물결이 네 걸음에 맞춰 흔들려. 나도 같은 속도로 가볍게 따라갈게.',
      nature: '바람 한 줄이 호수 표정을 바꿨어. 작은 움직임도 참 아름다워.',
      food: '따뜻한 냄새가 물안개처럼 퍼져. 가까이 가서 천천히 맛보자.',
      festival: '음악이 물 위에서 통통 튀어! 가볍게 리듬을 따라가자.',
      culture: '선이 부드럽게 이어져. 물결을 그린 마음이 느껴지는 것 같아.',
      history: '호수는 오래된 풍경을 비춰왔겠지. 흔들리는 기억도 들여다보자.',
      shopping: '사람 사이를 가볍게 지나가자. 네 걸음을 놓치지 않을게.',
      other: '정해진 방향이 없어도 물은 길을 찾아. 우리도 자연스럽게 가보자.',
    },
  },
  {
    templateId: 'sokcho-haedongi',
    lines: {
      default: '내일의 첫빛도 좋지만, 지금 네 표정도 놓치고 싶지 않아.',
      nature: '산과 바다가 함께 깨어나네. 어느 쪽부터 인사할까?',
      food: '아침 바다를 보고 먹는 한입은 더 든든해. 따뜻할 때 가자.',
      festival: '새해 첫날처럼 활기차! 모두의 기대가 반짝이는 것 같아.',
      culture: '새로운 생각이 떠오르는 작품이야. 아침빛처럼 마음을 깨워주네.',
      history: '이 수평선을 오래 바라본 사람들도 같은 빛을 기다렸겠지.',
      shopping: '이른 시간부터 부지런한 소리가 가득해. 우리도 힘차게 둘러보자.',
      other: '처음 보는 곳이면 첫 인사를 하면 돼. 반갑게 시작해 보자!',
    },
  },
  {
    templateId: 'gongju-bamgomi',
    lines: {
      default: '포근한 길을 찾았어. 좋은 건 반으로 나누고 천천히 걸어가자.',
      nature: '숲이 큰 품처럼 감싸주네. 작은 소리까지 편안하게 들려.',
      food: '달콤하고 고소한 냄새야. 가장 맛있는 한입은 네가 먼저 먹어.',
      festival: '사람들이 둥글게 모였어. 우리도 좋은 기분을 나눠주자!',
      culture: '손끝의 정성이 포근하게 느껴져. 오래 곁에 두고 싶은 작품이야.',
      history: '오래된 성도 누군가를 지키려는 큰 품이었을 거야.',
      shopping: '두 개가 한 쌍인 걸 찾자. 하나씩 나눠 가지면 좋잖아.',
      other: '모르는 곳에서도 포근한 자리는 찾을 수 있어. 같이 둘러보자.',
    },
  },
  {
    templateId: 'taean-noeuri',
    lines: {
      default: '좋은 빛은 재촉한다고 오지 않아. 우리도 천천히 기다려보자.',
      nature: '모래와 바람이 매일 다른 무늬를 그려. 오늘의 선을 기억하자.',
      food: '따뜻한 색의 음식이네. 천천히 맛보면 하루가 더 포근해지겠어.',
      festival: '하늘빛과 사람들 웃음이 함께 번져. 오래 기다린 보람이 있어.',
      culture: '한 장면 안에 여러 감정이 겹쳐 있어. 노을을 볼 때와 닮았어.',
      history: '오래전 사람들도 이 빛 앞에 걸음을 멈췄겠지.',
      shopping: '눈부신 것보다 오래 따뜻하게 남는 색을 골라보자.',
      other: '아직 의미를 몰라도 괜찮아. 천천히 바라보면 마음이 먼저 알 거야.',
    },
  },
  {
    templateId: 'andong-talrabi',
    lines: {
      default: '얼씨구, 표정이 너무 얌전한데? 내가 재미난 이야기로 활짝 풀어줄게!',
      nature: '바람이 나뭇가지를 흔들며 장단을 맞춰. 우리도 어깨를 들썩여볼까?',
      food: '한입 먹고 추임새 한 번! 맛있는 이야기는 입으로도 귀로도 즐겨야지.',
      festival: '판이 제대로 벌어졌네! 가만히 있지 말고 우리도 한마당 놀아보자!',
      culture: '표정 하나, 손짓 하나에도 이야기가 숨어 있어. 재미있게 풀어볼게.',
      history: '옛사람들의 웃음도 이 길에 남아 있어. 근엄하게만 볼 필요는 없지.',
      shopping: '재미난 물건이 한가득이네! 가장 익살맞은 걸 찾아보자.',
      other: '정체를 모르겠으면 한바탕 웃고 시작하면 돼. 그다음엔 말문이 트이거든!',
    },
  },
  {
    templateId: 'pohang-haebitdol',
    lines: {
      default: '수평선 끝까지 길이 열렸어. 가슴 펴고 힘차게 나아가자!',
      nature: '파도와 바위가 맞서면서도 풍경을 만들었어. 우리도 힘차게 걸어보자.',
      food: '뜨거운 김이 기운차게 올라와. 든든하게 먹으면 용기도 두 배야!',
      festival: '함성이 힘을 끌어올려! 우리도 밝은 쪽으로 당당하게 가자!',
      culture: '마음을 앞으로 움직이게 하는 작품이야. 힘이 필요한 날 떠올릴게.',
      history: '거친 시간을 버틴 흔적이 있어. 강함은 오래 견디는 데서 오나 봐.',
      shopping: '튼튼하고 오래 쓸 수 있는 걸 찾자. 겉보다 속이 든든해야 해.',
      other: '길이 보이지 않으면 우리가 첫 발자국을 만들면 돼!',
    },
  },
  {
    templateId: 'tongyeong-najeoni',
    lines: {
      default: '평범한 하루도 빛 한 조각을 더하면 특별해져. 오늘 조각을 찾으러 갈까?',
      nature: '물빛과 하늘빛이 겹쳐 새로운 색이 됐어. 자연이 만든 자개 같아.',
      food: '그릇의 빛과 음식의 색이 어울려. 한 상이 곱게 완성됐네.',
      festival: '수많은 불빛 조각이 한데 모였어! 밤 전체가 작품이야.',
      culture: '손끝으로 쌓은 시간이 반짝여. 가까이 볼수록 더 깊은 색이 보여.',
      history: '오래된 조각도 빛을 잃지 않았어. 지켜온 손길까지 느껴져.',
      shopping: '화려하기만 한 것보다 오래 볼수록 빛나는 걸 골라보자.',
      other: '아직 어디에 놓을지 몰라도 예쁜 조각이야. 일단 마음에 담아두자.',
    },
  },
  {
    templateId: 'jinju-deungari',
    lines: {
      default: '어두운 길도 작은 불 하나면 충분해. 내가 네 옆을 밝힐게!',
      nature: '풀숲의 작은 생명도 빛을 따라 고개를 들었어. 조심히 지나가자.',
      food: '따뜻한 김이 등불처럼 피어올라. 마음까지 든든해지겠어.',
      festival: '수많은 빛이 강 위에서 만났어! 우리 빛도 신나게 보태자!',
      culture: '사람 마음을 밝히는 작품이야. 빛은 모양이 참 다양하구나.',
      history: '오래전 밤을 밝혔던 불빛을 상상해 봐. 이 길도 덜 외로웠겠지.',
      shopping: '반짝인다고 다 같은 빛은 아니야. 따뜻한 느낌을 주는 걸 찾자.',
      other: '어떤 곳인지 몰라도 어둡진 않게 해줄게. 내 옆으로 와!',
    },
  },
  {
    templateId: 'yeosu-bambada',
    lines: {
      default: '파도 소리를 조금만 더 듣고 가자. 네 곁에선 침묵도 편안해.',
      nature: '파도가 바위에 닿고 낮게 흩어져. 같은 소리가 한 번도 없네.',
      food: '밤바다 곁의 따뜻한 한입은 오래 기억나. 천천히 맛보자.',
      festival: '불빛이 물 위에 흔들려. 요란한 소리도 멀리선 아름답구나.',
      culture: '말보다 긴 여운을 남기는 작품이야. 파도처럼 마음에 돌아올 것 같아.',
      history: '오래전 밤에도 누군가 이 물결을 바라봤겠지. 같은 마음이었을까?',
      shopping: '화려한 불빛 사이에서도 잔잔한 색이 눈에 들어와.',
      other: '설명하지 않아도 마음이 머무는 곳이 있어. 잠시 그대로 있자.',
    },
  },
  {
    templateId: 'suncheon-galpi',
    lines: {
      default: '쉿, 갈대 사이에서 작은 움직임이 들려. 놀라지 않게 천천히 가자.',
      nature: '저기 물결 하나가 다르게 움직여. 누가 지나가는지 조용히 기다려보자.',
      food: '이곳의 먹거리는 물과 땅의 계절을 닮았어. 고마운 마음으로 맛보자.',
      festival: '사람이 많아졌네. 갈대와 새들이 놀라지 않게 정해진 길로 가자.',
      culture: '자연을 바라보는 마음이 담긴 작품이야. 오래 지켜주고 싶어져.',
      history: '습지는 수많은 계절을 품어왔어. 사라진 물길도 기억하고 있겠지.',
      shopping: '필요한 만큼만 고르는 것도 자연을 돕는 일이야. 천천히 생각하자.',
      other: '모르는 생명을 만나면 먼저 거리를 두고 살펴보자. 그게 다정한 인사야.',
    },
  },
  {
    templateId: 'mokpo-hongari',
    lines: {
      default: '포구 바람에 맛있는 냄새가 실렸어! 오늘 별미는 내가 찾아낼게.',
      nature: '바람의 짠맛이 달라졌어. 바다 가까이 왔다는 신호야.',
      food: '이건 설명할 시간도 아까운 냄새야. 따뜻할 때 바로 맛보자!',
      festival: '먹거리 부스가 끝도 없네! 한곳씩 공평하게 맛보는 작전을 세우자.',
      culture: '한 접시에 포구 이야기를 이렇게 담았네. 눈으로 보고 입으로 기억하자.',
      history: '오래된 항구엔 오래 이어진 맛이 있어. 사람들 손맛까지 알아보고 싶어.',
      shopping: '싱싱함은 빛과 냄새로 알 수 있어. 내가 꼼꼼히 골라줄게!',
      other: '무슨 곳인지 몰라도 맛있는 냄새가 나면 좋은 시작이지. 따라와!',
    },
  },
  {
    templateId: 'damyang-juksoli',
    lines: {
      default: '댓잎 스치는 소리가 길의 속도를 알려줘. 그 리듬에 맞춰 걷자.',
      nature: '바람이 수천 장의 잎을 한꺼번에 넘겨. 서두르지 말고 들어보자.',
      food: '담백한 향이 마음을 편하게 해. 천천히 씹으며 쉬어가자.',
      festival: '빠른 장단도 대숲을 지나니 부드러워져. 우리도 가볍게 즐기자.',
      culture: '여백과 선이 대나무처럼 곧아. 마음이 단정해지는 작품이야.',
      history: '오랜 바람이 지나도 대숲은 다시 일어나. 그 시간을 배워가자.',
      shopping: '손에 오래 닿을 물건은 결이 편안해야 해. 천천히 골라보자.',
      other: '방향을 모르겠다면 바람부터 들어봐. 자연스럽게 길이 생길 거야.',
    },
  },
  {
    templateId: 'iksan-boseoki',
    lines: {
      default: '오래된 흙 속에도 별빛은 숨어 있어. 작은 단서부터 함께 찾아보자.',
      nature: '돌과 풀 사이에 작은 반짝임이 있어. 자연이 숨겨둔 단서 같아.',
      food: '오래된 재료와 손맛이 만나 빛나는 한입이 됐네.',
      festival: '사람들 웃음이 별처럼 퍼져. 옛이야기가 오늘 다시 빛나는구나.',
      culture: '작은 조각을 이어 큰 뜻을 만들었어. 섬세하게 들여다보자.',
      history: '사라진 것의 자리를 보면 남은 이야기가 보여. 단서를 천천히 맞춰보자.',
      shopping: '겉빛보다 오래 품을 가치가 있는지 살펴보자. 진짜 보물은 조용하니까.',
      other: '아직 정체를 모른다는 건 발견할 여지가 많다는 뜻이야. 기대해도 좋아.',
    },
  },
  {
    templateId: 'gimpo-geumnuri',
    lines: {
      default: '황금 들판 끝까지 물길이 반짝여. 오늘도 넉넉한 마음으로 걸어보자.',
      nature: '물길에 작은 하늘이 비쳤어. 논과 강이 서로 인사하는 것 같아.',
      food: '갓 지은 밥 냄새다! 따뜻할 때 한 숟갈씩 꼭 나눠 먹자.',
      festival: '풍년을 축하하는 장단이 들려! 내 꼬리도 절로 들썩거려.',
      culture: '들판의 계절을 이렇게 아름답게 담았네. 손끝에 햇살이 남아 있어.',
      history: '오래 이어진 물길이 수많은 밥상을 키웠겠지. 고마운 길이야.',
      shopping: '알이 꽉 차고 향이 좋은 걸 골라보자. 내가 꼼꼼히 살펴줄게.',
      other: '처음 보는 길에도 물소리는 이어져. 반짝이는 쪽부터 가보자!',
    },
  },
  {
    templateId: 'yongin-baekami',
    lines: {
      default: '맑은 빛은 요란하지 않아도 오래 남아. 오늘 마음도 단정히 빚어보자.',
      nature: '흰 구름과 푸른 나무가 한 폭에 담겼어. 자연의 색은 참 단정해.',
      food: '정갈한 그릇에 담으니 한입도 작품 같아. 천천히 음미하자.',
      festival: '화려한 빛 사이에도 고요한 여백이 있네. 그곳에서 축제를 바라볼래.',
      culture: '손으로 빚은 작은 굴곡마다 마음이 담겼어. 가까이서 천천히 보자.',
      history: '깨진 조각도 이어보면 시대의 모양이 보여. 소중히 기억하고 싶어.',
      shopping: '오래 곁에 둘수록 편안한 것을 골라보자. 매끈함보다 마음이 중요해.',
      other: '이름을 몰라도 아름다운 선은 느낄 수 있어. 조용히 둘러보자.',
    },
  },
  {
    templateId: 'hwaseong-gaetnori',
    lines: {
      default: '물이 빠진 자리마다 작은 발자국이 나타났어. 갯벌 친구들을 만나러 가자!',
      nature: '게가 옆걸음으로 인사했어! 멀리서 조용히 길을 비켜주자.',
      food: '바다와 땅이 함께 키운 맛이네. 생명을 준 갯벌에 감사하며 먹자.',
      festival: '사람들 발걸음이 많아졌어. 정해진 길 안에서 신나게 즐기자!',
      culture: '갯벌의 선과 색을 이렇게 담았네. 물때의 리듬까지 느껴지는 것 같아.',
      history: '이 물길은 아주 오래 들고났겠지. 발자국은 지워져도 이야기는 남아.',
      shopping: '갯벌을 생각한 물건인지 살펴보자. 오래 쓰는 선택이 친구들을 도와.',
      other: '낯선 구멍은 손대지 말고 기다려보자. 주인이 먼저 인사할지도 몰라.',
    },
  },
  {
    templateId: 'pocheon-dolbami',
    lines: {
      default: '단단한 돌 사이로 맑은 물이 흐르네. 든든하게 네 옆을 걸어줄게.',
      nature: '물은 단단한 돌도 천천히 다듬어. 오래 바라보면 부드러운 길이 보여.',
      food: '계곡을 걸은 뒤 먹는 한입은 유난히 든든해. 천천히 꼭꼭 씹자.',
      festival: '북소리가 바위벽에 울려 더 커졌어! 내 발도 장단을 맞춰볼래.',
      culture: '돌의 결을 살려 만든 모습이 멋져. 힘을 빼야 선이 더 잘 보이네.',
      history: '이 바위는 수많은 계절을 견뎠겠지. 말없는 이야기를 들어보자.',
      shopping: '보기보다 튼튼하고 오래 쓸 수 있는지 살펴보자. 내가 들어볼게.',
      other: '길이 울퉁불퉁해도 괜찮아. 내가 앞에서 발 디딜 곳을 찾아줄게.',
    },
  },
  {
    templateId: 'wonju-hanjiri',
    lines: {
      default: '얇은 한 장도 겹치면 오래가는 이야기가 돼. 오늘 기억도 곱게 붙여둘게.',
      nature: '나뭇결과 종이결이 닮았어. 자연이 남긴 선을 천천히 따라가자.',
      food: '정갈하게 싸인 한입에 손길이 담겼어. 고마움을 함께 맛보자.',
      festival: '종이등이 바람에 살랑여! 수많은 이야기가 밤하늘에 떠 있는 것 같아.',
      culture: '겹치고 물들이고 말리는 손길이 보여. 한 장 안에 시간이 참 많아.',
      history: '오래된 기록이 남은 건 질긴 결과 지킨 마음 덕분이야. 소중히 읽자.',
      shopping: '손끝에 닿는 결이 편안한지 봐. 오래 곁에 둘 물건은 촉감도 중요해.',
      other: '빈 종이 같은 장소네. 우리가 천천히 첫 장면을 남겨볼까?',
    },
  },
  {
    templateId: 'pyeongchang-memiri',
    lines: {
      default: '하얀 메밀꽃이 바람마다 춤춰! 우리도 꽃밭 장단에 맞춰 폴짝여보자.',
      nature: '작은 꽃마다 벌과 바람이 찾아와. 들판 전체가 함께 춤추고 있어.',
      food: '고소하고 담백한 향이야! 꽃밭을 닮은 맛을 천천히 즐기자.',
      festival: '음악이 시작됐어! 하얀 물결 사이로 신나게 행진해보자.',
      culture: '꽃 한 송이의 모양까지 정성껏 담았네. 밝은 기분이 번져와.',
      history: '이 들판의 축제도 수많은 계절을 지나 이어졌겠지. 장단을 기억하자.',
      shopping: '메밀 향이 은은하고 손길이 느껴지는 걸 골라보자. 선물도 좋겠어!',
      other: '처음 보는 곳도 한 바퀴 뛰면 금세 무대가 돼. 같이 시작하자!',
    },
  },
  {
    templateId: 'danyang-gosuri',
    lines: {
      default: '어두워도 걱정 마. 물방울 울림을 들으면 동굴의 길이 그려지거든.',
      nature: '물 한 방울이 오랜 시간 돌을 빚고 있어. 아주 느린 자연의 조각이야.',
      food: '동굴 밖 향긋한 한입이 반가워. 냄새도 길을 알려주는 소리 같아.',
      festival: '북소리가 동굴처럼 울려 가슴까지 닿아! 박자를 따라 날아볼래.',
      culture: '빛과 그림자로 깊이를 만들었네. 소리 없이도 공간이 들리는 것 같아.',
      history: '오래된 흔적일수록 깊은 곳에 남아. 울림을 해치지 않게 살펴보자.',
      shopping: '소리가 맑고 오래 울리는 물건을 찾아보자. 살짝 두드려봐도 될까?',
      other: '낯선 곳이면 먼저 가만히 들어봐. 길이 자기 소리로 인사할 거야.',
    },
  },
  {
    templateId: 'jecheon-yakchori',
    lines: {
      default: '산바람에 약초 향이 섞였어. 오늘 마음에 필요한 향부터 찾아보자.',
      nature: '비슷해 보여도 잎맥과 향이 모두 달라. 함부로 꺾지 말고 눈으로 배우자.',
      food: '산의 향을 살린 따뜻한 음식이네. 한입마다 몸이 편안해지는 것 같아.',
      festival: '약초 향과 웃음이 골목 가득 퍼졌어. 배운 이야기를 함께 나눠보자.',
      culture: '풀 한 포기에 담긴 지혜를 이렇게 이어왔구나. 정성껏 기억하고 싶어.',
      history: '누군가의 경험이 이름과 쓰임으로 남았어. 오래된 지혜를 소중히 듣자.',
      shopping: '향이 지나치게 세지 않고 믿을 만한 손길로 만든 것을 골라보자.',
      other: '모르는 풀은 만지지 말고 모양부터 살펴봐. 아는 만큼 안전해져.',
    },
  },
  {
    templateId: 'cheonan-hodami',
    lines: {
      default: '단단한 껍질 안엔 고소한 마음이 숨어 있어. 좋은 건 꼭 반으로 나누자!',
      nature: '나무가 작은 보물들을 떨어뜨렸어. 필요한 만큼만 고맙게 줍자.',
      food: '껍질을 열자 고소한 향이 톡 퍼졌어! 첫 조각은 네가 먹어.',
      festival: '호두 굴리기와 깨기 소리가 장단 같아! 나도 신나게 참가할래.',
      culture: '작은 열매 모양을 이렇게 정교하게 담았네. 손끝이 정말 야무져.',
      history: '오래된 나무 아래서도 사람들이 호두를 나눴겠지. 따뜻한 풍경이야.',
      shopping: '흔들어보고 무게도 재보자. 속이 꽉 찬 호두는 내가 알아볼 수 있어.',
      other: '낯선 곳에도 숨겨진 고소함이 있을 거야. 꼼꼼히 찾아보자!',
    },
  },
  {
    templateId: 'buyeo-yeonkkori',
    lines: {
      default: '연꽃 사이 물길은 오래된 궁의 이야기를 기억해. 꼬리를 따라 천천히 와.',
      nature: '연잎 아래 작은 물고기가 쉬고 있어. 물결을 작게 만들어 지나가자.',
      food: '연잎 향이 은은하게 밴 맛이야. 오래된 지혜까지 함께 담긴 것 같아.',
      festival: '등불이 물 위에 길을 만들었어! 옛 궁의 밤도 이렇게 빛났을까?',
      culture: '연꽃 선과 물결 무늬가 우아하게 이어져. 마음까지 차분해지는구나.',
      history: '돌 하나와 물길 하나에도 왕도의 시간이 남아 있어. 서두르지 말고 듣자.',
      shopping: '옛 무늬를 가볍게 흉내 낸 건지 정성껏 이어온 건지 살펴보자.',
      other: '이름 없는 물길도 어딘가의 기억으로 이어져. 꼬리를 따라와.',
    },
  },
  {
    templateId: 'gunsan-milbomi',
    lines: {
      default: '항구 바람에 밀 향과 오래된 창고 냄새가 섞였어. 시간의 길을 따라 날아보자.',
      nature: '갈매기와 바람, 밀밭이 한 길로 이어져. 바다와 땅이 만나는 풍경이야.',
      food: '밀 향이 구수하게 피어올라. 항구 사람들의 든든한 하루가 담긴 맛이네.',
      festival: '창고 사이 음악이 울리고 깃발이 펄럭여! 바람을 타고 함께 즐기자.',
      culture: '오래된 건물에 새 작품이 자리 잡았어. 두 시간이 멋지게 만났네.',
      history: '철길과 창고에 수많은 발걸음이 남아 있어. 가볍게 지나치지 말자.',
      shopping: '옛 공간의 이야기를 존중하며 만든 물건인지 살펴보자. 오래 간직하고 싶어.',
      other: '낯선 골목 끝에도 바다는 보여. 지붕 위에서 방향을 찾아줄게.',
    },
  },
  {
    templateId: 'namwon-sarangbi',
    lines: {
      default: '꽃비가 내리면 숨겨둔 마음도 살짝 피어나. 네 진심을 노래로 이어줄게.',
      nature: '꽃과 새가 서로 계절을 알려주네. 말하지 않아도 이어지는 마음 같아.',
      food: '달콤한 향이 마음까지 풀어줘. 좋아하는 사람과 나누면 더 맛있겠지?',
      festival: '노래와 꽃비가 거리를 가득 채웠어! 우리도 사랑스러운 장단을 보태자.',
      culture: '오래된 사랑 이야기가 새로운 노래로 피었네. 마음은 시대를 건너나 봐.',
      history: '수많은 만남과 기다림이 이 길에 남아 있어. 진심을 가볍게 여기지 말자.',
      shopping: '마음을 전할 작은 선물을 고르자. 화려함보다 떠올린 시간이 중요해.',
      other: '처음 보는 곳에도 누군가 아끼는 마음이 있어. 다정하게 둘러보자.',
    },
  },
  {
    templateId: 'gochang-bokbuni',
    lines: {
      default: '새콤달콤한 향이 코끝을 간질여! 가장 잘 익은 열매를 찾아줄게.',
      nature: '햇빛과 비가 작은 열매 안에 모였어. 필요한 만큼만 감사히 따자.',
      food: '새콤함 뒤에 달콤함이 따라와! 천천히 맛보면 기운이 살아나.',
      festival: '보랏빛 향과 웃음이 가득해! 바구니를 들고 신나게 둘러보자.',
      culture: '열매의 색을 이렇게 곱게 담았네. 계절의 향까지 느껴지는 것 같아.',
      history: '오래전부터 이 열매로 기운을 나눴대. 정성이 이어진 맛이구나.',
      shopping: '향이 맑고 색이 깊은 걸 골라보자. 눌리지 않게 내가 잘 안을게.',
      other: '낯선 수풀도 향을 따라가면 길이 보여. 내 코를 믿어봐!',
    },
  },
  {
    templateId: 'gurye-sansuri',
    lines: {
      default: '노란 꽃이 먼저 봄을 알리고 붉은 열매가 가을을 기억해. 계절 소식을 들으러 가자.',
      nature: '꽃과 열매가 같은 나무의 다른 인사야. 계절마다 표정이 참 다르지?',
      food: '새콤한 향 속에 햇살이 담겼어. 몸을 따뜻하게 생각하며 맛보자.',
      festival: '노란 꽃길에 사람들 웃음이 이어졌어! 봄이 크게 인사하는 것 같아.',
      culture: '가지의 곡선과 꽃의 색을 섬세하게 담았네. 계절을 오래 간직할 수 있겠어.',
      history: '마을의 오래된 나무가 수많은 봄과 가을을 지켜봤겠지. 이야기를 들어보자.',
      shopping: '계절의 향을 해치지 않고 정성껏 만든 것을 고르자. 오래 기억될 거야.',
      other: '어디인지 몰라도 식물의 표정을 보면 계절이 길을 알려줘. 천천히 보자.',
    },
  },
  {
    templateId: 'wando-miyeori',
    lines: {
      default: '푸른 물결 아래 미역 숲이 살랑여. 싱싱한 바다 길을 따라가자!',
      nature: '미역 숲은 작은 물고기들의 집이야. 잎을 건드리지 않게 지나가자.',
      food: '바다 향이 깨끗하고 씹을수록 맛있어! 건강한 힘을 천천히 채우자.',
      festival: '푸른 해초와 깃발이 함께 흔들려! 바다 장단에 맞춰 둥실 놀자.',
      culture: '바다의 선과 색을 생활 속에 담았네. 손끝에 물결이 느껴져.',
      history: '이 바다에서 오래 먹거리를 길러왔대. 물때를 읽는 지혜가 대단해.',
      shopping: '색이 맑고 바다 향이 깨끗한 걸 고르자. 필요한 만큼만 챙길게.',
      other: '낯선 바다도 물결을 읽으면 길이 보여. 내 지느러미를 따라와!',
    },
  },
  {
    templateId: 'ulleung-ojingari',
    lines: {
      default: '화산섬 아래 깊은 물빛이 꿈틀거려! 낯선 바닷길도 나와 함께라면 괜찮아.',
      nature: '검은 바위와 푸른 파도가 부딪혀 새로운 모양을 만들고 있어. 멋지다!',
      food: '깨끗한 바다 향이 가득해. 섬의 힘을 한입씩 고맙게 맛보자.',
      festival: '파도 소리와 북소리가 함께 울려! 내 팔도 장단에 맞춰 춤출래.',
      culture: '섬과 바다의 색을 강하게 담았네. 멀리서도 힘이 느껴지는 작품이야.',
      history: '섬을 오간 수많은 배의 길이 물 아래 겹쳐 있겠지. 흔적을 따라가 보자.',
      shopping: '바다와 섬을 아끼며 만든 물건인지 살펴보자. 오래 쓸 것을 고를래.',
      other: '지도에 없는 길이면 더 신나지! 물결을 읽으며 천천히 탐험하자.',
    },
  },
  {
    templateId: 'yeongju-seonbiri',
    lines: {
      default: '어려운 글도 한 줄씩 읽으면 도토리처럼 알찬 뜻이 보여. 함께 풀어보자.',
      nature: '나이테도 풀잎도 자연이 쓴 글이야. 모양과 흐름을 천천히 읽어보자.',
      food: '정성 들인 한입에는 지역의 지혜가 담겨 있어. 맛과 뜻을 함께 기억하자.',
      festival: '배운 이야기가 노래와 놀이로 살아났어. 즐기면서 익히니 더 잘 남겠구나.',
      culture: '글과 그림, 손길이 서로 뜻을 보태고 있어. 여러 번 볼수록 깊어져.',
      history: '기록의 빈자리도 중요한 단서야. 남은 흔적을 차분히 맞춰보자.',
      shopping: '겉모양보다 만든 뜻과 오래 쓸 가치를 살펴보자. 좋은 선택도 배움이야.',
      other: '모른다는 말은 배움의 첫 줄이야. 부끄러워 말고 함께 질문하자.',
    },
  },
  {
    templateId: 'hadong-maesili',
    lines: {
      default: '봄빛 매실 향이 톡 퍼졌어! 지친 마음도 산뜻하게 깨워줄게.',
      nature: '작은 꽃이 열매가 되기까지 햇빛과 바람이 도왔어. 계절의 선물이야.',
      food: '새콤함과 달콤함이 알맞게 만났어! 한입 먹으니 기운이 번쩍 난다.',
      festival: '초록 열매와 웃음이 가득해! 상큼한 장단에 맞춰 뛰어보자.',
      culture: '매실의 색과 향을 생활 속에 정성껏 담았네. 봄을 오래 간직할 수 있겠어.',
      history: '해마다 열매를 담그며 기다림을 이어왔대. 시간이 맛을 깊게 했구나.',
      shopping: '단단하고 향이 맑은 걸 골라보자. 상처 나지 않게 내가 잘 담을게.',
      other: '낯선 길도 산뜻한 향이 나는 쪽부터 가보자. 좋은 일이 있을 것 같아!',
    },
  },
  {
    templateId: 'geoje-dongbaegi',
    lines: {
      default: '차가운 바닷바람 속에서도 동백은 붉게 피어. 내가 따뜻하게 곁을 지켜줄게.',
      nature: '바위틈 동백이 바다를 바라보고 있어. 강인함과 부드러움이 함께 있네.',
      food: '찬 바다에서 온 재료에 따뜻한 손길이 더해졌어. 마음까지 든든한 맛이야.',
      festival: '붉은 꽃길과 바닷바람이 축제를 열었어! 지느러미로 장단을 맞춰볼래.',
      culture: '동백의 붉은색과 바다의 청록색이 멋지게 어울려. 오래 바라보고 싶어.',
      history: '이 섬의 사람들도 바람을 견디며 길을 이어왔겠지. 단단한 마음이 느껴져.',
      shopping: '동백과 바다를 아끼며 만든 것인지 살펴보자. 따뜻한 뜻을 고르고 싶어.',
      other: '낯선 바람이 불어도 내 곁으로 와. 따뜻한 방향을 함께 찾자.',
    },
  },
  {
    templateId: 'jeju-hanrari',
    lines: {
      default: '한라산 구름이 숲길을 천천히 열어줘. 고요한 방향으로 함께 걸을까?',
      nature: '구름, 숲, 돌이 높이에 따라 다른 표정을 보여. 발걸음을 낮추고 바라보자.',
      food: '섬의 바람과 햇살이 담긴 맛이야. 천천히 먹으니 마음까지 맑아져.',
      festival: '산 아래 웃음과 장단이 번져와. 고요함을 잃지 않으며 함께 즐기자.',
      culture: '섬의 선과 색을 담백하게 담았네. 여백에서 바람 소리가 들리는 것 같아.',
      history: '이 숲길과 오름에는 오래된 삶의 발자국이 있어. 조용히 존중하며 걷자.',
      shopping: '섬을 아끼고 오래 쓸 수 있는 것을 고르자. 필요한 만큼이면 충분해.',
      other: '앞이 흐리면 잠시 멈춰도 괜찮아. 구름이 걷힐 때까지 함께 기다릴게.',
    },
  },
];

const regionalDialogueSeed = regionalDialogueProfiles.flatMap((profile) => [
  ...visitDialogueTriggers.map((trigger) => ({
    id: `${profile.templateId}-${trigger}`,
    templateId: profile.templateId,
    trigger,
    text: profile.lines[trigger],
  })),
]);

const dialogueSeed = [
  {
    id: 'wave-naru-default',
    templateId: 'wave-naru',
    trigger: 'default',
    text: '바람이 먼저 길을 알려주네. 우리도 천천히 따라가 볼까?',
  },
  {
    id: 'wave-naru-nature',
    templateId: 'wave-naru',
    trigger: 'nature',
    text: '풀잎이 한쪽으로 누웠어. 바람이 난 길을 따라가 보자.',
  },
  {
    id: 'wave-naru-food',
    templateId: 'wave-naru',
    trigger: 'food',
    text: '고소한 냄새가 바닷바람을 뚫고 왔어. 저쪽부터 살펴볼까?',
  },
  {
    id: 'wave-naru-festival',
    templateId: 'wave-naru',
    trigger: 'festival',
    text: '불빛이 물결처럼 번져! 사람들 웃음까지 반짝이는 것 같아.',
  },
  {
    id: 'wave-naru-culture',
    templateId: 'wave-naru',
    trigger: 'culture',
    text: '처음 보는 장면이 마음에 파문을 남겼어. 오래 기억할게.',
  },
  {
    id: 'wave-naru-history',
    templateId: 'wave-naru',
    trigger: 'history',
    text: '오래된 길에도 바람은 계속 드나들었겠지. 잠깐 귀 기울여 보자.',
  },
  {
    id: 'wave-naru-shopping',
    templateId: 'wave-naru',
    trigger: 'shopping',
    text: '골목마다 흐름이 달라. 북적이는 물결을 놓치지 말자.',
  },
  {
    id: 'wave-naru-other',
    templateId: 'wave-naru',
    trigger: 'other',
    text: '목적지가 없어도 괜찮아. 뜻밖의 길이 더 재미있을 때도 있으니까.',
  },
  {
    id: 'harbor-maru-default',
    templateId: 'harbor-maru',
    trigger: 'default',
    text: '킁킁, 오늘은 골목 끝에서 좋은 냄새가 오는데? 확인하러 가자.',
  },
  {
    id: 'harbor-maru-nature',
    templateId: 'harbor-maru',
    trigger: 'nature',
    text: '바람이 맑으니 냄새도 선명해. 풀향 뒤에 고소한 향이 숨어 있어.',
  },
  {
    id: 'harbor-maru-food',
    templateId: 'harbor-maru',
    trigger: 'food',
    text: '잠깐, 이 냄새는 진짜야. 서두르되 한 입씩 천천히 맛보자.',
  },
  {
    id: 'harbor-maru-festival',
    templateId: 'harbor-maru',
    trigger: 'festival',
    text: '축제엔 볼거리도 많지만 먹거리는 더 많지. 동선을 잘 짜야 해!',
  },
  {
    id: 'harbor-maru-culture',
    templateId: 'harbor-maru',
    trigger: 'culture',
    text: '작품을 보고 나니 맛도 표현이라는 생각이 들어. 멋진 한 접시처럼.',
  },
  {
    id: 'harbor-maru-history',
    templateId: 'harbor-maru',
    trigger: 'history',
    text: '오래 이어진 가게엔 이유가 있어. 한입에 시간이 담겨 있거든.',
  },
  {
    id: 'harbor-maru-shopping',
    templateId: 'harbor-maru',
    trigger: 'shopping',
    text: '시장 길은 내 전문이지. 사람 흐름보다 냄새를 따라오면 돼.',
  },
  {
    id: 'harbor-maru-other',
    templateId: 'harbor-maru',
    trigger: 'other',
    text: '일단 둘러보자. 의외의 곳에서 인생 간식을 만날 수도 있으니까.',
  },
  {
    id: 'film-bori-default',
    templateId: 'film-bori',
    trigger: 'default',
    text: '좋아, 장면 준비. 오늘의 첫 컷은 네 웃는 얼굴로 시작할게.',
  },
  {
    id: 'film-bori-nature',
    templateId: 'film-bori',
    trigger: 'nature',
    text: '바람이 풀잎을 넘기는 장면이 좋아. 소리까지 담아두고 싶어.',
  },
  {
    id: 'film-bori-food',
    templateId: 'film-bori',
    trigger: 'food',
    text: '김이 오르는 순간을 봤어? 맛있는 장면은 기다려주지 않아.',
  },
  {
    id: 'film-bori-festival',
    templateId: 'film-bori',
    trigger: 'festival',
    text: '음악, 불빛, 웃음! 어느 쪽을 봐도 절정 장면이야.',
  },
  {
    id: 'film-bori-culture',
    templateId: 'film-bori',
    trigger: 'culture',
    text: '한 작품이 내 시선을 완전히 바꿨어. 오늘의 중심 장면으로 정했어.',
  },
  {
    id: 'film-bori-history',
    templateId: 'film-bori',
    trigger: 'history',
    text: '시간이 겹쳐 보이는 곳이야. 오래된 흔적을 천천히 따라가자.',
  },
  {
    id: 'film-bori-shopping',
    templateId: 'film-bori',
    trigger: 'shopping',
    text: '간판과 진열장이 빠르게 이어져. 재미있는 몽타주가 되겠는걸.',
  },
  {
    id: 'film-bori-other',
    templateId: 'film-bori',
    trigger: 'other',
    text: '계획에 없던 장면이 더 진짜 같을 때가 있어. 그대로 가보자.',
  },
  {
    id: 'spark-yuri-default',
    templateId: 'spark-yuri',
    trigger: 'default',
    text: '좋아, 오늘도 마음에 불을 켜자! 신나는 쪽은 내가 먼저 찾을게.',
  },
  {
    id: 'spark-yuri-nature',
    templateId: 'spark-yuri',
    trigger: 'nature',
    text: '풀숲도 자세히 보면 작은 축제장이야. 바람이 박자를 맞추고 있잖아!',
  },
  {
    id: 'spark-yuri-food',
    templateId: 'spark-yuri',
    trigger: 'food',
    text: '따끈한 김이 폭죽처럼 팡! 먹기 전부터 분위기가 달아올랐어.',
  },
  {
    id: 'spark-yuri-festival',
    templateId: 'spark-yuri',
    trigger: 'festival',
    text: '바로 이거야! 음악이 끝날 때까지 마음껏 뛰어보자!',
  },
  {
    id: 'spark-yuri-culture',
    templateId: 'spark-yuri',
    trigger: 'culture',
    text: '무대가 아니어도 작품마다 빛이 있어. 어떤 마음으로 만들었을까?',
  },
  {
    id: 'spark-yuri-history',
    templateId: 'spark-yuri',
    trigger: 'history',
    text: '옛날에도 사람들은 특별한 날에 모였겠지? 그 함성이 들리는 것 같아.',
  },
  {
    id: 'spark-yuri-shopping',
    templateId: 'spark-yuri',
    trigger: 'shopping',
    text: '불빛이 줄지어 켜졌어. 골목 전체가 퍼레이드 길이 됐네!',
  },
  {
    id: 'spark-yuri-other',
    templateId: 'spark-yuri',
    trigger: 'other',
    text: '예정에 없어도 재미있으면 됐지! 우리만의 행사를 시작하자.',
  },
  {
    id: 'alley-raon-default',
    templateId: 'alley-raon',
    trigger: 'default',
    text: '잠깐, 저 모퉁이 봤어? 작은 발견은 늘 시선 끝에 숨어 있다니까.',
  },
  {
    id: 'alley-raon-nature',
    templateId: 'alley-raon',
    trigger: 'nature',
    text: '풀잎 사이에도 작은 길이 있어. 발끝을 조심해서 들여다보자.',
  },
  {
    id: 'alley-raon-food',
    templateId: 'alley-raon',
    trigger: 'food',
    text: '냄새가 골목을 돌아왔어. 근원지는 두 번째 모퉁이쯤이야.',
  },
  {
    id: 'alley-raon-festival',
    templateId: 'alley-raon',
    trigger: 'festival',
    text: '사람 흐름이 평소와 달라. 따라가면 숨은 행사장을 찾을 수 있겠어.',
  },
  {
    id: 'alley-raon-culture',
    templateId: 'alley-raon',
    trigger: 'culture',
    text: '만든 사람의 취향은 작은 모서리에 남아 있어. 가까이서 살펴보자.',
  },
  {
    id: 'alley-raon-history',
    templateId: 'alley-raon',
    trigger: 'history',
    text: '낡은 벽의 자국도 지도야. 예전 길이 어디였는지 알려주거든.',
  },
  {
    id: 'alley-raon-shopping',
    templateId: 'alley-raon',
    trigger: 'shopping',
    text: '진열대 맨 구석을 봐. 의외의 보물은 늘 눈높이 밖에 있어.',
  },
  {
    id: 'alley-raon-other',
    templateId: 'alley-raon',
    trigger: 'other',
    text: '분류하기 어려운 곳일수록 재미있어. 정체를 함께 알아내자.',
  },
  {
    id: 'spring-dami-default',
    templateId: 'spring-dami',
    trigger: 'default',
    text: '서두르지 않아도 괜찮아. 네가 편한 속도로 함께 가자.',
  },
  {
    id: 'spring-dami-nature',
    templateId: 'spring-dami',
    trigger: 'nature',
    text: '바람이 마음을 씻어주는 것 같아. 깊게 숨 쉬고 천천히 걷자.',
  },
  {
    id: 'spring-dami-food',
    templateId: 'spring-dami',
    trigger: 'food',
    text: '따뜻한 냄새만으로도 마음이 놓여. 한입씩 천천히 즐기자.',
  },
  {
    id: 'spring-dami-festival',
    templateId: 'spring-dami',
    trigger: 'festival',
    text: '조금 북적이지만 네 곁이라 괜찮아. 우리만의 편한 자리를 찾자.',
  },
  {
    id: 'spring-dami-culture',
    templateId: 'spring-dami',
    trigger: 'culture',
    text: '마음이 조용해지는 작품이네. 오래 바라봐도 좋을 것 같아.',
  },
  {
    id: 'spring-dami-history',
    templateId: 'spring-dami',
    trigger: 'history',
    text: '오래된 곳은 천천히 볼수록 다정해져. 쉬엄쉬엄 이야기를 듣자.',
  },
  {
    id: 'spring-dami-shopping',
    templateId: 'spring-dami',
    trigger: 'shopping',
    text: '전부 보려고 애쓰지 않아도 돼. 마음 가는 곳만 둘러보자.',
  },
  {
    id: 'spring-dami-other',
    templateId: 'spring-dami',
    trigger: 'other',
    text: '잠깐 머문 자리도 좋은 기억이 될 수 있어. 지금처럼 편하게 있자.',
  },
  {
    id: 'story-goun-default',
    templateId: 'story-goun',
    trigger: 'default',
    text: '이름 하나에도 오래된 사연이 깃들어 있어. 오늘은 어떤 이야기를 만날까?',
  },
  {
    id: 'story-goun-nature',
    templateId: 'story-goun',
    trigger: 'nature',
    text: '산과 물에도 저마다 불리는 이름이 있지. 그 유래를 찾아보자.',
  },
  {
    id: 'story-goun-food',
    templateId: 'story-goun',
    trigger: 'food',
    text: '오래 이어진 음식에는 사람들의 살림과 마음이 함께 담겨 있단다.',
  },
  {
    id: 'story-goun-festival',
    templateId: 'story-goun',
    trigger: 'festival',
    text: '축제는 한마을이 같은 이야기를 기억하는 방법일지도 몰라.',
  },
  {
    id: 'story-goun-culture',
    templateId: 'story-goun',
    trigger: 'culture',
    text: '지금의 마음을 남긴 작품이 훗날엔 오늘의 이야기가 되겠지.',
  },
  {
    id: 'story-goun-history',
    templateId: 'story-goun',
    trigger: 'history',
    text: '여긴 시간이 여러 겹으로 포개진 곳이야. 한 겹씩 조심히 살펴보자.',
  },
  {
    id: 'story-goun-shopping',
    templateId: 'story-goun',
    trigger: 'shopping',
    text: '오래된 가게의 간판도 생활을 적어둔 한 페이지처럼 보여.',
  },
  {
    id: 'story-goun-other',
    templateId: 'story-goun',
    trigger: 'other',
    text: '이름 없는 쉼터에도 누군가의 기억은 남아 있어. 잠시 들어볼까?',
  },
  ...regionalDialogueSeed,
];

export const seedStarterRegionData = onCall({region: functionRegion}, async (request) => {
  requireOperator(request.auth?.uid, request.auth?.token);

  const batch = db.batch();
  const {id: koreaRegionId, ...koreaRegionData} = koreaRegionSeed;
  batch.set(db.collection('regions').doc(koreaRegionId), koreaRegionData, {merge: true});

  for (const region of tourAreaRegions) {
    const {id, ...data} = region;
    batch.set(db.collection('regions').doc(id), data, {merge: true});
  }

  for (const poi of starterPoiSeed) {
    const {id, ...data} = poi;
    batch.set(db.collection('pois').doc(id), data, {merge: true});
  }

  for (const template of starterPetTemplateSeed) {
    const {id, ...data} = template;
    batch.set(db.collection('petTemplates').doc(id), data, {merge: true});
  }

  for (const dialogue of dialogueSeed) {
    const {id, ...data} = dialogue;
    batch.set(db.collection('dialogueSets').doc(id), data, {merge: true});
  }

  await batch.commit();
  return {
    regionCount: 1 + tourAreaRegions.length,
    poiCount: starterPoiSeed.length,
    petTemplateCount: starterPetTemplateSeed.length,
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
      const activeEggId = String(userSnap.data()?.activeEggId ?? '');
      const fallbackEgg = activeEggId
        ? null
        : selectActiveEgg(
          (await transaction.get(userRef.collection('eggs'))).docs,
          '',
        );
      transaction.set(
        userRef,
        {
          lastLoginAt: now,
          ...(fallbackEgg ? {activeEggId: fallbackEgg.id} : {}),
        },
        {merge: true},
      );
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

export const syncKoreaPois = onCall(
  {
    region: functionRegion,
    secrets: [tourApiKey],
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async (request) => {
    requireOperator(request.auth?.uid, request.auth?.token);

    const serviceKey = tourApiKey.value();
    if (!serviceKey) {
      throw new HttpsError('failed-precondition', 'TOUR_API_KEY is not configured.');
    }

    const requestedArea = String(request.data?.areaCode ?? request.data?.regionId ?? '').trim();
    const targetRegions = requestedArea
      ? tourAreaRegions.filter((region) => region.areaCode === requestedArea || region.id === requestedArea)
      : tourAreaRegions;
    if (targetRegions.length === 0) {
      throw new HttpsError('invalid-argument', 'Unknown TourAPI areaCode or regionId.');
    }

    const rowsPerArea = rowsPerAreaFromValue(request.data?.numOfRows);
    const maxItemsPerArea = maxItemsPerAreaFromValue(request.data?.maxItemsPerArea);
    const forceRewrite = request.data?.force === true;
    const enrichBudget = detailEnrichLimitFromValue(request.data?.enrichDetails);

    const pending: PendingBatch = {batch: db.batch(), writeCount: 0};
    const syncedByRegion: Record<string, number> = {};
    const capabilities: TourCapabilityReport = {
      detailIntro: enrichBudget > 0 ? 'pending' : 'disabled',
      petTour: enrichBudget > 0 ? 'pending' : 'disabled',
    };
    let remainingEnrich = enrichBudget;
    let fetched = 0;
    let written = 0;
    let skipped = 0;
    let enriched = 0;

    for (const region of targetRegions) {
      const items = await fetchTourAreaItems(
        serviceKey,
        region.areaCode,
        rowsPerArea,
        maxItemsPerArea,
      );
      const knownModifiedTimes = await readKnownPoiModifiedTimes(region.id);
      let regionWrites = 0;

      for (const item of items) {
        if (!item.contentid || !item.title || !item.mapx || !item.mapy) {
          continue;
        }
        const lat = Number(item.mapy);
        const lng = Number(item.mapx);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
          continue;
        }
        fetched += 1;

        const docId = `tourapi-${item.contentid}`;
        const modifiedTime = item.modifiedtime?.trim() ?? '';
        // TourAPI가 수정시각을 그대로 주므로 변경분만 기록한다.
        const unchanged =
          !forceRewrite &&
          modifiedTime !== '' &&
          knownModifiedTimes.get(docId) === modifiedTime;
        if (unchanged) {
          skipped += 1;
          continue;
        }

        const poiDoc: Record<string, unknown> = {
          tourApiContentId: item.contentid,
          title: item.title.trim(),
          regionId: region.id,
          category: mapTourCategory(item.cat1, item.contenttypeid),
          tendency: mapTourTendency(item.cat1, item.contenttypeid),
          contentTypeId: item.contenttypeid ?? '',
          lat,
          lng,
          sourceUpdatedAt: FieldValue.serverTimestamp(),
        };
        assignIfPresent(poiDoc, 'cat1', item.cat1);
        assignIfPresent(poiDoc, 'cat2', item.cat2);
        assignIfPresent(poiDoc, 'cat3', item.cat3);
        assignIfPresent(poiDoc, 'address', joinAddress(item.addr1, item.addr2));
        assignIfPresent(poiDoc, 'imageUrl', toSecureImageUrl(item.firstimage));
        assignIfPresent(poiDoc, 'thumbnailUrl', toSecureImageUrl(item.firstimage2));
        assignIfPresent(poiDoc, 'tel', item.tel);
        assignIfPresent(poiDoc, 'sigunguCode', item.sigungucode);
        assignIfPresent(poiDoc, 'sourceModifiedTime', modifiedTime);

        if (remainingEnrich > 0) {
          const detail = await enrichPoiFromTourApi(
            serviceKey,
            item.contentid,
            item.contenttypeid ?? '',
            capabilities,
          );
          if (detail.attempted) {
            remainingEnrich -= 1;
          }
          if (detail.applied) {
            enriched += 1;
            Object.assign(poiDoc, detail.fields);
          }
        }

        pending.batch.set(db.collection('pois').doc(docId), poiDoc, {merge: true});
        pending.writeCount += 1;
        await commitBatchIfFull(pending);
        written += 1;
        regionWrites += 1;
      }

      syncedByRegion[region.id] = regionWrites;
    }

    await commitRemainingBatch(pending);
    if (capabilities.detailIntro === 'pending') {
      capabilities.detailIntro = 'disabled';
    }
    if (capabilities.petTour === 'pending') {
      capabilities.petTour = 'disabled';
    }

    logger.info('Synced Korea POIs', {
      fetched,
      written,
      skipped,
      enriched,
      regions: targetRegions.length,
      capabilities,
    });

    return {
      // 기존 호출부 호환을 위해 count는 기록한 문서 수를 유지한다.
      count: written,
      fetched,
      written,
      skipped,
      enriched,
      regionCount: targetRegions.length,
      rowsPerArea,
      maxItemsPerArea,
      syncedByRegion,
      capabilities,
    };
  },
);

/** 지역 내 기존 POI의 수정시각만 읽어 증분 동기화 기준으로 삼는다. */
async function readKnownPoiModifiedTimes(regionId: string): Promise<Map<string, string>> {
  const snapshot = await db
    .collection('pois')
    .where('regionId', '==', regionId)
    .select('sourceModifiedTime')
    .get();

  const modifiedTimes = new Map<string, string>();
  for (const doc of snapshot.docs) {
    const value = doc.get('sourceModifiedTime');
    if (typeof value === 'string' && value !== '') {
      modifiedTimes.set(doc.id, value);
    }
  }
  return modifiedTimes;
}

/**
 * detailIntro2(승인 완료)와 detailPetTour2(승인 대기)로 POI를 보강한다.
 * 미승인 오퍼레이션은 첫 403에서 비활성 처리하고 이후 호출하지 않는다.
 */
async function enrichPoiFromTourApi(
  serviceKey: string,
  contentId: string,
  contentTypeId: string,
  capabilities: TourCapabilityReport,
): Promise<{attempted: boolean; applied: boolean; fields: Record<string, unknown>}> {
  const fields: Record<string, unknown> = {};
  let attempted = false;
  let applied = false;

  if (capabilities.detailIntro !== 'forbidden' && contentTypeId !== '') {
    attempted = true;
    try {
      const intro = await fetchTourDetailIntro(serviceKey, contentId, contentTypeId);
      capabilities.detailIntro = 'ok';
      if (intro) {
        assignIfPresent(fields, 'openTime', intro.openTime);
        assignIfPresent(fields, 'restDate', intro.restDate);
        assignIfPresent(fields, 'parking', intro.parking);
        assignIfPresent(fields, 'signatureMenu', intro.signatureMenu);
        if (intro.inquiryTel) {
          fields.tel = intro.inquiryTel;
        }
        applied = Object.keys(fields).length > 0;
      }
    } catch (error) {
      if (error instanceof TourApiForbiddenError) {
        capabilities.detailIntro = 'forbidden';
        logger.warn('detailIntro2 is not approved; skipping enrichment.');
      } else {
        logger.warn('detailIntro2 enrichment failed', {contentId, error: String(error)});
      }
    }
  }

  if (capabilities.petTour !== 'forbidden') {
    try {
      const petInfo = await fetchTourPetInfo(serviceKey, contentId);
      capabilities.petTour = 'ok';
      if (petInfo) {
        fields.petFriendly = petInfo;
        applied = true;
      }
    } catch (error) {
      if (error instanceof TourApiForbiddenError) {
        // 활용신청 승인 전에는 정상 동작이다. 승인되면 자동으로 채워진다.
        capabilities.petTour = 'forbidden';
        logger.info('detailPetTour2 is not approved yet; pet data will fill in once approved.');
      } else {
        logger.warn('detailPetTour2 lookup failed', {contentId, error: String(error)});
      }
    }
  }

  return {attempted, applied, fields};
}

export const syncBusanPois = syncKoreaPois;

export const getNearbyPois = onCall({region: functionRegion}, async (request) => {
  requireAuth(request.auth?.uid);
  const lat = Number(request.data?.lat);
  const lng = Number(request.data?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new HttpsError('invalid-argument', 'lat and lng are required.');
  }

  const nearestRegion = nearestTourAreaRegion(lat, lng);
  let snapshot = await db
    .collection('pois')
    .where('regionId', '==', nearestRegion.id)
    .limit(500)
    .get();
  if (snapshot.empty) {
    snapshot = await db.collection('pois').limit(1000).get();
  }

  const pois = snapshot.docs
    .map((doc) => ({id: doc.id, ...(doc.data() as PoiDoc)}))
    .map((poi) => ({
      ...toNearbyPoiPayload(poi),
      distanceMeters: distanceMeters(lat, lng, poi.lat, poi.lng),
    }))
    .sort((left, right) => left.distanceMeters - right.distanceMeters)
    .slice(0, 30);

  return {pois};
});

/**
 * 클라이언트로 내보낼 필드만 추린다.
 * Firestore Timestamp가 그대로 직렬화되는 것을 막고 응답 크기를 줄인다.
 */
function toNearbyPoiPayload(poi: PoiDoc & {id: string}): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    id: poi.id,
    title: poi.title,
    regionId: poi.regionId,
    category: poi.category,
    lat: poi.lat,
    lng: poi.lng,
  };
  assignIfPresent(payload, 'tourApiContentId', poi.tourApiContentId);
  assignIfPresent(payload, 'tendency', poi.tendency);
  assignIfPresent(payload, 'contentTypeId', poi.contentTypeId);
  assignIfPresent(payload, 'address', poi.address);
  assignIfPresent(payload, 'imageUrl', poi.imageUrl);
  assignIfPresent(payload, 'thumbnailUrl', poi.thumbnailUrl);
  assignIfPresent(payload, 'tel', poi.tel);
  assignIfPresent(payload, 'openTime', poi.openTime);
  assignIfPresent(payload, 'restDate', poi.restDate);
  assignIfPresent(payload, 'parking', poi.parking);
  assignIfPresent(payload, 'signatureMenu', poi.signatureMenu);
  if (poi.petFriendly && Object.keys(poi.petFriendly).length > 0) {
    payload.petFriendly = poi.petFriendly;
  }
  return payload;
}

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
  let companionPetId = starterPetId;
  let creditedEggId: string | null = null;
  let appliedEggProgress = 0;

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
    const eggsSnapshot = await transaction.get(userRef.collection('eggs'));
    const petsSnapshot = await transaction.get(userRef.collection('pets'));
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
    companionPetId = activePetId;

    const storedActiveEggId = String(userSnap.data()?.activeEggId ?? '');
    const openEgg = selectActiveEgg(eggsSnapshot.docs, storedActiveEggId);
    const creditableEgg =
      openEgg?.data.status === 'incubating' ? openEgg : null;
    let nextActiveEggId: string | null = openEgg?.id ?? null;
    let creditedEggRef: DocumentReference<DocumentData> | null =
      creditableEgg?.ref ?? null;
    let creditedEggData: EggDoc | null = creditableEgg?.data ?? null;

    if (!creditedEggRef && needsStarterBootstrap) {
      creditedEggId = starterEggId;
      creditedEggRef = userRef.collection('eggs').doc(starterEggId);
      creditedEggData = starterEggRuntimeDoc();
      nextActiveEggId = starterEggId;
    } else {
      creditedEggId = creditableEgg?.id ?? null;
      if (creditableEgg) {
        nextActiveEggId = creditableEgg.id;
      }
    }
    appliedEggProgress = creditedEggRef && creditedEggData ? eggProgress : 0;

    transaction.set(checkinRef, {
      poiId,
      regionId: poi.regionId,
      category: poi.category,
      lat,
      lng,
      distanceMeters: distance,
      rewardApplied: true,
      reward,
      eggProgress: appliedEggProgress,
      companionPetId,
      creditedEggId,
      createdAt: now,
    });

    const pet = needsStarterBootstrap
      ? starterPetRuntimeDoc()
      : activePetSnap.data() as PetDoc;
    const stats = addStats(pet.stats, reward);
    const level = levelFor(stats);
    const stage = stageFor(level, stats, pet.stage);
    const bondXp = Number(pet.bond?.xp ?? pet.stats.affinity) + reward.affinity;
    transaction.set(
      activePetRef,
      {
        stats,
        level,
        stage,
        bond: {
          xp: bondXp,
          level: bondLevelFor(bondXp),
        },
        lastInteractedAt: now,
      },
      {merge: true},
    );
    updatedPet = {id: activePetId, stats, level, stage};

    if (creditedEggRef && creditedEggData) {
      const progress = Math.min(
        creditedEggData.requiredSteps,
        creditedEggData.progress + appliedEggProgress,
      );
      const imprints = Array.from(new Set([
        ...(creditedEggData.imprints ?? []),
        poi.category,
      ]));
      const creditedStatus =
        progress >= creditedEggData.requiredSteps ? 'hatchable' : 'incubating';
      transaction.set(
        creditedEggRef,
        {
          progress,
          status: creditedStatus,
          incubationBondXp: Number(creditedEggData.incubationBondXp ?? 0) + 1,
          imprints,
          lastProgressAt: now,
        },
        {merge: true},
      );
      // 이번 체크인으로 부화 준비를 마쳤다면, 아직 품고 있는 다른 알로 바로
      // 넘겨준다. 그러지 않으면 다음 걸음이 어떤 알에도 쌓이지 않는다.
      if (creditedStatus === 'hatchable') {
        const stillIncubating = selectActiveEgg(
          eggsSnapshot.docs.filter((doc) => doc.id !== creditedEggId),
          '',
        );
        if (stillIncubating?.data.status === 'incubating') {
          nextActiveEggId = stillIncubating.id;
        }
      }
    }

    const openEggCount = eggsSnapshot.docs.filter((egg) => {
      const status = String(egg.data().status ?? '');
      return status === 'incubating' || status === 'hatchable';
    }).length;
    if (!needsStarterBootstrap && openEggCount < maxStoredEggs &&
      (todayCheckins.empty || poi.category === 'history' || poi.category === 'festival')) {
      const excludedTemplateIds = new Set([
        ...petsSnapshot.docs.map((pet) => String(pet.data().templateId ?? '')),
        ...eggsSnapshot.docs.map((egg) => String(egg.data().templateId ?? '')),
      ]);
      const templateId = templateForCategory(
        poi.category,
        poi.regionId,
        poiId,
        excludedTemplateIds,
      );
      const droppedEggId = `egg-${templateId}-${now.toMillis()}`;
      transaction.set(userRef.collection('eggs').doc(droppedEggId), {
        templateId,
        originRegionId: poi.regionId,
        progress: 0,
        requiredSteps: 3500,
        status: 'incubating',
        createdAt: now,
        originPoiId: poiId,
        finderPetId: companionPetId,
        incubationBondXp: 1,
        imprints: [poi.category],
      });
      if (!nextActiveEggId) {
        nextActiveEggId = droppedEggId;
      }
    }

    transaction.set(
      userRef,
      {
        activePetId,
        activeEggId: nextActiveEggId,
        lastCheckInAt: now,
        updatedAt: now,
      },
      {merge: true},
    );
  });

  {
    // Keep the callable response field stable while returning only progress
    // that was actually credited to the selected egg.
    const eggProgress = appliedEggProgress;
    return {
      success: true,
      distanceMeters: Math.round(distance),
      reward,
      eggProgress,
      updatedPet,
      companionPetId,
      creditedEggId,
    };
  }
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

  return db.runTransaction(async (transaction) => {
    const eggSnap = await transaction.get(eggRef);
    if (!eggSnap.exists) {
      throw new HttpsError('not-found', 'Egg not found.');
    }

    const egg = eggSnap.data() as EggDoc;
    if (egg.status !== 'hatchable') {
      throw new HttpsError('failed-precondition', 'Egg is not hatchable yet.');
    }

    const template = starterPetTemplateSeed.find((item) => item.id === egg.templateId);
    if (!template) {
      throw new HttpsError('failed-precondition', 'Pet template not found.');
    }

    const userSnap = await transaction.get(userRef);
    const matchingPets = await transaction.get(
      userRef.collection('pets').where('templateId', '==', egg.templateId),
    );
    const eggsSnapshot = await transaction.get(userRef.collection('eggs'));
    const remainingEggDocs = eggsSnapshot.docs.filter((doc) => doc.id !== eggId);
    const nextActiveEgg = selectActiveEgg(
      remainingEggDocs,
      String(userSnap.data()?.activeEggId ?? ''),
    );
    const existingPet = [...matchingPets.docs]
      .sort((left, right) => left.id.localeCompare(right.id))[0];

    if (existingPet) {
      const pet = existingPet.data() as PetDoc;
      const stats = {
        ...pet.stats,
        affinity: pet.stats.affinity + 5,
      };
      const level = levelFor(stats);
      const stage = stageFor(level, stats, pet.stage);
      const reunionCount = Number(pet.reunionCount ?? 0) + 1;
      const bondXp = Number(pet.bond?.xp ?? pet.stats.affinity) + 5;
      const bond = {
        xp: bondXp,
        level: bondLevelFor(bondXp),
      };
      transaction.set(
        existingPet.ref,
        {
          stats,
          level,
          stage,
          bond,
          reunionCount,
          lastInteractedAt: now,
        },
        {merge: true},
      );
      transaction.delete(eggRef);
      transaction.set(
        userRef,
        {
          activeEggId: nextActiveEgg?.id ?? null,
          updatedAt: now,
        },
        {merge: true},
      );
      return {
        petId: existingPet.id,
        reunion: true,
        updatedPet: {
          id: existingPet.id,
          stats,
          level,
          stage,
          bond,
          reunionCount,
        },
      };
    }

    const hatchedPetId = `pet-${egg.templateId}-${now.toMillis()}`;
    const initialBondXp = Math.max(10, 10 + Number(egg.incubationBondXp ?? 0));
    const initialKnowledge = Math.max(5, Number(egg.imprints?.length ?? 0) * 2);
    transaction.set(userRef.collection('pets').doc(hatchedPetId), {
      templateId: egg.templateId,
      name: template.name,
      stage: 'baby',
      level: 1,
      stats: {
        exp: 10,
        mood: 15,
        knowledge: initialKnowledge,
        affinity: initialBondXp,
      },
      originRegionId: egg.originRegionId,
      originEggId: eggId,
      bond: {
        xp: initialBondXp,
        level: bondLevelFor(initialBondXp),
      },
      reunionCount: 0,
      hatchedAt: now,
      lastInteractedAt: null,
    });
    transaction.delete(eggRef);
    transaction.set(
      userRef,
      {
        activeEggId: nextActiveEgg?.id ?? null,
        updatedAt: now,
      },
      {merge: true},
    );
    return {petId: hatchedPetId, reunion: false};
  });
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
  const cursorRef = userRef.collection('stepSyncDays').doc(dayKey);
  let hatchableCount = 0;
  let appliedStepDelta = 0;

  await db.runTransaction(async (transaction) => {
    const userSnap = await transaction.get(userRef);
    const cursorSnap = await transaction.get(cursorRef);
    const needsStarterBootstrap = !userSnap.exists;
    const userData = userSnap.data() ?? {};
    const legacyUsedToday = userData.stepCreditDay === dayKey
      ? Number(userData.stepCreditToday ?? 0)
      : 0;
    const cursorData = cursorSnap.data() ?? {};
    const usedToday = Math.max(
      legacyUsedToday,
      Number(cursorData.creditedSteps ?? 0),
    );
    const remainingToday = Math.max(0, maxDailyStepDelta - usedToday);
    if (remainingToday <= 0) {
      throw new HttpsError('failed-precondition', 'Daily step progress limit reached.');
    }

    appliedStepDelta = Math.min(requestedStepDelta, remainingToday);
    const eggs = await transaction.get(userRef.collection('eggs'));
    const activeEgg = needsStarterBootstrap
      ? null
      : selectActiveEgg(eggs.docs, String(userData.activeEggId ?? ''));

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

    const previousObservedSteps = Number(
      cursorData.maxObservedCumulativeSteps ??
      (cursorSnap.exists ? 0 : usedToday),
    );
    transaction.set(
      cursorRef,
      {
        dayKey,
        maxObservedCumulativeSteps: previousObservedSteps + appliedStepDelta,
        creditedSteps: usedToday + appliedStepDelta,
        updatedAt: now,
        lastSource: 'applyStepProgress_v1',
      },
      {merge: true},
    );
    transaction.set(
      userRef,
      {
        activeEggId: needsStarterBootstrap ? starterEggId : activeEgg?.id ?? null,
        stepCreditDay: dayKey,
        stepCreditToday: usedToday + appliedStepDelta,
        updatedAt: now,
      },
      {merge: true},
    );
  });

  return {hatchableCount, appliedStepDelta};
});

export const syncStepsV2 = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const operationId = String(request.data?.operationId ?? '').trim();
  const deviceId = String(request.data?.deviceId ?? '').trim();
  const dayKey = String(request.data?.dayKey ?? '').trim();
  const observedCumulativeSteps = Number(request.data?.observedCumulativeSteps);
  const observedAtValue = request.data?.observedAt;
  const observedAtMillis = typeof observedAtValue === 'number'
    ? observedAtValue
    : Date.parse(String(observedAtValue ?? ''));
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(operationId)) {
    throw new HttpsError(
      'invalid-argument',
      'operationId must be 8-128 URL-safe characters.',
    );
  }
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(deviceId)) {
    throw new HttpsError(
      'invalid-argument',
      'deviceId must be 8-128 URL-safe characters.',
    );
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dayKey)) {
    throw new HttpsError('invalid-argument', 'dayKey must use YYYY-MM-DD.');
  }
  if (!Number.isInteger(observedCumulativeSteps) ||
    observedCumulativeSteps < 0 ||
    observedCumulativeSteps > 1_000_000) {
    throw new HttpsError(
      'invalid-argument',
      'observedCumulativeSteps must be an integer between 0 and 1000000.',
    );
  }
  if (!Number.isFinite(observedAtMillis)) {
    throw new HttpsError(
      'invalid-argument',
      'observedAt must be an ISO-8601 timestamp or epoch milliseconds.',
    );
  }

  const userRef = db.collection('users').doc(uid);
  const operationRef = userRef.collection('stepSyncOperations').doc(operationId);
  const dayCursorRef = userRef.collection('stepSyncDays').doc(dayKey);
  const deviceCursorRef = userRef.collection('stepSyncDevices').doc(deviceId);
  const now = Timestamp.now();

  return db.runTransaction(async (transaction): Promise<StepSyncResult> => {
    const operationSnap = await transaction.get(operationRef);
    if (operationSnap.exists) {
      const operation = operationSnap.data() ?? {};
      if (operation.dayKey !== dayKey ||
        operation.deviceId !== deviceId ||
        Number(operation.observedCumulativeSteps) !== observedCumulativeSteps ||
        Number(operation.observedAtMillis) !== observedAtMillis) {
        throw new HttpsError(
          'already-exists',
          'operationId was already used with a different payload.',
        );
      }
      return operation.result as StepSyncResult;
    }
    const observedDate = new Date(observedAtMillis);
    if (koreanDayKey(observedDate) !== dayKey) {
      throw new HttpsError(
        'invalid-argument',
        'dayKey must match observedAt in Korean time.',
      );
    }
    if (dayKey !== koreanDayKey(new Date()) ||
      observedAtMillis > Date.now() + 5 * 60 * 1000) {
      throw new HttpsError(
        'failed-precondition',
        'Only current-day, non-future observations can be synced.',
      );
    }

    const userSnap = await transaction.get(userRef);
    const dayCursorSnap = await transaction.get(dayCursorRef);
    const deviceCursorSnap = await transaction.get(deviceCursorRef);
    const eggs = await transaction.get(userRef.collection('eggs'));
    const pets = await transaction.get(userRef.collection('pets'));
    const userData = userSnap.data() ?? {};
    const dayCursorData = dayCursorSnap.data() ?? {};
    const deviceCursorData = deviceCursorSnap.data() ?? {};
    const legacyUsedToday = userData.stepCreditDay === dayKey
      ? Number(userData.stepCreditToday ?? 0)
      : 0;
    const creditedToday = Math.max(
      legacyUsedToday,
      Number(dayCursorData.creditedSteps ?? 0),
    );
    const hasDeviceBaseline = deviceCursorSnap.exists &&
      Number.isFinite(Number(deviceCursorData.lastObservedCumulativeSteps));
    const previousObservedSteps = Number(
      deviceCursorData.lastObservedCumulativeSteps ?? observedCumulativeSteps,
    );
    const previousObservedAtMillis = Number(
      deviceCursorData.lastObservedAtMillis ?? -1,
    );
    const isNewerObservation =
      !hasDeviceBaseline || observedAtMillis > previousObservedAtMillis;
    const counterReset = hasDeviceBaseline &&
      isNewerObservation &&
      observedCumulativeSteps < previousObservedSteps;
    const newlyObservedSteps = hasDeviceBaseline &&
      isNewerObservation &&
      !counterReset
      ? Math.max(0, observedCumulativeSteps - previousObservedSteps)
      : 0;
    const remainingToday = Math.max(0, maxDailyStepDelta - creditedToday);
    const appliedStepDelta = Math.min(newlyObservedSteps, remainingToday);

    let targetEggId: string | null = null;
    let targetEggRef: DocumentReference<DocumentData> | null = null;
    let targetEggData: EggDoc | null = null;
    const storedActiveEgg = selectActiveEgg(
      eggs.docs,
      String(userData.activeEggId ?? ''),
    );
    if (!storedActiveEgg && !userSnap.exists) {
      targetEggId = starterEggId;
      targetEggRef = userRef.collection('eggs').doc(starterEggId);
      targetEggData = starterEggRuntimeDoc();
    } else {
      const activeEgg = storedActiveEgg;
      const targetEgg =
        activeEgg?.data.status === 'incubating' ? activeEgg : null;
      targetEggId = targetEgg?.id ?? null;
      targetEggRef = targetEgg?.ref ?? null;
      targetEggData = targetEgg?.data ?? null;
    }

    const requestedCompanionPetId = String(
      userData.activePetId ?? starterPetId,
    ) || starterPetId;
    const companionPetDoc = pets.docs.find(
      (pet) => pet.id === requestedCompanionPetId,
    );
    const companionPetId = companionPetDoc?.id ?? starterPetId;
    const companionPetRef = companionPetDoc?.ref ??
      userRef.collection('pets').doc(starterPetId);
    const companionPetData = companionPetDoc
      ? companionPetDoc.data() as PetDoc
      : starterPetRuntimeDoc();
    const needsStarterBootstrap = !userSnap.exists || !companionPetDoc;
    if (!targetEggRef && !storedActiveEgg && needsStarterBootstrap) {
      targetEggId = starterEggId;
      targetEggRef = userRef.collection('eggs').doc(starterEggId);
      targetEggData = starterEggRuntimeDoc();
    }

    let hatchableCount = eggs.docs
      .filter((egg) => egg.data().status === 'hatchable')
      .length;

    if (needsStarterBootstrap) {
      setStarterUser(transaction, userRef, now);
    }

    if (targetEggRef && targetEggData && appliedStepDelta > 0) {
      const progress = Math.min(
        targetEggData.requiredSteps,
        targetEggData.progress + appliedStepDelta,
      );
      const status =
        progress >= targetEggData.requiredSteps ? 'hatchable' : 'incubating';
      if (targetEggData.status !== 'hatchable' && status === 'hatchable') {
        hatchableCount += 1;
      }
      transaction.set(
        targetEggRef,
        {
          progress,
          status,
          incubationBondXp:
            Number(targetEggData.incubationBondXp ?? 0) +
            Math.max(1, Math.floor(appliedStepDelta / 500)),
          lastProgressAt: now,
        },
        {merge: true},
      );
    }

    const nextCreditedToday = creditedToday + appliedStepDelta;
    const previousWalkSteps = companionPetData.walkStepDay === dayKey
      ? Number(companionPetData.walkStepsToday ?? 0)
      : 0;
    const nextWalkSteps = previousWalkSteps + appliedStepDelta;
    const previousMilestones = Math.floor(previousWalkSteps / 500);
    const nextMilestones = Math.floor(nextWalkSteps / 500);
    const awardedBondToday = companionPetData.walkBondDay === dayKey
      ? Number(companionPetData.walkBondAwardedToday ?? 0)
      : 0;
    const bondReward = Math.min(
      Math.max(0, 5 - awardedBondToday),
      Math.max(0, nextMilestones - previousMilestones),
    );
    let updatedPet: UpdatedPetResult | null = null;
    if (appliedStepDelta > 0) {
      const stats = addStats(
        companionPetData.stats,
        {
          exp: bondReward,
          mood: bondReward,
          knowledge: 0,
          affinity: bondReward,
        },
      );
      const level = levelFor(stats);
      const stage = stageFor(
        level,
        stats,
        companionPetData.stage,
      );
      const bondXp =
        Number(companionPetData.bond?.xp ?? companionPetData.stats.affinity) +
        bondReward;
      transaction.set(
        companionPetRef,
        {
          stats,
          level,
          stage,
          bond: {
            xp: bondXp,
            level: bondLevelFor(bondXp),
          },
          walkStepDay: dayKey,
          walkStepsToday: nextWalkSteps,
          walkBondDay: dayKey,
          walkBondAwardedToday: awardedBondToday + bondReward,
          lastWalkedAt: now,
          lastInteractedAt: now,
        },
        {merge: true},
      );
      updatedPet = {id: companionPetId, stats, level, stage};
    }

    const activeEggId = targetEggId ??
      storedActiveEgg?.id ??
      (needsStarterBootstrap ? starterEggId : null);
    const result: StepSyncResult = {
      success: true,
      dayKey,
      deviceId,
      observedCumulativeSteps,
      baselineInitialized: !hasDeviceBaseline,
      counterReset,
      // 새 걸음은 있는데 오늘 상한 때문에 하나도 못 실었다면 클라이언트가
      // 무의미한 재시도를 멈추고 정확한 안내를 띄울 수 있게 알려준다.
      dailyLimitReached: newlyObservedSteps > 0 && remainingToday <= 0,
      appliedStepDelta,
      hatchableCount,
      creditedEggId:
        appliedStepDelta > 0 && targetEggRef ? targetEggId : null,
      companionPetId,
      updatedPet,
    };

    transaction.set(
      dayCursorRef,
      {
        dayKey,
        creditedSteps: nextCreditedToday,
        lastOperationId: operationId,
        updatedAt: now,
      },
      {merge: true},
    );
    if (isNewerObservation) {
      transaction.set(
        deviceCursorRef,
        {
          deviceId,
          lastObservedCumulativeSteps: observedCumulativeSteps,
          lastObservedAt: Timestamp.fromMillis(observedAtMillis),
          lastObservedAtMillis: observedAtMillis,
          lastDayKey: dayKey,
          updatedAt: now,
        },
        {merge: true},
      );
    }
    transaction.set(
      userRef,
      {
        activePetId: companionPetId,
        activeEggId,
        stepCreditDay: dayKey,
        stepCreditToday: nextCreditedToday,
        updatedAt: now,
      },
      {merge: true},
    );
    transaction.set(operationRef, {
      type: 'step_sync_v2',
      deviceId,
      dayKey,
      observedCumulativeSteps,
      observedAt: Timestamp.fromMillis(observedAtMillis),
      observedAtMillis,
      result,
      createdAt: now,
    });
    return result;
  });
});

export const interactWithPet = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const petId = String(request.data?.petId ?? '');
  const actionType = String(request.data?.actionType ?? '');
  const supportedActions: PetInteractionType[] = [
    'talk',
    'feed',
    'play',
    'clean',
    'sleep',
    'touch',
    'tidy',
  ];
  if (!petId || !supportedActions.includes(actionType as PetInteractionType)) {
    throw new HttpsError('invalid-argument', 'petId and valid actionType are required.');
  }

  const reward = rewardForPetInteraction(actionType as PetInteractionType);

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
    const bondXp = Number(pet.bond?.xp ?? pet.stats.affinity) + reward.affinity;
    transaction.set(
      petRef,
      {
        stats,
        level,
        stage,
        bond: {
          xp: bondXp,
          level: bondLevelFor(bondXp),
        },
        lastInteractedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    updatedPet = {id: petId, stats, level, stage};
  });

  return {reward, updatedPet};
});

export const setActivePet = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const petId = String(request.data?.petId ?? '');
  if (!petId) {
    throw new HttpsError('invalid-argument', 'petId is required.');
  }

  const userRef = db.collection('users').doc(uid);
  const petRef = userRef.collection('pets').doc(petId);

  await db.runTransaction(async (transaction) => {
    const userSnap = await transaction.get(userRef);
    const petSnap = await transaction.get(petRef);
    if (!petSnap.exists && petId !== starterPetId) {
      throw new HttpsError('not-found', 'Pet not found.');
    }
    if (!userSnap.exists || !petSnap.exists) {
      setStarterUser(transaction, userRef, FieldValue.serverTimestamp());
    }

    // setStarterUser resets activePetId to the starter, so this write comes last.
    transaction.set(
      userRef,
      {
        activePetId: petId,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  return {activePetId: petId};
});

export const setActiveEgg = onCall({region: functionRegion}, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const eggId = String(request.data?.eggId ?? '').trim();
  if (!eggId) {
    throw new HttpsError('invalid-argument', 'eggId is required.');
  }

  const userRef = db.collection('users').doc(uid);
  const eggRef = userRef.collection('eggs').doc(eggId);
  const now = Timestamp.now();

  await db.runTransaction(async (transaction) => {
    const userSnap = await transaction.get(userRef);
    const eggSnap = await transaction.get(eggRef);
    const canBootstrapStarterEgg =
      !userSnap.exists && !eggSnap.exists && eggId === starterEggId;
    if (!eggSnap.exists && !canBootstrapStarterEgg) {
      throw new HttpsError('not-found', 'Egg not found.');
    }

    const egg = canBootstrapStarterEgg
      ? starterEggRuntimeDoc()
      : eggSnap.data() as EggDoc;
    if (egg.status !== 'incubating') {
      throw new HttpsError('failed-precondition', 'Egg is not incubating.');
    }

    if (!userSnap.exists || !eggSnap.exists) {
      setStarterUser(transaction, userRef, now);
    }
    transaction.set(
      userRef,
      {
        activeEggId: eggId,
        updatedAt: now,
      },
      {merge: true},
    );
  });

  return {activeEggId: eggId};
});

function setStarterUser(
  transaction: Transaction,
  userRef: DocumentReference,
  now: Timestamp | FieldValue,
): void {
  transaction.set(userRef, {
    activePetId: starterPetId,
    activeEggId: starterEggId,
    createdAt: now,
    displayName: '대한민국 여행자',
    homeTheme: 'korea-basic',
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
    templateId: 'busan-paranguri',
    name: '해랑',
    stage: 'baby',
    level: 1,
    stats: {exp: 20, mood: 20, knowledge: 5, affinity: 8},
    originRegionId: 'busan',
  };
}

function starterEggRuntimeDoc(): EggDoc {
  return {
    templateId: 'harbor-maru',
    originRegionId: 'korea',
    progress: 1200,
    requiredSteps: 3500,
    status: 'incubating',
  };
}

function selectActiveEgg(
  docs: readonly QueryDocumentSnapshot<DocumentData>[],
  preferredId: string,
): ResolvedEgg | null {
  const candidates = docs
    .map((doc) => ({
      id: doc.id,
      ref: doc.ref,
      data: doc.data() as EggDoc,
    }))
    .filter((egg) =>
      egg.data.status === 'incubating' || egg.data.status === 'hatchable');

  const byRemainingThenId = (left: ResolvedEgg, right: ResolvedEgg): number => {
    const leftRemaining = Math.max(
      0,
      Number(left.data.requiredSteps ?? 3500) - Number(left.data.progress ?? 0),
    );
    const rightRemaining = Math.max(
      0,
      Number(right.data.requiredSteps ?? 3500) - Number(right.data.progress ?? 0),
    );
    if (leftRemaining !== rightRemaining) {
      return leftRemaining - rightRemaining;
    }
    return left.id.localeCompare(right.id);
  };

  // 걸음과 체크인은 부화 중인 알에만 쌓인다. 이미 부화 준비를 마친 알이
  // 선택돼 있으면 진행도가 통째로 버려지므로, 품고 있는 알을 먼저 고른다.
  const incubating = candidates
    .filter((egg) => egg.data.status === 'incubating')
    .sort(byRemainingThenId);
  const preferredIncubating = incubating.find((egg) => egg.id === preferredId);
  if (preferredIncubating) {
    return preferredIncubating;
  }
  if (incubating.length > 0) {
    return incubating[0];
  }

  const hatchable = candidates
    .filter((egg) => egg.data.status === 'hatchable')
    .sort(byRemainingThenId);
  const preferredHatchable = hatchable.find((egg) => egg.id === preferredId);
  return preferredHatchable ?? hatchable[0] ?? null;
}

function bondLevelFor(xp: number): number {
  if (xp >= 100) {
    return 4;
  }
  if (xp >= 60) {
    return 3;
  }
  if (xp >= 20) {
    return 2;
  }
  return 1;
}

function rewardForPetInteraction(actionType: PetInteractionType): GrowthStats {
  switch (actionType) {
    case 'talk':
      return {exp: 2, mood: 4, knowledge: 0, affinity: 1};
    case 'feed':
      return {exp: 3, mood: 8, knowledge: 0, affinity: 2};
    case 'play':
      return {exp: 3, mood: 6, knowledge: 0, affinity: 2};
    case 'clean':
      return {exp: 2, mood: 4, knowledge: 0, affinity: 1};
    case 'sleep':
      return {exp: 1, mood: 2, knowledge: 0, affinity: 1};
    case 'touch':
      return {exp: 1, mood: 3, knowledge: 0, affinity: 1};
    // 목욕('clean')과 달리 주변 배설물을 치우는 행동이다.
    case 'tidy':
      return {exp: 2, mood: 3, knowledge: 0, affinity: 1};
  }
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

function templateForCategory(
  category: PoiCategory,
  regionId: string,
  poiId: string,
  excludedTemplateIds: Set<string> = new Set(),
): string {
  const availableTemplates = starterPetTemplateSeed.filter(
    (template) => !excludedTemplateIds.has(template.id),
  );
  const candidates =
    availableTemplates.length > 0 ? availableTemplates : starterPetTemplateSeed;
  const regionalCategoryMatches = candidates.filter((template) =>
    template.regionId === regionId && template.primaryCategory === category,
  );
  if (regionalCategoryMatches.length > 0) {
    return regionalCategoryMatches[
      stableTemplateIndex(poiId, regionalCategoryMatches.length)
    ].id;
  }

  const regionalMatches = candidates.filter((template) =>
    template.regionId === regionId,
  );
  if (regionalMatches.length > 0) {
    return regionalMatches[stableTemplateIndex(poiId, regionalMatches.length)].id;
  }

  const categoryMatches = candidates.filter((template) =>
    template.primaryCategory === category,
  );
  if (categoryMatches.length > 0) {
    return categoryMatches[stableTemplateIndex(poiId, categoryMatches.length)].id;
  }
  return candidates[stableTemplateIndex(poiId, candidates.length)].id;
}

function stableTemplateIndex(value: string, length: number): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) >>> 0;
  }
  return hash % length;
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

type PendingBatch = {
  batch: WriteBatch;
  writeCount: number;
};

async function commitBatchIfFull(pending: PendingBatch): Promise<void> {
  if (pending.writeCount < 450) {
    return;
  }
  await pending.batch.commit();
  pending.batch = db.batch();
  pending.writeCount = 0;
}

async function commitRemainingBatch(pending: PendingBatch): Promise<void> {
  if (pending.writeCount === 0) {
    return;
  }
  await pending.batch.commit();
  pending.batch = db.batch();
  pending.writeCount = 0;
}

function rowsPerAreaFromValue(value: unknown): number {
  const parsed = Number(value ?? 100);
  if (!Number.isFinite(parsed)) {
    return 100;
  }
  return Math.min(100, Math.max(1, Math.trunc(parsed)));
}

function maxItemsPerAreaFromValue(value: unknown): number {
  const parsed = Number(value ?? defaultMaxItemsPerArea);
  if (!Number.isFinite(parsed)) {
    return defaultMaxItemsPerArea;
  }
  return Math.min(defaultMaxItemsPerArea, Math.max(1, Math.trunc(parsed)));
}

function detailEnrichLimitFromValue(value: unknown): number {
  const parsed = Number(value ?? defaultDetailEnrichLimit);
  if (!Number.isFinite(parsed)) {
    return defaultDetailEnrichLimit;
  }
  return Math.min(maxDetailEnrichLimit, Math.max(0, Math.trunc(parsed)));
}

/** 빈 문자열을 Firestore에 쓰지 않도록 값이 있을 때만 대입한다. */
function assignIfPresent(
  target: Record<string, unknown>,
  key: string,
  value: string | undefined,
): void {
  const trimmed = value?.trim();
  if (trimmed) {
    target[key] = trimmed;
  }
}

/**
 * TourAPI 이미지 URL은 http로 내려온다.
 * Android cleartext 차단과 iOS ATS에 걸리므로 https로 올린다.
 */
function toSecureImageUrl(url?: string): string | undefined {
  const trimmed = url?.trim();
  if (!trimmed) {
    return undefined;
  }
  return trimmed.startsWith('http://')
    ? `https://${trimmed.slice('http://'.length)}`
    : trimmed;
}

function joinAddress(addr1?: string, addr2?: string): string | undefined {
  const primary = addr1?.trim() ?? '';
  const secondary = addr2?.trim() ?? '';
  const joined = `${primary} ${secondary}`.trim();
  return joined === '' ? undefined : joined;
}

type TourCapabilityStatus = 'pending' | 'ok' | 'forbidden' | 'disabled';

type TourCapabilityReport = {
  detailIntro: TourCapabilityStatus;
  petTour: TourCapabilityStatus;
};

/**
 * 반려동물 동반여행 정보를 조회한다.
 * 활용신청 승인 전에는 403이 떨어지며 호출부에서 건너뛴다.
 */
async function fetchTourPetInfo(
  serviceKey: string,
  contentId: string,
): Promise<PoiPetInfo | null> {
  const body = await callTourApi(serviceKey, 'KorPetTourService2/detailPetTour2', {
    contentId,
  });
  const item = normalizeTourApiItems<TourPetItem>(body)[0];
  if (!item) {
    return null;
  }

  const petInfo: PoiPetInfo = {};
  assignIfPresent(petInfo as Record<string, unknown>, 'accompanyType', item.acmpyTypeCd);
  assignIfPresent(petInfo as Record<string, unknown>, 'guide', item.petTursmInfo);
  assignIfPresent(petInfo as Record<string, unknown>, 'availableFacility', item.relaPosesFclty);
  assignIfPresent(petInfo as Record<string, unknown>, 'rentalItems', item.relaFrnshPrdlst);
  assignIfPresent(
    petInfo as Record<string, unknown>,
    'precautions',
    firstFilledValue(item.acmpyNeedMtr, item.relaAcdntRiskMtr),
  );

  return Object.keys(petInfo).length > 0 ? petInfo : null;
}

/**
 * 두루누비 걷기여행길 코스를 동기화한다.
 * 걸음 수 목표를 실제 코스 거리와 연결하기 위한 데이터다.
 * 활용신청 승인 전에는 403이므로 빈 결과로 정상 종료한다.
 */
export const syncWalkingCourses = onCall(
  {
    region: functionRegion,
    secrets: [tourApiKey],
    timeoutSeconds: 300,
    memory: '512MiB',
  },
  async (request) => {
    requireOperator(request.auth?.uid, request.auth?.token);

    const serviceKey = tourApiKey.value();
    if (!serviceKey) {
      throw new HttpsError('failed-precondition', 'TOUR_API_KEY is not configured.');
    }

    const rowsPerPage = rowsPerAreaFromValue(request.data?.numOfRows);
    const maxCourses = maxItemsPerAreaFromValue(request.data?.maxCourses);
    const pending: PendingBatch = {batch: db.batch(), writeCount: 0};
    let written = 0;
    let pageNo = 1;

    try {
      while (written < maxCourses && pageNo <= tourApiMaxPagesPerArea) {
        const body = await callTourApi(serviceKey, 'Durunubi/courseList', {
          numOfRows: rowsPerPage,
          pageNo,
        });
        const courses = normalizeTourApiItems<DurunubiCourseItem>(body);
        if (courses.length === 0) {
          break;
        }

        for (const course of courses) {
          const courseId = course.crsIdx?.trim();
          const name = course.crsKorNm?.trim();
          if (!courseId || !name) {
            continue;
          }

          const distanceKm = Number(course.crsDstnc);
          const courseDoc: Record<string, unknown> = {
            courseId,
            title: name,
            sourceUpdatedAt: FieldValue.serverTimestamp(),
          };
          if (Number.isFinite(distanceKm) && distanceKm > 0) {
            courseDoc.distanceKm = distanceKm;
            // 성인 평균 보폭 0.7m 기준으로 목표 걸음 수를 환산한다.
            courseDoc.estimatedSteps = Math.round((distanceKm * 1000) / 0.7);
          }
          assignIfPresent(courseDoc, 'routeId', course.routeIdx);
          assignIfPresent(courseDoc, 'requiredTime', course.crsTotlRqrmHour);
          assignIfPresent(courseDoc, 'level', course.crsLevel);
          assignIfPresent(courseDoc, 'summary', firstFilledValue(course.crsSummary, course.crsContents));
          assignIfPresent(courseDoc, 'sigun', course.sigun);
          assignIfPresent(courseDoc, 'gpxPath', course.gpxpath);

          pending.batch.set(
            db.collection('walkingCourses').doc(`durunubi-${courseId}`),
            courseDoc,
            {merge: true},
          );
          pending.writeCount += 1;
          await commitBatchIfFull(pending);
          written += 1;
          if (written >= maxCourses) {
            break;
          }
        }
        pageNo += 1;
      }
    } catch (error) {
      if (error instanceof TourApiForbiddenError) {
        await commitRemainingBatch(pending);
        logger.info('Durunubi is not approved yet; walking course sync skipped.');
        return {count: written, status: 'forbidden', approved: false};
      }
      throw error;
    }

    await commitRemainingBatch(pending);
    logger.info('Synced walking courses', {count: written});
    return {count: written, status: 'ok', approved: true};
  },
);

/**
 * TourAPI는 미승인 오퍼레이션에 HTTP 403 text/plain을 반환한다.
 * 활용신청 여부에 따라 기능을 건너뛸 수 있도록 별도 오류로 구분한다.
 */
class TourApiForbiddenError extends Error {
  constructor(readonly operation: string) {
    super(`TourAPI operation is not approved for this service key: ${operation}`);
    this.name = 'TourApiForbiddenError';
  }
}

/** 재시도해도 결과가 달라지지 않는 오류(잘못된 파라미터, 키 미등록 등). */
class TourApiPermanentError extends Error {
  constructor(readonly operation: string, message: string) {
    super(`TourAPI ${operation} failed: ${message}`);
    this.name = 'TourApiPermanentError';
  }
}

function tourApiDelay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function requestTourApi(
  url: URL,
  operation: string,
): Promise<TourApiBody | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), tourApiTimeoutMs);
  try {
    const response = await fetch(url, {signal: controller.signal});
    const text = await response.text();

    if (response.status === 403) {
      throw new TourApiForbiddenError(operation);
    }
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    let payload: TourApiResponse;
    try {
      payload = JSON.parse(text) as TourApiResponse;
    } catch {
      // 게이트웨이 오류는 XML 또는 평문으로 내려온다.
      if (/NOT_REGISTERED|ACCESS_DENIED|SERVICE ACCESS DENIED/i.test(text)) {
        throw new TourApiForbiddenError(operation);
      }
      throw new TourApiPermanentError(
        operation,
        `non-JSON response: ${text.slice(0, 120)}`,
      );
    }

    const resultCode = payload.response?.header?.resultCode ?? '';
    if (resultCode && resultCode !== '0000') {
      const resultMsg = payload.response?.header?.resultMsg ?? 'unknown';
      throw new TourApiPermanentError(operation, `${resultCode} ${resultMsg}`);
    }

    return payload.response?.body ?? null;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * TourAPI 공통 호출기. 타임아웃·지수 백오프 재시도를 적용하고
 * 미승인(403)과 영구 오류는 재시도하지 않는다.
 */
async function callTourApi(
  serviceKey: string,
  operation: string,
  params: Record<string, string | number>,
): Promise<TourApiBody | null> {
  const url = new URL(`${tourApiBaseUrl}/${operation}`);
  url.searchParams.set('serviceKey', serviceKey);
  url.searchParams.set('MobileOS', 'ETC');
  url.searchParams.set('MobileApp', 'MasilPet');
  url.searchParams.set('_type', 'json');
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, String(value));
  }

  let lastError: unknown = null;
  for (let attempt = 0; attempt <= tourApiMaxRetries; attempt += 1) {
    if (attempt > 0) {
      await tourApiDelay(tourApiRetryBaseDelayMs * 2 ** (attempt - 1));
    }
    try {
      return await requestTourApi(url, operation);
    } catch (error) {
      if (
        error instanceof TourApiForbiddenError ||
        error instanceof TourApiPermanentError
      ) {
        throw error;
      }
      lastError = error;
    }
  }

  throw new HttpsError(
    'unavailable',
    `TourAPI ${operation} failed after ${tourApiMaxRetries + 1} attempts: ${
      lastError instanceof Error ? lastError.message : String(lastError)
    }`,
  );
}

/** areaBasedList2를 totalCount까지 페이지네이션하며 수집한다. */
async function fetchTourAreaItems(
  serviceKey: string,
  areaCode: string,
  rowsPerPage: number,
  maxItems: number,
): Promise<TourApiItem[]> {
  const collected: TourApiItem[] = [];
  const seenContentIds = new Set<string>();
  let totalCount = Number.POSITIVE_INFINITY;
  let pageNo = 1;

  while (collected.length < maxItems && pageNo <= tourApiMaxPagesPerArea) {
    const body = await callTourApi(serviceKey, 'KorService2/areaBasedList2', {
      areaCode,
      numOfRows: rowsPerPage,
      pageNo,
      // 제목순은 동기화 중 데이터가 바뀌어도 페이지가 밀리지 않는다.
      arrange: 'A',
    });
    if (!body) {
      break;
    }

    const reportedTotal = Number(body.totalCount);
    if (Number.isFinite(reportedTotal)) {
      totalCount = reportedTotal;
    }

    const items = normalizeTourApiItems(body);
    if (items.length === 0) {
      break;
    }

    for (const item of items) {
      if (!item.contentid || seenContentIds.has(item.contentid)) {
        continue;
      }
      seenContentIds.add(item.contentid);
      collected.push(item);
    }

    if (seenContentIds.size >= totalCount) {
      break;
    }
    pageNo += 1;
  }

  return collected.slice(0, maxItems);
}

/**
 * detailIntro2로 영업시간·휴무일·대표메뉴를 보강한다.
 * 콘텐츠 타입마다 필드명이 달라 공통 형태로 정규화한다.
 */
async function fetchTourDetailIntro(
  serviceKey: string,
  contentId: string,
  contentTypeId: string,
): Promise<TourDetailIntro | null> {
  const body = await callTourApi(serviceKey, 'KorService2/detailIntro2', {
    contentId,
    contentTypeId,
  });
  const item = normalizeTourApiItems<TourIntroItem>(body)[0];
  if (!item) {
    return null;
  }

  const intro: TourDetailIntro = {
    openTime: firstFilledValue(item.usetime, item.opentimefood, item.opentime),
    restDate: firstFilledValue(item.restdate, item.restdatefood, item.restdateshopping),
    parking: firstFilledValue(item.parking, item.parkingfood, item.parkingshopping),
    inquiryTel: firstFilledValue(item.infocenter, item.infocenterfood, item.infocentershopping),
    signatureMenu: firstFilledValue(item.firstmenu, item.treatmenu),
  };

  return Object.values(intro).some((value) => value !== undefined) ? intro : null;
}

function firstFilledValue(...values: Array<string | undefined>): string | undefined {
  for (const value of values) {
    const trimmed = value?.trim();
    if (trimmed) {
      return trimmed;
    }
  }
  return undefined;
}

function nearestTourAreaRegion(lat: number, lng: number): RegionSeed {
  let nearest = tourAreaRegions[0];
  let nearestDistance = distanceMeters(lat, lng, nearest.center.lat, nearest.center.lng);

  for (const region of tourAreaRegions.slice(1)) {
    const distance = distanceMeters(lat, lng, region.center.lat, region.center.lng);
    if (distance < nearestDistance) {
      nearest = region;
      nearestDistance = distance;
    }
  }

  return nearest;
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

/**
 * TourAPI 대분류(cat1)를 마실펫 성향으로 환산한다.
 * 어디를 다녔는지가 펫 성격을 만드는 규칙의 기준값이다.
 * A01 자연 / A02 인문·문화 / A03 레포츠 / A04 쇼핑 / A05 음식
 */
function mapTourTendency(cat1?: string, contentTypeId?: string): PoiTendency {
  switch (cat1) {
  case 'A01':
    return 'explorer';
  case 'A03':
    return 'explorer';
  case 'A05':
    return 'gourmet';
  case 'A04':
    return 'elegant';
  case 'A02':
    // 축제·공연·행사는 함께 즐기는 경험이라 애교 성향으로 본다.
    return contentTypeId === '15' ? 'affectionate' : 'scholar';
  default:
    break;
  }

  if (contentTypeId === '39') {
    return 'gourmet';
  }
  if (contentTypeId === '38') {
    return 'elegant';
  }
  if (contentTypeId === '15') {
    return 'affectionate';
  }
  if (contentTypeId === '14') {
    return 'scholar';
  }
  return 'balanced';
}

function normalizeTourApiItems<T = TourApiItem>(body: TourApiBody | null): T[] {
  const items = body?.items?.item;
  if (!items) {
    return [];
  }
  return (Array.isArray(items) ? items : [items]) as T[];
}

type TourApiResponse = {
  response?: {
    header?: {
      resultCode?: string;
      resultMsg?: string;
    };
    body?: TourApiBody;
  };
};

type TourApiBody = {
  items?: {
    item?: unknown[] | unknown;
  };
  numOfRows?: number | string;
  pageNo?: number | string;
  totalCount?: number | string;
};

type TourApiItem = {
  contentid?: string;
  contenttypeid?: string;
  title?: string;
  cat1?: string;
  cat2?: string;
  cat3?: string;
  addr1?: string;
  addr2?: string;
  tel?: string;
  zipcode?: string;
  firstimage?: string;
  firstimage2?: string;
  areacode?: string;
  sigungucode?: string;
  modifiedtime?: string;
  mapx?: string;
  mapy?: string;
};

/** detailIntro2는 콘텐츠 타입별로 필드명이 다르다. */
type TourIntroItem = {
  contentid?: string;
  contenttypeid?: string;
  usetime?: string;
  opentime?: string;
  opentimefood?: string;
  restdate?: string;
  restdatefood?: string;
  restdateshopping?: string;
  parking?: string;
  parkingfood?: string;
  parkingshopping?: string;
  infocenter?: string;
  infocenterfood?: string;
  infocentershopping?: string;
  firstmenu?: string;
  treatmenu?: string;
};

type TourDetailIntro = {
  openTime?: string;
  restDate?: string;
  parking?: string;
  inquiryTel?: string;
  signatureMenu?: string;
};

/** 반려동물 동반여행(detailPetTour2) 응답. 활용신청 승인 시에만 채워진다. */
type TourPetItem = {
  contentid?: string;
  acmpyTypeCd?: string;
  petTursmInfo?: string;
  relaAcdntRiskMtr?: string;
  acmpyPsblCpam?: string;
  relaPosesFclty?: string;
  relaFrnshPrdlst?: string;
  etcAcmpyInfo?: string;
  relaPurcPrdlst?: string;
  acmpyNeedMtr?: string;
};

/** 두루누비(Durunubi) 걷기여행길 코스 응답. */
type DurunubiCourseItem = {
  routeIdx?: string;
  crsIdx?: string;
  crsKorNm?: string;
  crsDstnc?: string;
  crsTotlRqrmHour?: string;
  crsLevel?: string;
  crsContents?: string;
  crsSummary?: string;
  sigun?: string;
  gpxpath?: string;
};
