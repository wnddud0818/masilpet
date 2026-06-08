# MasilPet Operations Runbook

## 서비스 구성

- Flutter Web 앱은 Firebase Hosting에서 제공한다.
- Firebase 익명 인증으로 사용자를 시작시킨다.
- 사용자 진행도 읽기는 Firestore에서 수행한다.
- 사용자 진행도 쓰기는 callable Cloud Functions가 Admin SDK로 처리한다.
- TourAPI 키는 Firebase Secret으로만 보관한다.

## 배포 순서

```powershell
firebase login
firebase functions:secrets:set TOUR_API_KEY
$env:FIREBASE_WEB_API_KEY="..."
$env:FIREBASE_WEB_APP_ID="..."
$env:FIREBASE_MESSAGING_SENDER_ID="..."
$env:MASILPET_BUILD_CHANNEL="contest"
# 선택: OpenStreetMap 공개 타일 대신 승인된 지도 타일 서비스나 프록시를 사용한다.
$env:MASILPET_MAP_TILE_URL_TEMPLATE="https://tiles.example.com/{z}/{x}/{y}.png"
$env:MASILPET_MAP_TILE_USER_AGENT="com.masilpet.app"
powershell -ExecutionPolicy Bypass -File tools/release_preflight.ps1
powershell -ExecutionPolicy Bypass -File tools/local_judging_smoke.ps1
firebase deploy --only functions,firestore,hosting
powershell -ExecutionPolicy Bypass -File tools/hosting_smoke.ps1 -HostingUrl "https://{hosting-domain}"
powershell -ExecutionPolicy Bypass -File tools/release_evidence.ps1 -HostingUrl "https://{hosting-domain}"
```

preflight는 `pubspec.yaml` 버전과 UTC 빌드 시각을 Flutter Web 산출물에 주입한다. 배포 후 내 정보 화면에서 `앱 버전`, `빌드 채널`, `빌드 시각`이 의도한 제출 빌드와 일치하는지 확인한다.
`local_judging_smoke.ps1`는 로컬 release web 산출물에서 빠른 심사 체험 루프가 실제로 이어지는지 확인하고 `build/verification`에 캡처와 JSON 요약을 남긴다.
지도 타일은 기본적으로 OpenStreetMap 공개 타일을 사용한다. 공개 타일 사용량 정책이나 공모전 시연 환경상 별도 제공자가 필요하면 `MASILPET_MAP_TILE_URL_TEMPLATE`으로 승인된 타일 URL 템플릿을 주입한다.
`release_evidence.ps1`는 실제 제출 증빙에서 Hosting URL을 필수로 요구한다. 로컬 초안 리포트가 필요할 때만 `-AllowDraftEvidence`를 함께 사용한다.

## 운영자 권한과 지역 데이터 반영

운영자 스크립트는 Firebase Admin SDK를 사용하므로 `GOOGLE_APPLICATION_CREDENTIALS`가 서비스 계정 JSON 파일을 가리키거나, `gcloud auth application-default login`으로 Application Default Credentials가 준비되어 있어야 한다. 서비스 계정 JSON은 저장소에 커밋하지 않는다.

운영자 권한은 익명 인증 UID 또는 운영용 Firebase Auth UID에 부여한다.

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\secure\masilpet-service-account.json"
powershell -ExecutionPolicy Bypass -File tools/set_operator_claim.ps1 -Uid "OPERATOR_UID"
```

배포 후 운영자 권한으로 `seedStarterRegionData`를 호출해 전국 지역, POI, 펫 템플릿, 대사 시드를 Firestore에 병합한다.

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_operator_callable.ps1 `
  -Uid "OPERATOR_UID" `
  -FunctionName seedStarterRegionData
```

TourAPI 최신 장소를 반영해야 할 때는 같은 방식으로 `syncKoreaPois`를 호출한다.

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_operator_callable.ps1 `
  -Uid "OPERATOR_UID" `
  -FunctionName syncKoreaPois
```

## 장애 대응

### 앱이 오프라인 모드로만 동작할 때

1. 내 정보 화면의 실행 모드가 `기기 내 진행 (설정 필요)`인지 `기기 내 진행 (연결 실패)`인지 확인한다.
2. `기기 내 진행 (설정 필요)`이면 Firebase Web 환경 변수와 `--dart-define` 값이 빠졌는지 확인한다.
3. `기기 내 진행 (연결 실패)`이면 익명 인증 제공자, Firebase 프로젝트 설정, Functions/Firestore 배포 상태를 확인한다.
4. Firebase 프로젝트 설정과 `--dart-define` 값이 맞는지 확인한다.
5. Functions 배포 지역이 `asia-northeast3`인지 확인한다.
6. 내 정보 화면의 앱 버전과 빌드 시각이 최신 배포인지 확인한다.
7. 브라우저 콘솔에서 Functions callable 오류를 확인한다.

### 주변 장소가 갱신되지 않을 때

1. `TOUR_API_KEY` Secret이 설정되어 있는지 확인한다.
2. `syncKoreaPois` 호출 로그와 운영자 custom claim 상태를 확인한다.
3. TourAPI 응답 제한, 서비스 키 권한, 공공데이터포털 상태를 확인한다.
4. 실패 시 앱은 번들된 전국 seed POI로 계속 동작해야 한다.

### 체크인이 실패할 때

1. 사용자가 POI 반경 150m 안에 있는지 확인한다.
2. 사용자가 최근 15분 안에 현재 위치 확인을 완료했는지 확인한다.
3. 같은 POI에 오늘 이미 체크인했는지 확인한다.
4. 사용자가 하루 체크인 상한 20회에 도달했는지 확인한다.
5. Firestore의 `pois/{poiId}` 좌표와 사용자의 제출 좌표 사이 거리를 확인한다.
6. Functions 로그에서 `failed-precondition`, `already-exists`, `not-found` 오류를 구분한다.

체크인 문서는 `poiId + KST 날짜` 기반 ID로 기록한다. 같은 POI에 같은 날 들어오는 중복 요청은 트랜잭션에서 기존 문서를 읽은 뒤 `already-exists`로 거절하므로, 네트워크 재시도나 빠른 연타가 보상을 중복 지급하지 않아야 한다.

### 진행도가 저장되지 않을 때

1. Firestore rules가 클라이언트 쓰기를 막는 것은 정상이다.
2. `attemptCheckIn`, `applyStepProgress`, `interactWithPet`는 사용자 문서가 아직 없으면 스타터 사용자 상태를 같은 트랜잭션 안에서 보정해야 한다.
3. `ensureUserBootstrap`, `attemptCheckIn`, `applyStepProgress`, `hatchEgg`, `interactWithPet` Functions 로그를 확인한다.
4. 클라이언트는 로컬 저장소에 진행도를 보존하므로, 네트워크 복구 후 `진행도 새로고침`으로 서버 상태를 다시 불러온다.

## 제출 당일 확인

- `flutter analyze`, `flutter test`, `flutter build web --release`, `npm --prefix functions run build`가 통과해야 한다.
- Firebase Hosting URL에서 온보딩, 지도, 마실펫, 하우스, 도감, 내 정보 탭이 모두 표시되어야 한다.
- `tools/hosting_smoke.ps1`가 배포 URL의 앱 셸, 개인정보 페이지, PWA manifest, 보안 헤더를 통과해야 한다.
- PWA manifest의 `id`, `lang`, 지도/개인정보 바로가기가 배포 산출물에 포함되어야 한다.
- 첫 로딩 화면이 표시되고 Flutter 첫 프레임 이후 사라져야 한다.
- 내 정보 탭의 앱 버전, 빌드 채널, 빌드 시각이 제출 빌드와 일치해야 한다.
- 개인정보 안내 카드가 `내 정보` 탭에 보여야 한다.
- `진행도 초기화`를 실행하면 기기 내 진행이 초기화되고, 온라인 연결 상태에서는 `deleteUserProgress` callable이 사용자 진행도 문서와 하위 컬렉션을 삭제해야 한다.
- `/privacy.html` 정적 개인정보 처리방침이 200으로 제공되어야 한다.
- 새 브라우저 프로필에서도 온보딩부터 홈 진입까지 가능해야 한다.
