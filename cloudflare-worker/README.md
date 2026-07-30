# MasilPet Cloudflare Worker

MasilPet의 온라인 체크인, 진행도 저장, 펫 성장과 TourAPI 동기화를 제공하는
HTTP 백엔드입니다. Firebase Spark 요금제에서도 서버 검증 로직을 사용할 수
있도록 Firebase Functions의 callable 로직을 Cloudflare Worker에서 재사용합니다.

운영 Worker:

```text
이름: masilpet-api
주소: https://masilpet-api.firstghrn818.workers.dev
Firebase 프로젝트: masilpet-8ef37
```

현재 GitHub Actions는 검사만 수행합니다. `main`에 커밋하거나 PR을 병합해도
Worker는 자동 배포되지 않으며, 이 문서의 수동 배포 명령을 실행해야 합니다.

## 구성

```text
Flutter 앱
  └─ Firebase 익명 인증으로 ID 토큰 발급
      └─ Authorization: Bearer <ID_TOKEN>
          └─ Cloudflare Worker
              ├─ Firebase ID 토큰 검증
              ├─ functions/src/index.ts의 업무 로직 실행
              ├─ Firestore REST API 읽기·쓰기
              └─ TourAPI 호출
```

- `src/index.ts`: 인증, CORS, 라우팅과 HTTP 응답 처리
- `src/firebase-admin-firestore-worker.ts`: Worker 환경용 Firestore REST 호환 계층
- `../functions/src/index.ts`: 체크인·성장·동기화 등 공통 업무 로직
- `wrangler.jsonc`: Worker 이름, 진입점, 일반 환경변수와 허용 Origin

인증된 API는 `POST /v1/{callableName}` 형식이며 요청 본문은
`{"data": {...}}` 형식을 사용합니다. `/health`만 인증 없이 조회할 수 있습니다.

## 환경변수

### 저장소에 포함되는 일반 변수

다음 값은 `wrangler.jsonc`의 `vars`에 있으며 비밀값이 아닙니다.

| 이름 | 용도 | 현재 값 |
| --- | --- | --- |
| `CLOUDFLARE_WORKER` | Worker 런타임 분기 활성화 | `true` |
| `FIREBASE_PROJECT_ID` | 연결할 Firebase 프로젝트 | `masilpet-8ef37` |
| `ALLOWED_ORIGINS` | 웹 브라우저 요청을 허용할 Origin 목록 | `wrangler.jsonc` 참고 |

웹 로컬 테스트는 허용 목록에 맞춰 포트 `7357`로 실행합니다.

```powershell
flutter run -d chrome --web-port 7357
```

### Cloudflare에 암호화 저장되는 비밀값

| 이름 | 출처 | 용도 |
| --- | --- | --- |
| `FIREBASE_CLIENT_EMAIL` | Firebase 서비스 계정 JSON의 `client_email` | Admin 인증 |
| `FIREBASE_PRIVATE_KEY` | Firebase 서비스 계정 JSON의 `private_key` | OAuth 토큰 서명 |
| `TOUR_API_KEY` | 한국관광공사 TourAPI 포털 | 관광지 데이터 조회 |

이 값들은 Cloudflare의 Worker Secret 저장소에 암호화되어 있습니다. 저장 후에는
평문으로 다시 조회할 수 없고 이름만 확인할 수 있습니다. 서비스 계정 JSON,
개인키, `.dev.vars`를 Git이나 메신저에 올리지 않습니다.

등록된 Secret 이름 확인:

```powershell
Push-Location cloudflare-worker
npx wrangler secret list
Pop-Location
```

새 환경에 처음 등록하거나 값을 교체할 때는 아래 명령을 하나씩 실행하고
프롬프트에 값을 입력합니다. 명령행 인수에 비밀값을 직접 넣지 않아야 셸 기록에
남지 않습니다.

```powershell
Push-Location cloudflare-worker
npx wrangler secret put FIREBASE_CLIENT_EMAIL
npx wrangler secret put FIREBASE_PRIVATE_KEY
npx wrangler secret put TOUR_API_KEY
Pop-Location
```

일반적인 코드 배포는 기존 Secret 값을 유지합니다.

### Flutter 앱 빌드 변수

`MASILPET_API_BASE_URL`은 선택값입니다. 지정하지 않으면 Flutter 앱은 운영
Worker 주소를 사용합니다. 로컬 Worker나 별도 환경을 사용할 때만 바꿉니다.

```powershell
flutter run -d chrome --web-port 7357 `
  --dart-define=MASILPET_API_BASE_URL=http://127.0.0.1:8787
```

### 자동 배포를 추가할 때 필요한 GitHub Secret

현재 자동 배포는 설정되어 있지 않습니다. 추후 GitHub Actions에서 배포하려면
최소한 다음 값을 GitHub Actions Secret으로 등록해야 합니다.

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

이 값들은 Worker 런타임 환경변수가 아니며 저장소에 커밋하면 안 됩니다.

## 로컬 실행

저장소 루트에서 의존성을 설치하고 타입 검사를 실행합니다.

```powershell
npm --prefix functions ci
npm --prefix cloudflare-worker ci
npm --prefix functions run build
npm --prefix cloudflare-worker run check
```

`cloudflare-worker/.dev.vars`를 만들고 로컬 개발용 비밀값을 넣습니다. 이 파일은
`.gitignore`에 포함되어 있습니다.

```dotenv
FIREBASE_CLIENT_EMAIL="..."
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
TOUR_API_KEY="..."
```

Worker 실행:

```powershell
npm --prefix cloudflare-worker run dev
```

상태 확인:

```powershell
Invoke-RestMethod http://127.0.0.1:8787/health
```

Flutter 웹 앱도 함께 테스트한다면 다른 터미널에서 실행합니다.

```powershell
flutter run -d chrome --web-port 7357 `
  --dart-define=MASILPET_API_BASE_URL=http://127.0.0.1:8787
```

## 운영 수동 배포

배포 전에 의도하지 않은 로컬 변경이 포함되지 않도록 깨끗한 `main`인지
확인합니다.

```powershell
git switch main
git pull --ff-only origin main
git status --short
```

처음 사용하는 컴퓨터라면 Cloudflare에 로그인하고 대상 계정을 확인합니다.

```powershell
Push-Location cloudflare-worker
npx wrangler login
npx wrangler whoami
Pop-Location
```

검사 후 배포:

```powershell
npm --prefix functions ci
npm --prefix cloudflare-worker ci
npm --prefix functions run build
npm --prefix cloudflare-worker run check
npm --prefix cloudflare-worker run dry-run

Push-Location cloudflare-worker
npx wrangler whoami
npx wrangler secret list
npm run deploy
Pop-Location
```

`secret list`에 필수 Secret 세 개가 모두 표시되는지 확인한 다음 배포합니다.

## 배포 검증

상태 응답 확인:

```powershell
Invoke-RestMethod `
  -Uri "https://masilpet-api.firstghrn818.workers.dev/health"
```

아래 필드가 모두 `true`여야 합니다.

```json
{
  "ok": true,
  "firebaseCredentialsConfigured": true,
  "tourApiConfigured": true
}
```

배포 버전 확인:

```powershell
Push-Location cloudflare-worker
npx wrangler deployments list
Pop-Location
```

`/health`는 Secret이 존재하는지만 확인합니다. 최종 확인에서는 Flutter 앱에
익명 로그인한 뒤 POI 조회나 진행도 저장처럼 인증이 필요한 API도 시험합니다.

## 롤백

배포 후 장애가 발생하면 `deployments list`에서 직전 정상 버전 ID를 확인하고
롤백합니다.

```powershell
Push-Location cloudflare-worker
npx wrangler rollback PREVIOUS_VERSION_ID `
  --message "Rollback failed deployment"
Pop-Location
```

롤백 후 `/health`와 앱의 인증 API를 다시 확인합니다. Secret 값은 롤백과 별도로
관리되므로 Secret 교체가 장애 원인이었다면 올바른 값으로 다시 등록해야 합니다.

## 자주 발생하는 문제

- `wrangler whoami`의 계정이 다름: 올바른 Cloudflare 계정으로 다시 로그인합니다.
- `firebaseCredentialsConfigured: false`: Firebase Secret 두 개의 이름과 등록 상태를 확인합니다.
- `tourApiConfigured: false`: `TOUR_API_KEY` Secret을 다시 등록합니다.
- 웹에서 CORS 오류 발생: `ALLOWED_ORIGINS`와 실행 포트 `7357`을 확인합니다.
- `401 unauthenticated`: Flutter의 Firebase 초기화와 익명 로그인 여부를 확인합니다.
- 배포 후 코드가 바뀌지 않음: `wrangler deployments list`에서 최신 버전과 시간을 확인합니다.
