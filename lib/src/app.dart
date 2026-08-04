import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets/paper_kit.dart';

class MasilPetApp extends ConsumerStatefulWidget {
  const MasilPetApp({super.key});

  @override
  ConsumerState<MasilPetApp> createState() => _MasilPetAppState();
}

class _MasilPetAppState extends ConsumerState<MasilPetApp> {
  /// build마다 라우터를 새로 만들면 네비게이션 스택이 통째로 버려지므로 한 번만
  /// 만들고, 시작 복원과 온보딩 완료는 [_routerRefresh]로 알린다.
  final _routerRefresh = ValueNotifier<int>(0);
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: _startupPath,
      refreshListenable: _routerRefresh,
      redirect: (context, routerState) {
        final target = _pathFor(ref.read(masilPetControllerProvider));
        return routerState.uri.path == target ? null : target;
      },
      routes: [
        GoRoute(
          path: _startupPath,
          builder: (context, state) => const _StartupScreen(),
        ),
        GoRoute(
          path: _onboardingPath,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: _homePath,
          builder: (context, state) => const HomeShell(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _routerRefresh.dispose();
    _router.dispose();
    super.dispose();
  }

  /// 저장해 둔 진행도를 읽기 전에는 [MasilPetState.onboardingComplete]가 아직
  /// 기본값이라, 그대로 믿으면 재방문 사용자에게 온보딩이 한 번 깜빡인다.
  static String _pathFor(MasilPetState state) {
    if (!state.startupRestored) {
      return _startupPath;
    }
    return state.onboardingComplete ? _homePath : _onboardingPath;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      masilPetControllerProvider.select(
        (state) => (state.startupRestored, state.onboardingComplete),
      ),
      (previous, next) => _routerRefresh.value++,
    );

    return MaterialApp.router(
      title: 'MasilPet',
      debugShowCheckedModeBanner: false,
      theme: buildMasilPetTheme(),
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
      ],
    );
  }
}

const _startupPath = '/';
const _onboardingPath = '/onboarding';
const _homePath = '/home';

/// 네이티브 실행 화면과 첫 페이지 사이를 잇는 정지 화면.
///
/// 저장해 둔 진행도를 읽는 짧은 순간에만 보이므로 애니메이션을 두지 않는다.
/// 여기서 무언가 움직이면 오히려 로딩이 길게 느껴진다.
class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MasilPetPalette.canvas,
      body: Center(
        child: Semantics(
          label: '마실펫을 여는 중',
          child: const BrandMark(sealSize: 44, wordmarkSize: 22),
        ),
      ),
    );
  }
}
