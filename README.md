# MasilPet

부산을 파일럿 지역으로 한 위치 기반 반려펫 육성 앱입니다. 현재 저장소는 Flutter SDK가 없는 환경에서 직접 스캐폴딩한 소스 구조이며, SDK 설치 후 플랫폼 템플릿을 붙여 실행할 수 있습니다.

## MVP 범위

- Firebase 익명 인증 기반 첫 실행
- 부산 파일럿 지역과 오리지널 마실펫 5종
- TourAPI 연동을 전제로 한 POI/카테고리 모델
- 체크인, 알 부화, 4지표 성장, 진화 조건
- 고정 대사 기반 마실펫 대화
- 마실펫 하우스, 도감, 프로필 화면
- Firebase Functions용 TourAPI/체크인 프록시 골격

## 로컬 실행 준비

이 PC에는 현재 `flutter` 명령이 설치되어 있지 않습니다. Flutter SDK 설치 후 저장소 루트에서 아래 순서로 진행하세요.

```powershell
flutter create --platforms=android,ios .
flutter pub get
flutter test
flutter run
```

Firebase를 실제로 연결하려면 FlutterFire CLI로 플랫폼 설정을 생성하고, Functions 환경변수에 TourAPI 키를 넣어야 합니다.

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

Functions 배포 전 TourAPI 키는 Firebase Secret으로 등록합니다.

```powershell
firebase functions:secrets:set TOUR_API_KEY
npm --prefix functions run build
firebase deploy --only functions,firestore
```

앱 실행 후 `내 정보 > 서버 시드 준비`를 누르면 부산 파일럿 공개 데이터와 사용자 초기화 함수가 호출됩니다.

## 주요 구조

```text
.github/workflows/ci.yml
lib/
  main.dart
  src/
    app.dart
    models.dart
    seed_data.dart
    services.dart
    state.dart
    screens/
functions/
  src/index.ts
test/
assets/
  pets/
    wave_naru/
      emotions/
      growth/
      actions/
```

## 캐릭터 에셋 규칙

마실펫 캐릭터는 개별 PNG를 앱 번들에 넣고 `Image.asset`으로 렌더링합니다. 경로 문자열은 화면에 직접 쓰지 않고 [PetAssets](/C:/Users/first/masilpet/lib/src/pet_assets.dart)에서만 생성합니다.

```dart
Image.asset(
  PetAssets.emotion(template.assetKey, 'happy'),
  fit: BoxFit.contain,
)
```

현재 구조:

```text
assets/
  pets/
    {petKey}/
      emotions/{emotion}.png
      growth/{stage}.png
      actions/{action}.png
```

MVP에서는 `growth/baby.png`, `growth/grown.png`, `growth/evolved.png`, `emotions/happy.png`, `actions/idle.png`를 기본으로 둡니다. 생성 원본 시트는 저장소 밖이나 별도 원본 폴더에 보관하고, 앱 번들에는 실제 사용하는 최종 PNG만 넣습니다.

## 설계 기본값

- 파일럿 지역: 부산광역시
- 체크인 반경: 150m
- MVP 대화: LLM 없이 고정 대사
- 로그인: Firebase 익명 인증, 실패 시 데모 모드 유지
- TourAPI: 클라이언트 직접 호출 금지, Cloud Functions 경유
