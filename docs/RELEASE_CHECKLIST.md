# MasilPet Release Checklist

이 체크리스트는 공모전 제출 전마다 같은 품질 기준으로 앱을 확인하기 위한 문서입니다.

## 1. 코드 검증

```powershell
powershell -ExecutionPolicy Bypass -File tools/release_preflight.ps1 -SkipFirebase
powershell -ExecutionPolicy Bypass -File tools/local_judging_smoke.ps1
```

Firebase 로그인, Secret, Firebase Web 빌드 설정까지 함께 확인할 때는 `-SkipFirebase`를 제거한다.
`local_judging_smoke.ps1`는 release web 산출물에서 온보딩, 기본 위치 체험, 첫 체크인, 마실펫 대화까지의 빠른 심사 루프를 실제 Chrome으로 확인한다.
`release_evidence.ps1`는 Functions moderate npm audit 결과를 증빙 리포트에 남기며, 취약점이 1건 이상이면 실패한다.

## 2. Firebase 준비

- `.firebaserc`의 기본 프로젝트가 제출용 프로젝트인지 확인한다.
- `firebase login`을 완료한다.
- `firebase functions:secrets:set TOUR_API_KEY`로 TourAPI 키를 등록한다.
- `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID` 환경 변수를 설정한다.
- Android 온라인 빌드는 `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`를 설정한다.
- iOS 온라인 빌드는 `FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`를 설정한다.
- Android Application ID와 iOS Bundle ID가 모두 `com.masilpet.app`인지 확인한다.
- iOS Deployment Target이 Firebase Apple SDK와 호환되는 15.0 이상인지 확인한다.
- Android Manifest의 인터넷·정밀/대략 위치 권한과 iOS의 위치 사용 설명 문구를 확인한다.
- `powershell -ExecutionPolicy Bypass -File tools/release_preflight.ps1 -SkipBuild`로 프로젝트 접근, `TOUR_API_KEY` Secret 접근, Firebase Web 빌드 설정값을 확인한다.
- Firebase Web 설정값을 일부러 빼고 실행한 로컬 빌드에서는 앱이 `기기 내 진행 (설정 필요)`로 원인을 표시해야 한다.
- 제출용 빌드 채널을 구분해야 하면 `MASILPET_BUILD_CHANNEL` 환경 변수를 설정한다. 지정하지 않으면 preflight가 `release`로 주입한다.
- OpenStreetMap 공개 타일 사용량 정책을 확인하고, 별도 지도 타일 서비스 또는 프록시가 필요하면 `MASILPET_MAP_TILE_URL_TEMPLATE`과 `MASILPET_MAP_TILE_USER_AGENT`를 설정한다.
- `firebase deploy --only functions,firestore,hosting`으로 Functions, Firestore rules/indexes, Hosting을 함께 배포한다.
- 배포 후 `powershell -ExecutionPolicy Bypass -File tools/hosting_smoke.ps1 -HostingUrl "https://{hosting-domain}"`로 Hosting 앱 셸, 개인정보 페이지, manifest, 보안 헤더를 확인한다.
- `powershell -ExecutionPolicy Bypass -File tools/release_evidence.ps1 -HostingUrl "https://{hosting-domain}"`로 `build/release-evidence.md` 출품 증빙 리포트를 생성한다.
- Hosting URL 없이 생성한 초안 증빙이 필요할 때만 `-AllowDraftEvidence`를 사용한다. 실제 제출 증빙에는 반드시 `-HostingUrl`을 전달한다.
- 로컬 release build 기준 빠른 체험 루프 증빙이 필요하면 `powershell -ExecutionPolicy Bypass -File tools/local_judging_smoke.ps1`를 실행하고 `build/verification/local-judging-*.png`와 `local-judging-smoke-result.json`을 보관한다.
- `GOOGLE_APPLICATION_CREDENTIALS` 또는 Application Default Credentials를 준비하고 `tools/set_operator_claim.ps1`로 운영자 UID에 `operator: true`를 부여한다.
- `tools/run_operator_callable.ps1 -FunctionName seedStarterRegionData`로 전국 지역, POI, 펫 템플릿, 대사 시드를 반영한다.
- TourAPI 최신 장소 동기화가 필요하면 `tools/run_operator_callable.ps1 -FunctionName syncKoreaPois`를 호출한다.
- 첫 사용자 액션이 `ensureUserBootstrap`보다 먼저 도착해도 `attemptCheckIn`, `applyStepProgress`, `interactWithPet`가 스타터 사용자 상태를 서버에서 보정하는지 Functions 로그로 확인한다.
- Firestore rules에서 사용자 진행도 쓰기가 클라이언트에 열려 있지 않은지 확인한다.

## 3. 실제 기기 검증

- 모바일 브라우저에서 배포 URL 접속 후 PWA 설치 프롬프트 또는 홈 화면 추가가 가능한지 확인한다.
- 설치된 PWA의 바로가기에서 지도와 개인정보 처리방침 진입 항목이 보이는지 확인한다.
- PWA manifest의 `screenshots/onboarding-wide.png`와 `screenshots/onboarding-mobile.png`가 설치/심사 화면에서 wide/narrow 미리보기로 표시되는지 확인한다.
- 느린 네트워크에서도 첫 화면이 빈 화면이 아니라 MasilPet 로딩 화면으로 보이는지 확인한다.
- 배포 URL을 메신저나 심사 제출 시스템에 붙여 넣었을 때 MasilPet 제목, 설명, 대표 이미지가 표시되는지 확인한다.
- 위치 권한을 허용하고, 전국 기본 위치 또는 실제 현장 위치로 지도와 POI 목록이 정상 표시되는지 확인한다.
- 위치 권한을 바로 허용하기 어려운 심사 환경에서는 `전국 기본 지도 보기`를 눌러 첫 체크인 후보, 0m 거리, `여기에 도장 찍기` 버튼이 표시되는지 확인한다.
- 지도 화면의 분류 필터(`전체`/`자연`/`음식` …)가 `주변 산책지` 목록을 즉시 좁히는지 확인한다.
- 도감과 하우스의 다음 목표 버튼을 누른 뒤 지도 화면에서 해당 분류 필터가 선택되는지 확인한다.
- 지도 화면의 `오늘의 산책 코스`가 추천 장소를 01·02·03 순서로 표시하고, 범위 안 장소에는 `여기에 도장` 버튼이 붙는지 확인한다.
- 현재 위치 확인 전 또는 위치 확인 15분 경과 후에는 체크인 버튼이 잠기는지 확인한다.
- 150m 밖에서는 체크인이 막히고, 150m 안에서는 체크인 보상이 적용되는지 확인한다.
- 체크인 직후 `방문 인증` 도장 오버레이가 찍히고, 지도 화면의 `방문 인증 완료` 카드가 장소, VISITED 도장, 보상 태그를 표시하는지 확인한다.
- 하단 텍스트 탭 또는 좌측 사이드 레일의 배지가 체크인 수, 남은 대화, 알, 미발견 도감, 연속 산책 일수를 표시하는지 확인한다.
- 같은 POI에 같은 날 중복 체크인을 시도하면 서버에서 `already-exists`로 거절되는지 확인한다.
- 하루 체크인 상한 20회를 넘긴 요청은 서버에서 거절되는지 확인한다.
- 체크인 후 알 진행도, 펫 성장치, 도감 수집률, 수첩 목표가 갱신되는지 확인한다.
- 체크인 후 마실펫 화면의 말풍선이 방문 맥락 대사를 보여주고, `쓰다듬기 · 오늘 N번 남음`과 `같이 다녀온 곳` 노트가 표시되는지 확인한다.
- 하우스 화면의 `마당`에서 펫·공·밥그릇 터치가 반응하고, 알 카드·`오늘의 돌봄`·`하우스 현황`·`다음 외출`이 겹침 없이 표시되는지 확인한다.
- 기록 화면의 `최근 산책` 타임라인에 최근 체크인 시각, 장소, 보상이 표시되는지 확인한다.
- 기록 화면의 `오늘의 리포트`가 방문 수와 알 진행도를 문장으로 요약하고 `리포트 복사하기`가 동작하는지 확인한다.
- 기록 화면의 리포트 태그가 등급, 점수, 성장 루프, 카테고리 진척을 표시하는지 확인한다.
- 기록 화면의 `수첩 목표`가 동행 시작, 위치 인증, 첫 발자국, 장소 이야기꾼, 연속 산책, 부화 준비 진행률과 다음 행동을 표시하는지 확인한다.
- 도감 화면에서 발견한 마실펫과 `미발견` 칸이 구분되고, 지역·발견 상태 필터가 목록을 좁히는지 확인한다.
- 기록 화면의 `WALKING PASSPORT` 달력에서 걸은 날에만 도장이 찍히는지 확인한다.
- 기록 화면의 `개인정보 처리방침 열기` 버튼이 `/privacy.html`로 이동하는지 확인한다.
- 기록 화면 `앱 정보와 연결`의 `앱 버전`, `빌드 채널`, `빌드 시각`이 제출하려는 빌드와 일치하는지 확인한다.
- 기록 화면 `진행도 관리`의 `진행도 초기화`가 확인 다이얼로그를 거친 뒤 기기 내 진행을 초기화하는지 확인한다.
- 브라우저를 닫았다가 다시 열어 기기 내 진행 저장과 Firebase 진행도 새로고침이 모두 동작하는지 확인한다.
- 배포 URL의 `/privacy.html`이 열리고, 기록 화면의 개인정보 안내와 내용이 충돌하지 않는지 확인한다.
- JavaScript 비활성화 환경에서는 앱 실행 대신 개인정보 처리방침 링크가 포함된 안내가 표시되어야 한다.
- 배포 URL의 `/index.html` 응답에 `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options`, `Permissions-Policy`가 적용되어 있는지 확인한다.

## 4. 제출 패키지

- [제출 패키지](SUBMISSION_PACKAGE.md)의 앱 URL과 개인정보 처리방침 URL을 실제 배포 주소로 갱신한다.
- 앱 URL
- 핵심 기능 3줄 요약
- 개인정보 처리 요약
- 개인정보 처리방침 URL: `https://{hosting-domain}/privacy.html`
- 사용 기술: Flutter Web, Firebase Auth/Firestore/Functions/Hosting, TourAPI, OpenStreetMap
- 시연 흐름: 온보딩 -> 지도 산책 코스 -> 위치 사용 -> 도장 찍기 -> 마실펫 성장 -> 하우스 마당/도감 -> 기록 수첩
- 브라우저 검증 스크린샷: 온보딩 wide/narrow, 지도, 마실펫, 기록

## 5. 제출 전 금지 사항

- Flutter Web 산출물에 TourAPI 키를 직접 포함하지 않는다.
- 서비스 계정 JSON 또는 `GOOGLE_APPLICATION_CREDENTIALS` 파일을 저장소에 커밋하지 않는다.
- Firebase Web 설정값 없이 릴리즈 빌드를 만들지 않는다.
- `demo`, `MVP`, 임시 데이터라는 표현을 사용자 화면에 노출하지 않는다.
- `build/web`만 갱신하고 Firestore rules/functions 배포를 빼먹지 않는다.
- 제출용 프로젝트가 아닌 Firebase 프로젝트로 배포하지 않는다.
