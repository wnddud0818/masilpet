# MasilPet Submission Package

이 문서는 공모전 제출 양식에 바로 옮겨 적기 위한 제출 패키지입니다. 배포 후 앱 URL과 개인정보 처리방침 URL만 실제 Firebase Hosting 주소로 바꿉니다.

## 앱 정보

- 앱 이름: MasilPet
- 앱 URL: 배포 후 Firebase Hosting URL 입력
- 개인정보 처리방침 URL: 배포 후 `https://{hosting-domain}/privacy.html` 입력
- 첫 탐험 지역: 부산광역시

## 한 줄 소개

MasilPet은 실제 지역을 걸으며 150m 안의 장소에 체크인하고, 지역 맥락을 가진 마실펫을 수집·성장시키는 위치 기반 펫 성장 앱입니다.

## 핵심 기능 3줄 요약

1. 최근 15분 안에 확인한 현재 위치로 부산 POI 150m 체크인을 판정합니다.
2. 오늘의 산책 루트가 위치 확인, 첫 체크인, 펫 교감, 알 부화 준비를 한 화면에서 안내합니다.
3. Firebase Functions가 보상 지급과 중복 체크인 방지를 처리하고, TourAPI와 OpenStreetMap으로 지역 장소 경험을 구성합니다.

## 개인정보 처리 요약

- 사용자는 Firebase 익명 인증으로 시작하며 이름, 이메일, 소셜 계정을 요구하지 않습니다.
- 위치 정보는 주변 장소 조회와 150m 체크인 판정에 사용됩니다.
- 체크인은 최근 15분 안에 확인한 위치에서만 가능하며, 체크인 성공 시 장소, 거리, 보상 기록이 사용자 진행도에 저장될 수 있습니다.
- 사용자 진행도 쓰기는 Cloud Functions Admin SDK로만 처리하고, 클라이언트는 Firestore에서 본인의 진행도만 읽을 수 있습니다.
- TourAPI 키와 운영자 권한은 서버 Secret과 custom claim으로 관리하며 Flutter Web 산출물에 포함하지 않습니다.

## 사용 기술

- Flutter Web
- Firebase Auth, Firestore, Cloud Functions, Hosting
- TourAPI
- OpenStreetMap
- SharedPreferences 기반 기기 내 진행 저장

## 시연 흐름

1. 온보딩에서 MasilPet의 지역 탐험 구조를 확인합니다.
2. 지도 탭에서 오늘의 산책 루트, 현재 위치, 주변 POI를 확인합니다.
3. 150m 안의 장소에 체크인해 펫 성장치와 알 진행도를 받습니다.
4. 마실펫 탭에서 대표 펫과 대화하거나 먹이를 줍니다.
5. 하우스에서 오늘의 하우스 플랜, 집중 부화 알, 다음 외출지를 확인합니다.
6. 도감에서 성장 상태, 부산 탐험 여권, 보유 펫, 수집률을 확인합니다.
7. 내 정보 탭에서 실행 모드, 최근 방문 기록, 개인정보 처리방침, 진행도 동기화 상태를 확인합니다.

## 제출 전 증빙

- `tools/release_preflight.ps1` 실행 결과
- `tools/release_evidence.ps1`로 생성한 `build/release-evidence.md`
- Firebase Hosting 배포 URL
- 내 정보 탭의 앱 버전, 빌드 채널, 빌드 시각
- 내 정보 탭의 최근 방문 기록과 실제 적용된 체크인 보상 상세 표시
- 하우스 탭의 오늘의 하우스 플랜, 집중 부화 알, 바로 부화 동선 표시
- 첫 로딩 화면과 JavaScript 비활성화 대체 안내 확인
- PWA 설치 가능 여부와 지도/개인정보 바로가기 확인
- `/privacy.html` 접속 확인
- 내 정보 탭의 진행도 초기화 확인
- 온보딩, 지도, 마실펫, 프로필 화면 스크린샷
- 실기기 위치 권한 허용 후 150m 체크인 성공/실패 확인
- 같은 POI 당일 중복 체크인 거절 확인

## 운영 전제

- `TOUR_API_KEY` Firebase Secret 등록
- Firebase Web 빌드 환경 변수 설정
- 운영자 UID에 `operator: true` custom claim 부여
- `seedStarterRegionData` 호출로 부산 지역 데이터 반영
- 필요 시 `syncBusanPois` 호출로 TourAPI 최신 장소 동기화
