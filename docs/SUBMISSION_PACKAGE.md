# MasilPet Submission Package

이 문서는 공모전 제출 양식에 바로 옮겨 적기 위한 제출 패키지입니다. 배포 후 앱 URL과 개인정보 처리방침 URL만 실제 Firebase Hosting 주소로 바꿉니다.

## 앱 정보

- 앱 이름: MasilPet
- 앱 URL: 배포 후 Firebase Hosting URL 입력
- 개인정보 처리방침 URL: 배포 후 `https://{hosting-domain}/privacy.html` 입력
- 첫 탐험 지역: 대한민국 전역

## 한 줄 소개

MasilPet은 실제 지역을 걸으며 150m 안의 장소에 체크인하고, 지역 맥락을 가진 마실펫을 수집·성장시키는 위치 기반 펫 성장 앱입니다.

## 핵심 기능 3줄 요약

1. 최근 15분 안에 확인한 현재 위치로 전국 POI 150m 체크인을 판정합니다.
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

## 빠른 심사 체험 경로

위치 권한을 바로 허용하기 어려운 심사 환경에서는 지도 화면의 `기본 위치로 체험`을 누르면 전국 기본 POI 기준으로 첫 체크인 루프를 확인할 수 있습니다. 이 경로는 기기 내 진행 모드에서만 체크인을 열고, Firebase 서버 모드에서는 실제 위치 확인을 계속 요구합니다.

## 시연 흐름

1. 온보딩에서 MasilPet의 지역 탐험 구조를 확인합니다.
2. 지도 탭에서 오늘의 산책 루트, 현재 위치, 주변 POI와 카테고리 필터를 확인합니다.
3. 위치 권한이 없으면 `기본 위치로 체험`, 실기기에서는 `현재 위치 확인`으로 첫 체크인 후보를 엽니다.
4. 150m 안의 장소에 체크인해 펫 성장치와 알 진행도를 받습니다.
5. 마실펫 탭에서 `마실펫과 대화하기` 흐름으로 장소 맥락 대사와 능력치 변화를 확인합니다.
6. 하우스에서 오늘의 하우스 플랜, 집중 부화 알, 다음 외출지를 확인합니다.
7. 도감에서 성장 상태, 전국 탐험 여권, 보유 펫, 수집률을 확인합니다.
8. 내 정보 탭에서 오늘의 탐험 리포트, 탐험 배지, 최근 방문 기록, 개인정보 처리방침, 진행도 동기화 상태를 확인합니다.

## 제출 전 증빙

- `tools/release_preflight.ps1` 실행 결과
- `tools/local_judging_smoke.ps1` 실행 결과와 `build/verification/local-judging-smoke-result.json`
- `tools/release_evidence.ps1`로 생성한 `build/release-evidence.md`
- Firebase Hosting 배포 URL
- 내 정보 탭의 앱 버전, 빌드 채널, 빌드 시각
- 내 정보 탭의 오늘의 탐험 리포트와 요약 복사 동선
- 내 정보 탭의 탐험 배지와 다음 행동 안내
- 내 정보 탭의 최근 방문 기록과 실제 적용된 체크인 보상 상세 표시
- 내 정보 탭의 데이터·지도 출처와 지도 타일 설정 표시
- 지도 탭의 POI 카테고리 필터와 선택 카테고리 목록 표시
- 지도 POI 카드의 장소 데이터 출처 표시
- 하우스 탭의 오늘의 하우스 플랜, 집중 부화 알, 바로 부화 동선 표시
- 첫 로딩 화면과 JavaScript 비활성화 대체 안내 확인
- 배포 URL 링크 프리뷰의 제목, 설명, 대표 이미지 확인
- PWA 설치 가능 여부, 지도/개인정보 바로가기, wide/narrow manifest 스크린샷 확인
- `/privacy.html` 접속 확인
- 내 정보 탭의 진행도 초기화 확인
- 온보딩 wide/narrow, 지도, 마실펫, 프로필 화면 스크린샷
- 실기기 위치 권한 허용 후 150m 체크인 성공/실패 확인
- 같은 POI 당일 중복 체크인 거절 확인

## 운영 전제

- `TOUR_API_KEY` Firebase Secret 등록
- Firebase Web 빌드 환경 변수 설정
- 운영자 UID에 `operator: true` custom claim 부여
- `seedStarterRegionData` 호출로 전국 지역 데이터 반영
- 필요 시 `syncKoreaPois` 호출로 TourAPI 최신 장소 동기화
