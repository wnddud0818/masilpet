import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

String _pngDimensions(String path) {
  final bytes = File(path).readAsBytesSync();
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) {
    throw FormatException('PNG file is too small: $path');
  }
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) {
      throw FormatException('Not a PNG file: $path');
    }
  }

  final data = ByteData.sublistView(bytes);
  return '${data.getUint32(16)}x${data.getUint32(20)}';
}

void main() {
  test('user-facing app sources avoid submission and demo wording', () {
    final userFacingFiles = [
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      ...Directory('web').listSync(recursive: true).whereType<File>().where(
          (file) => file.path.endsWith('.html') || file.path.endsWith('.json')),
    ];

    for (final file in userFacingFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('출품')));
      expect(source, isNot(contains('심사')));
      expect(source, isNot(contains('서버 시드')));
      expect(source, isNot(contains('해운대 기준 위치로 이동')));
      expect(source, isNot(contains('demo')));
      expect(source, isNot(contains('Demo')));
      expect(source, isNot(contains('MVP')));
      expect(source, isNot(contains('placeholder')));
      expect(source, isNot(contains('You can customize')));
    }
  });

  test('README describes the current nationwide collection scope', () {
    final readme = File('README.md').readAsStringSync();

    expect(readme, contains('대한민국 전역'));
    expect(readme, contains('전국 POI'));
    expect(readme, contains('7종 수집'));
    expect(readme, isNot(contains('첫 출품 지역은 부산')));
    expect(readme, isNot(contains('부산 POI 지도')));
    expect(readme, isNot(contains('부산 탐험 여권')));
  });

  test('Firebase Hosting serves the Flutter web app safely', () {
    final config = _readJson('firebase.json');
    final hosting = config['hosting'] as Map<String, dynamic>;

    expect(hosting['public'], 'build/web');
    expect(hosting['ignore'], contains('**/node_modules/**'));

    final rewrites = hosting['rewrites'] as List<dynamic>;
    expect(
      rewrites,
      contains(
        allOf(
          containsPair('source', '**'),
          containsPair('destination', '/index.html'),
        ),
      ),
    );

    final headers =
        (hosting['headers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final noCacheSources = headers
        .where(
          (entry) => (entry['headers'] as List<dynamic>).any(
            (header) =>
                header['key'] == 'Cache-Control' &&
                header['value'] == 'no-cache',
          ),
        )
        .map((entry) => entry['source'])
        .toSet();

    expect(noCacheSources, contains('/index.html'));
    expect(noCacheSources, contains('/flutter_bootstrap.js'));
    expect(noCacheSources, contains('/manifest.json'));
    expect(noCacheSources, contains('/privacy.html'));
    expect(noCacheSources, contains('/robots.txt'));

    final immutableSources = headers
        .where(
          (entry) => (entry['headers'] as List<dynamic>).any(
            (header) =>
                header['key'] == 'Cache-Control' &&
                header['value'] == 'public, max-age=31536000, immutable',
          ),
        )
        .map((entry) => entry['source'])
        .toSet();
    expect(immutableSources, contains('/assets/**'));
    expect(immutableSources, contains('/icons/**'));
    expect(immutableSources, contains('/screenshots/**'));
    expect(immutableSources, contains('/favicon.png'));

    final globalHeaders = headers.singleWhere(
      (entry) => entry['source'] == '**',
    )['headers'] as List<dynamic>;
    expect(
      globalHeaders,
      contains(
        allOf(
          containsPair('key', 'X-Content-Type-Options'),
          containsPair('value', 'nosniff'),
        ),
      ),
    );
    expect(
      globalHeaders,
      contains(
        allOf(
          containsPair('key', 'Referrer-Policy'),
          containsPair('value', 'strict-origin-when-cross-origin'),
        ),
      ),
    );
    expect(
      globalHeaders,
      contains(
        allOf(
          containsPair('key', 'X-Frame-Options'),
          containsPair('value', 'DENY'),
        ),
      ),
    );
    expect(
      globalHeaders,
      contains(
        allOf(
          containsPair('key', 'Permissions-Policy'),
          containsPair(
            'value',
            'geolocation=(self), camera=(), microphone=(), payment=()',
          ),
        ),
      ),
    );
  });

  test('web shell provides loading and no-script fallbacks', () {
    final indexHtml = File('web/index.html').readAsStringSync();
    final robotsTxt = File('web/robots.txt').readAsStringSync();

    expect(indexHtml, contains('<html lang="ko">'));
    expect(indexHtml, contains('id="loading-shell"'));
    expect(indexHtml, contains('role="status"'));
    expect(indexHtml, contains('aria-live="polite"'));
    expect(indexHtml, contains('flutter-first-frame'));
    expect(indexHtml, contains('loadingShell.remove()'));
    expect(indexHtml, isNot(contains('name="viewport"')));
    expect(indexHtml, contains('<noscript>'));
    expect(indexHtml, contains('JavaScript를 켜야 합니다'));
    expect(indexHtml, contains('/privacy.html'));
    expect(indexHtml, contains('prefers-reduced-motion'));
    expect(indexHtml, contains('name="application-name" content="MasilPet"'));
    expect(indexHtml, contains('property="og:site_name" content="MasilPet"'));
    expect(indexHtml, contains('property="og:locale" content="ko_KR"'));
    expect(indexHtml, contains('property="og:image"'));
    expect(indexHtml, contains('/screenshots/onboarding-wide.png'));
    expect(
      indexHtml,
      contains('name="twitter:card" content="summary_large_image"'),
    );
    expect(indexHtml, contains('name="twitter:image"'));
    expect(robotsTxt, contains('User-agent: *'));
    expect(robotsTxt, contains('Allow: /'));
  });

  test('Firestore rules keep user progress server-owned', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /users/{uid}'));
    expect(rules, contains('allow read: if isOwner(uid);'));
    expect(rules, contains('allow create, update, delete: if false;'));
    expect(rules, contains('match /pets/{petId}'));
    expect(rules, contains('match /eggs/{eggId}'));
    expect(rules, contains('match /checkins/{checkinId}'));
    expect(rules, isNot(contains('allow read, write: if isOwner(uid);')));
    expect(rules, isNot(contains('allow write: if isOwner(uid);')));
  });

  test('users can reset local and server-owned progress', () {
    final functionsSource = File('functions/src/index.ts').readAsStringSync();
    final backendSource =
        File('lib/src/data/masilpet_backend.dart').readAsStringSync();
    final localRepositorySource =
        File('lib/src/data/local_progress_repository.dart').readAsStringSync();
    final stateSource = File('lib/src/state.dart').readAsStringSync();
    final profileSource =
        File('lib/src/screens/profile_screen.dart').readAsStringSync();
    final privacyDoc = File('docs/PRIVACY_POLICY.md').readAsStringSync();
    final privacyHtml = File('web/privacy.html').readAsStringSync();

    expect(
        functionsSource, contains('export const deleteUserProgress = onCall'));
    expect(functionsSource, contains('requireAuth(request.auth?.uid)'));
    expect(functionsSource, contains('db.recursiveDelete(userRef)'));
    expect(backendSource, contains('Future<void> deleteUserProgress()'));
    expect(backendSource, contains("_call('deleteUserProgress')"));
    expect(localRepositorySource, contains('Future<void> clearProgress()'));
    expect(localRepositorySource, contains('prefs.remove(_storageKey)'));
    expect(stateSource, contains('Future<void> resetProgress()'));
    expect(stateSource, contains('await _backend.deleteUserProgress()'));
    expect(stateSource, contains('await repository?.clearProgress()'));
    expect(profileSource, contains('진행도 관리'));
    expect(profileSource, contains('진행도 초기화'));
    expect(profileSource, contains('showDialog<bool>'));
    expect(profileSource, contains('controller.resetProgress()'));
    expect(privacyDoc, contains('내 정보'));
    expect(privacyDoc, contains('진행도 초기화'));
    expect(privacyHtml, contains('내 정보'));
    expect(privacyHtml, contains('진행도 초기화'));
  });

  test('public app does not expose operator-only data sync', () {
    final functionsSource = File('functions/src/index.ts').readAsStringSync();
    final backendSource =
        File('lib/src/data/masilpet_backend.dart').readAsStringSync();
    final profileSource =
        File('lib/src/screens/profile_screen.dart').readAsStringSync();

    expect(functionsSource, contains('function requireOperator'));
    expect(
      functionsSource,
      contains('export const seedStarterRegionData = onCall'),
    );
    expect(functionsSource, contains('export const syncKoreaPois = onCall'));
    expect(
      functionsSource,
      contains('requireOperator(request.auth?.uid, request.auth?.token);'),
    );
    expect(
      backendSource,
      isNot(contains("httpsCallable('seedStarterRegionData')")),
    );
    expect(profileSource, isNot(contains('지역 데이터 동기화')));
  });

  test('manual step test controls are not exposed in production UI', () {
    final functionsSource = File('functions/src/index.ts').readAsStringSync();
    final profileSource =
        File('lib/src/screens/profile_screen.dart').readAsStringSync();
    final houseSource =
        File('lib/src/screens/house_screen.dart').readAsStringSync();
    final mapSource =
        File('lib/src/screens/map_screen.dart').readAsStringSync();
    final stateSource = File('lib/src/state.dart').readAsStringSync();

    expect(profileSource, isNot(contains('1000걸음 반영')));
    expect(houseSource, isNot(contains('500걸음 반영')));
    expect(profileSource, isNot(contains('해운대 기준 위치로 이동')));
    expect(profileSource, contains('전국 기본 지도 보기'));
    expect(profileSource, contains('기본 위치로 체험'));
    expect(profileSource, contains('final onlineActionEnabled'));
    expect(profileSource, contains('state.firebaseReady && !state.isBusy'));
    expect(
      profileSource,
      contains('? controller.ensureRemoteUserBootstrap'),
    );
    expect(
      profileSource,
      contains('? () => controller.refreshRemoteProgress()'),
    );
    expect(profileSource,
        contains('state.isBusy ? null : controller.useStarterKoreaLocation'));
    expect(mapSource, contains('현재 위치 확인'));
    expect(mapSource, contains('전국 기본 지도 보기'));
    expect(mapSource, contains('controller.useDeviceLocation'));
    expect(mapSource, contains('controller.useStarterKoreaLocation'));
    expect(mapSource, contains('미확인'));
    expect(mapSource, contains('key: ValueKey'));
    expect(
        mapSource, contains('state.currentLocation.latitude.toStringAsFixed'));
    expect(stateSource, contains('locationVerificationTtl'));
    expect(stateSource, contains('hasFreshVerifiedLocation'));
    expect(stateSource, contains('if (!state.hasFreshVerifiedLocation)'));
    expect(functionsSource, contains('const maxStepDeltaPerCall = 3000;'));
    expect(functionsSource, contains('const maxDailyStepDelta = 12000;'));
    expect(functionsSource, contains('const maxDailyCheckIns = 20;'));
    expect(functionsSource, contains('startOfKoreanDay'));
    expect(functionsSource, contains('koreanDayKey'));
  });

  test('callable check-ins are idempotent and daily limited', () {
    final functionsSource = File('functions/src/index.ts').readAsStringSync();

    expect(functionsSource, contains('function checkInDocumentId'));
    expect(
      functionsSource,
      contains('checkinsRef.doc(checkInDocumentId(poiId, dayKey))'),
    );
    expect(functionsSource, contains('transaction.get(checkinRef)'));
    expect(functionsSource, contains('already-exists'));
    expect(functionsSource, contains('Daily check-in limit reached.'));
    expect(
      functionsSource,
      isNot(contains(".where('poiId', '==', poiId)")),
    );
  });

  test('remote check-ins return and consume server-authored progress', () {
    final functionsSource = File('functions/src/index.ts').readAsStringSync();
    final backendSource =
        File('lib/src/data/masilpet_backend.dart').readAsStringSync();
    final stateSource = File('lib/src/state.dart').readAsStringSync();

    expect(functionsSource, contains('const eggProgress = eggProgressFor'));
    expect(functionsSource, contains('rewardApplied: true'));
    expect(functionsSource, contains('reward,'));
    expect(functionsSource, contains('eggProgress,'));
    expect(functionsSource, contains('updatedPet,'));
    expect(backendSource, contains('final int? eggProgress;'));
    expect(backendSource, contains('final RemotePetUpdate? updatedPet;'));
    expect(stateSource, contains('result.eggProgress ??'));
    expect(stateSource, contains('result.updatedPet'));
    expect(stateSource, contains('await refreshRemoteProgress(silent: true);'));
  });

  test('remote pet interactions return an updated pet identity', () {
    final functionsSource = File('functions/src/index.ts').readAsStringSync();
    final backendSource =
        File('lib/src/data/masilpet_backend.dart').readAsStringSync();

    expect(functionsSource,
        contains('updatedPet = {id: petId, stats, level, stage};'));
    expect(backendSource, contains('final String? id;'));
  });

  test('operator dialogue seed covers every pet and visit category', () {
    final functionsSource = File('functions/src/index.ts').readAsStringSync();
    const templateIds = [
      'wave-naru',
      'harbor-maru',
      'film-bori',
      'spark-yuri',
      'alley-raon',
      'spring-dami',
      'story-goun',
    ];
    const triggers = [
      'default',
      'nature',
      'food',
      'festival',
      'culture',
      'history',
      'shopping',
      'other',
    ];

    for (final templateId in templateIds) {
      for (final trigger in triggers) {
        expect(functionsSource, contains("id: '$templateId-$trigger'"));
      }
    }
    expect(functionsSource, contains('dialogueCount: dialogueSeed.length'));
  });

  test('PWA manifest is contest-ready and uses production branding', () {
    final manifest = _readJson('web/manifest.json');

    expect(manifest['name'], contains('MasilPet'));
    expect(manifest['short_name'], 'MasilPet');
    expect(manifest['id'], '/');
    expect(manifest['lang'], 'ko-KR');
    expect(manifest['dir'], 'ltr');
    expect(manifest['start_url'], '/');
    expect(manifest['scope'], '/');
    expect(manifest['display'], 'standalone');
    expect(manifest['orientation'], 'any');
    expect(manifest['description'], contains('대한민국'));
    expect(manifest['description'], isNot(contains('demo')));

    final screenshots =
        (manifest['screenshots'] as List<dynamic>).cast<Map<String, dynamic>>();
    final screenshotsByFormFactor = {
      for (final screenshot in screenshots)
        screenshot['form_factor'] as String: screenshot,
    };
    expect(screenshotsByFormFactor.keys, containsAll(['wide', 'narrow']));
    final wideScreenshot = screenshotsByFormFactor['wide']!;
    final narrowScreenshot = screenshotsByFormFactor['narrow']!;
    expect(wideScreenshot['src'], 'screenshots/onboarding-wide.png');
    expect(wideScreenshot['sizes'], '1280x720');
    expect(narrowScreenshot['src'], 'screenshots/onboarding-mobile.png');
    expect(narrowScreenshot['sizes'], '390x844');
    for (final screenshot in screenshots) {
      expect(screenshot['type'], 'image/png');
      expect(screenshot['label'], contains('MasilPet'));
      final path = 'web/${screenshot['src']}';
      expect(File(path).existsSync(), isTrue);
      expect(_pngDimensions(path), screenshot['sizes']);
    }

    final iconEntries =
        (manifest['icons'] as List<dynamic>).cast<Map<String, dynamic>>();
    final icons = iconEntries.map((icon) => icon['src']).toSet();

    expect(icons, contains('icons/Icon-192.png'));
    expect(icons, contains('icons/Icon-512.png'));
    expect(icons, contains('icons/Icon-maskable-192.png'));
    expect(icons, contains('icons/Icon-maskable-512.png'));
    expect(iconEntries.any((icon) => icon['purpose'] == 'maskable'), isTrue);

    for (final icon in iconEntries) {
      expect(File('web/${icon['src']}').existsSync(), isTrue);
    }

    final shortcuts =
        (manifest['shortcuts'] as List<dynamic>).cast<Map<String, dynamic>>();
    final shortcutUrls =
        shortcuts.map((shortcut) => shortcut['url'] as String).toSet();
    expect(shortcutUrls, contains('/#/home'));
    expect(shortcutUrls, contains('/privacy.html'));
    for (final shortcut in shortcuts) {
      expect(shortcut['name'], isNotEmpty);
      expect(shortcut['short_name'], isNotEmpty);
      expect(shortcut['description'], isNotEmpty);
      final shortcutIcons =
          (shortcut['icons'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(shortcutIcons.single['src'], 'icons/Icon-192.png');
    }
  });

  test('privacy policy is publishable and linked from the app', () {
    final indexHtml = File('web/index.html').readAsStringSync();
    final privacyHtml = File('web/privacy.html').readAsStringSync();
    final privacyDoc = File('docs/PRIVACY_POLICY.md').readAsStringSync();
    final mapSource =
        File('lib/src/screens/map_screen.dart').readAsStringSync();
    final profileSource =
        File('lib/src/screens/profile_screen.dart').readAsStringSync();
    final privacyNavigationSource =
        File('lib/src/services/privacy_navigation_web.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(indexHtml,
        contains('<link rel="privacy-policy" href="/privacy.html">'));
    expect(privacyHtml, contains('<html lang="ko">'));
    expect(privacyHtml, contains('MasilPet 개인정보 처리방침'));
    expect(privacyHtml, contains('Firebase 익명 인증 식별자'));
    expect(privacyHtml, contains('최근 15분 안에 확인한 위치'));
    expect(privacyHtml, contains('TourAPI 키는 앱에 포함하지 않습니다'));
    expect(privacyDoc, contains('MasilPet 개인정보 처리방침'));
    expect(privacyDoc, contains('Cloud Functions'));
    expect(mapSource, contains('© OpenStreetMap contributors'));
    expect(mapSource, contains('https://www.openstreetmap.org/copyright'));
    expect(mapSource, contains('LinkTarget.blank'));
    expect(mapSource, contains('전국 기본 장소'));
    expect(mapSource, contains('TourAPI ID'));
    expect(profileSource, contains('개인정보 처리방침: /privacy.html'));
    expect(profileSource, contains('개인정보 처리방침 열기'));
    expect(profileSource, contains('데이터·지도 출처'));
    expect(profileSource, contains('TourAPI 지역 장소'));
    expect(profileSource, contains('OpenStreetMap 지도'));
    expect(profileSource, contains('지도 타일 설정'));
    expect(profileSource, contains('mapTileBuildConfig.providerLabel'));
    expect(profileSource, contains('mapTileBuildConfig.userAgentLabel'));
    expect(profileSource, contains('Firebase Functions 검증'));
    expect(profileSource, contains('openPrivacyPolicyPage()'));
    expect(
        privacyNavigationSource, contains("location.assign('/privacy.html')"));
    expect(pubspec, contains('url_launcher:'));
  });

  test('Firestore indexes cover current remote progress queries', () {
    final indexes = _readJson('firestore.indexes.json');
    final indexEntries =
        (indexes['indexes'] as List<dynamic>).cast<Map<String, dynamic>>();

    expect(
      indexEntries,
      contains(
        allOf(
          containsPair('collectionGroup', 'checkins'),
          predicate<Map<String, dynamic>>(
            (index) {
              final fields = (index['fields'] as List<dynamic>)
                  .cast<Map<String, dynamic>>();
              return fields.any(
                    (field) =>
                        field['fieldPath'] == 'poiId' &&
                        field['order'] == 'ASCENDING',
                  ) &&
                  fields.any(
                    (field) =>
                        field['fieldPath'] == 'createdAt' &&
                        field['order'] == 'DESCENDING',
                  );
            },
            'checkins index includes poiId and createdAt',
          ),
        ),
      ),
    );
  });

  test('runtime exposes Firebase Web configuration diagnostics', () {
    final firebaseOptions =
        File('lib/firebase_options.dart').readAsStringSync();
    final buildInfoSource =
        File('lib/src/app_build_info.dart').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final stateSource = File('lib/src/state.dart').readAsStringSync();
    final profileSource =
        File('lib/src/screens/profile_screen.dart').readAsStringSync();
    final onboardingSource =
        File('lib/src/screens/onboarding_screen.dart').readAsStringSync();
    final checklist = File('docs/RELEASE_CHECKLIST.md').readAsStringSync();

    expect(firebaseOptions, contains('hasRequiredWebConfiguration'));
    expect(firebaseOptions, contains('FIREBASE_WEB_API_KEY'));
    expect(firebaseOptions, contains('FIREBASE_WEB_APP_ID'));
    expect(firebaseOptions, contains('FIREBASE_MESSAGING_SENDER_ID'));
    expect(buildInfoSource, contains('MASILPET_APP_VERSION'));
    expect(buildInfoSource, contains('MASILPET_BUILD_CHANNEL'));
    expect(buildInfoSource, contains('MASILPET_BUILD_TIME_UTC'));
    expect(buildInfoSource, contains('MASILPET_MAP_TILE_URL_TEMPLATE'));
    expect(buildInfoSource, contains('MASILPET_MAP_TILE_USER_AGENT'));
    expect(buildInfoSource, contains('mapTileBuildConfig'));
    expect(buildInfoSource, contains('defaultOpenStreetMapUrlTemplate'));
    expect(buildInfoSource, contains('providerLabel'));
    expect(buildInfoSource, contains('userAgentLabel'));
    expect(mainSource, contains('missingWebConfiguration'));
    expect(mainSource, contains('initializationFailed'));
    expect(mainSource, contains('firebaseStartupIssueProvider'));
    expect(stateSource, contains('FirebaseStartupIssue'));
    expect(stateSource, contains('기기 내 진행 (설정 필요)'));
    expect(stateSource, contains('기기 내 진행 (연결 실패)'));
    expect(stateSource, contains('firebaseConnectionLabel'));
    expect(profileSource, contains('firebaseConnectionLabel'));
    expect(profileSource, contains('appBuildInfo'));
    expect(profileSource, contains('앱 버전'));
    expect(profileSource, contains('빌드 채널'));
    expect(profileSource, contains('빌드 시각'));
    expect(onboardingSource, contains('firebaseStartupIssue.fallbackMessage'));
    expect(checklist, contains('기기 내 진행 (설정 필요)'));
    expect(checklist, contains('MASILPET_BUILD_CHANNEL'));
    expect(checklist, contains('MASILPET_MAP_TILE_URL_TEMPLATE'));
  });

  test('release preflight script covers local and Firebase gates', () {
    final script = File('tools/release_preflight.ps1').readAsStringSync();
    final hostingSmokeScript =
        File('tools/hosting_smoke.ps1').readAsStringSync();
    final localJudgingSmokeScript =
        File('tools/local_judging_smoke.ps1').readAsStringSync();
    final releaseEvidenceScript =
        File('tools/release_evidence.ps1').readAsStringSync();
    final readme = File('README.md').readAsStringSync();
    final checklist = File('docs/RELEASE_CHECKLIST.md').readAsStringSync();
    final runbook = File('docs/OPERATIONS_RUNBOOK.md').readAsStringSync();

    expect(script, contains('dart format --set-exit-if-changed lib test'));
    expect(script, contains('flutter analyze'));
    expect(script, contains('flutter test'));
    expect(script, contains('npm --prefix functions ci'));
    expect(script, contains('npm --prefix functions audit --audit-level=high'));
    expect(script, contains('flutter build web --release --no-wasm-dry-run'));
    expect(script, contains('firebase projects:list --json'));
    expect(script, contains('functions:secrets:access TOUR_API_KEY'));
    expect(script, contains('FIREBASE_WEB_API_KEY'));
    expect(script, contains('FIREBASE_WEB_APP_ID'));
    expect(script, contains('FIREBASE_MESSAGING_SENDER_ID'));
    expect(script, contains('Get-PubspecVersion'));
    expect(script, contains('MASILPET_APP_VERSION'));
    expect(script, contains('MASILPET_BUILD_CHANNEL'));
    expect(script, contains('MASILPET_BUILD_TIME_UTC'));
    expect(script, contains('MASILPET_MAP_TILE_URL_TEMPLATE'));
    expect(script, contains('MASILPET_MAP_TILE_USER_AGENT'));
    expect(script, contains('@AppDartDefineArgs'));
    expect(script, contains('@FirebaseDartDefineArgs'));
    expect(script, contains('build/web/privacy.html'));
    expect(script, contains('build/web/robots.txt'));
    expect(script, contains('build/web/icons/Icon-maskable-192.png'));
    expect(script, contains('build/web/icons/Icon-maskable-512.png'));
    expect(script, contains('build/web/screenshots/onboarding-wide.png'));
    expect(script, contains('build/web/screenshots/onboarding-mobile.png'));
    expect(checklist, contains('Firebase Web 빌드 설정'));
    expect(checklist, contains('FIREBASE_WEB_API_KEY'));
    expect(checklist, contains('앱 버전'));
    expect(checklist, contains('빌드 채널'));
    expect(checklist, contains('빌드 시각'));
    expect(checklist, contains('tools/release_preflight.ps1'));
    expect(checklist, contains('tools/local_judging_smoke.ps1'));
    expect(checklist, contains('tools/hosting_smoke.ps1'));
    expect(checklist, contains('tools/release_evidence.ps1'));
    expect(checklist, contains('-AllowDraftEvidence'));
    expect(
        readme,
        contains(
            'tools/release_evidence.ps1 -AllowDirtyWorktree -AllowDraftEvidence'));
    expect(readme, contains('tools/local_judging_smoke.ps1'));
    expect(runbook, contains('tools/release_preflight.ps1'));
    expect(runbook, contains('tools/local_judging_smoke.ps1'));
    expect(runbook, contains('tools/hosting_smoke.ps1'));
    expect(runbook, contains('tools/release_evidence.ps1'));
    expect(runbook, contains('MASILPET_BUILD_CHANNEL'));
    expect(runbook, contains('MASILPET_MAP_TILE_URL_TEMPLATE'));
    expect(runbook, contains('UTC 빌드 시각'));
    expect(runbook, contains('-AllowDraftEvidence'));

    expect(hostingSmokeScript, contains('param('));
    expect(hostingSmokeScript, contains('[string]\$HostingUrl'));
    expect(hostingSmokeScript, contains('Invoke-WebRequest'));
    expect(hostingSmokeScript, contains('loading-shell'));
    expect(hostingSmokeScript, contains('flutter-first-frame'));
    expect(hostingSmokeScript, contains('<noscript>'));
    expect(hostingSmokeScript, contains('privacy.html'));
    expect(hostingSmokeScript, contains('robots.txt'));
    expect(hostingSmokeScript, contains('User-agent: *'));
    expect(hostingSmokeScript, contains('TourAPI'));
    expect(hostingSmokeScript, contains('Firebase'));
    expect(hostingSmokeScript, contains('manifest.json'));
    expect(hostingSmokeScript, contains('Assert-StaticPngAsset'));
    expect(hostingSmokeScript, contains('Assert-ManifestScreenshot'));
    expect(hostingSmokeScript, contains('screenshots/onboarding-wide.png'));
    expect(hostingSmokeScript, contains('screenshots/onboarding-mobile.png'));
    expect(hostingSmokeScript, contains('Icon-maskable-192.png'));
    expect(hostingSmokeScript, contains('Icon-maskable-512.png'));
    expect(hostingSmokeScript, contains('favicon.png'));
    expect(
      hostingSmokeScript,
      contains('public, max-age=31536000, immutable'),
    );
    expect(hostingSmokeScript, contains('form_factor'));
    expect(hostingSmokeScript, contains('X-Content-Type-Options'));
    expect(hostingSmokeScript, contains('Referrer-Policy'));
    expect(hostingSmokeScript, contains('X-Frame-Options'));
    expect(hostingSmokeScript, contains('Permissions-Policy'));
    expect(hostingSmokeScript, contains('geolocation=(self)'));

    expect(localJudgingSmokeScript, contains('build/web/index.html'));
    expect(localJudgingSmokeScript, contains('--headless=new'));
    expect(localJudgingSmokeScript, contains('remote-debugging-port'));
    expect(localJudgingSmokeScript, contains('local-judging-after-fallback'));
    expect(localJudgingSmokeScript, contains('local-judging-after-checkin'));
    expect(localJudgingSmokeScript, contains('local-judging-after-talk'));
    expect(
        localJudgingSmokeScript, contains('local-judging-smoke-result.json'));
    expect(localJudgingSmokeScript, contains('checkIns'));
    expect(localJudgingSmokeScript, contains('dialogueCountToday'));
    expect(localJudgingSmokeScript, contains('lastVisitedCategory'));
    expect(
        localJudgingSmokeScript, contains('Local judging smoke check passed'));

    expect(releaseEvidenceScript, contains('Release evidence written'));
    expect(releaseEvidenceScript, contains('build/release-evidence.md'));
    expect(releaseEvidenceScript, contains('Overall status: \$OverallStatus'));
    expect(releaseEvidenceScript, contains('[switch]\$AllowDraftEvidence'));
    expect(releaseEvidenceScript, contains('required for submission evidence'));
    expect(releaseEvidenceScript, contains('build/web/index.html'));
    expect(releaseEvidenceScript, contains('build/web/robots.txt'));
    expect(releaseEvidenceScript, contains('Robots file'));
    expect(releaseEvidenceScript, contains('PWA manifest id'));
    expect(releaseEvidenceScript, contains('PWA screenshots'));
    expect(releaseEvidenceScript,
        contains('build/web/icons/Icon-maskable-192.png'));
    expect(releaseEvidenceScript,
        contains('build/web/icons/Icon-maskable-512.png'));
    expect(releaseEvidenceScript,
        contains('build/web/screenshots/onboarding-wide.png'));
    expect(releaseEvidenceScript,
        contains('build/web/screenshots/onboarding-mobile.png'));
    expect(releaseEvidenceScript, contains('Web preview metadata'));
    expect(releaseEvidenceScript, contains('summary_large_image'));
    expect(releaseEvidenceScript, contains('Security headers'));
    expect(releaseEvidenceScript, contains('Immutable static media cache'));
    expect(releaseEvidenceScript, contains('/screenshots/**'));
    expect(releaseEvidenceScript, contains('/icons/**'));
    expect(releaseEvidenceScript, contains('Check-in reward evidence fields'));
    expect(releaseEvidenceScript,
        contains('Compiled Functions reward evidence fields'));
    expect(releaseEvidenceScript, contains('functions/lib/index.js'));
    expect(releaseEvidenceScript, contains('Client reward snapshot model'));
    expect(releaseEvidenceScript, contains('Profile visit reward breakdown'));
    expect(releaseEvidenceScript, contains('Map tile provider configuration'));
    expect(
        releaseEvidenceScript,
        contains(
            'recent visit reward breakdown from the stored check-in record'));
    expect(releaseEvidenceScript, contains('tools/local_judging_smoke.ps1'));
    expect(
      releaseEvidenceScript,
      contains('build/verification/local-judging-smoke-result.json'),
    );
  });

  test('CI runs the same release preflight gate as local release checks', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();

    expect(workflow, contains('release-preflight'));
    expect(workflow, contains('subosito/flutter-action@v2'));
    expect(workflow, contains('actions/setup-node@v4'));
    expect(workflow, contains('node-version: 20'));
    expect(workflow,
        contains('cache-dependency-path: functions/package-lock.json'));
    expect(workflow, contains('shell: pwsh'));
    expect(workflow, contains('./tools/release_preflight.ps1 -SkipFirebase'));
    expect(workflow,
        isNot(contains('flutter build web --release --no-wasm-dry-run')));
    expect(workflow, isNot(contains('npm run build')));
    expect(workflow, isNot(contains('npm audit --audit-level=high')));
  });

  test('operator operations are scripted and secret files are ignored', () {
    final setOperatorScript =
        File('tools/set_operator_claim.ps1').readAsStringSync();
    final callOperatorScript =
        File('tools/run_operator_callable.ps1').readAsStringSync();
    final gitignore = File('.gitignore').readAsStringSync();
    final checklist = File('docs/RELEASE_CHECKLIST.md').readAsStringSync();
    final runbook = File('docs/OPERATIONS_RUNBOOK.md').readAsStringSync();

    expect(setOperatorScript, contains('setCustomUserClaims'));
    expect(setOperatorScript, contains('GOOGLE_APPLICATION_CREDENTIALS'));
    expect(callOperatorScript, contains('createCustomToken'));
    expect(callOperatorScript, contains('signInWithCustomToken'));
    expect(callOperatorScript, contains('seedStarterRegionData'));
    expect(callOperatorScript, contains('syncKoreaPois'));
    expect(callOperatorScript, contains('FIREBASE_WEB_API_KEY'));
    expect(gitignore, contains('*-firebase-adminsdk-*.json'));
    expect(gitignore, contains('service-account*.json'));
    expect(checklist, contains('tools/set_operator_claim.ps1'));
    expect(checklist, contains('tools/run_operator_callable.ps1'));
    expect(runbook, contains('tools/set_operator_claim.ps1'));
    expect(runbook, contains('tools/run_operator_callable.ps1'));
  });

  test('submission package is ready for contest handoff', () {
    final readme = File('README.md').readAsStringSync();
    final checklist = File('docs/RELEASE_CHECKLIST.md').readAsStringSync();
    final submission = File('docs/SUBMISSION_PACKAGE.md').readAsStringSync();

    expect(readme, contains('docs/SUBMISSION_PACKAGE.md'));
    expect(readme, contains('web/screenshots/onboarding-wide.png'));
    expect(readme, contains('web/screenshots/onboarding-mobile.png'));
    expect(checklist, contains('SUBMISSION_PACKAGE.md'));
    expect(submission, contains('앱 URL'));
    expect(submission, contains('개인정보 처리방침 URL'));
    expect(submission, contains('핵심 기능 3줄 요약'));
    expect(submission, contains('개인정보 처리 요약'));
    expect(submission, contains('사용 기술'));
    expect(submission, contains('시연 흐름'));
    expect(submission, contains('빠른 심사 체험 경로'));
    expect(submission, contains('기본 위치로 체험'));
    expect(submission, contains('마실펫과 대화하기'));
    expect(submission, contains('제출 전 증빙'));
    expect(submission, contains('tools/local_judging_smoke.ps1'));
    expect(submission, contains('local-judging-smoke-result.json'));
    expect(submission, contains('실제 적용된 체크인 보상 상세 표시'));
    expect(checklist, contains('기본 위치로 체험'));
    expect(checklist, contains('지금 체크인 가능'));
    expect(checklist, contains('마실펫과 대화하기'));
    expect(submission, contains('운영 전제'));
    expect(submission, contains('앱 버전'));
    expect(submission, contains('빌드 채널'));
    expect(submission, contains('빌드 시각'));
    expect(submission, contains('지도 타일 설정'));
    expect(submission, contains('장소 데이터 출처'));
    expect(submission, contains('Flutter Web'));
    expect(submission, contains('Firebase Auth'));
    expect(submission, contains('TourAPI'));
    expect(submission, contains('OpenStreetMap'));
    expect(submission, contains('TOUR_API_KEY'));
    expect(submission, contains('operator: true'));
  });

  test('user action callables can recover missing starter progress', () {
    final functionsSource = File('functions/src/index.ts').readAsStringSync();
    final checklist = File('docs/RELEASE_CHECKLIST.md').readAsStringSync();
    final runbook = File('docs/OPERATIONS_RUNBOOK.md').readAsStringSync();

    expect(functionsSource, contains('function setStarterUser'));
    expect(functionsSource, contains('function starterPetRuntimeDoc'));
    expect(functionsSource, contains('function starterEggRuntimeDoc'));
    expect(functionsSource, contains('const starterPetId'));
    expect(functionsSource, contains('const starterEggId'));
    expect(functionsSource, contains('needsStarterBootstrap'));
    expect(
        functionsSource, contains('setStarterUser(transaction, userRef, now)'));
    expect(
      functionsSource,
      contains(
          'setStarterUser(transaction, userRef, FieldValue.serverTimestamp())'),
    );
    expect(checklist, contains('스타터 사용자 상태를 서버에서 보정'));
    expect(runbook, contains('스타터 사용자 상태를 같은 트랜잭션 안에서 보정'));
  });
}
