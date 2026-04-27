import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state.dart';
import 'theme.dart';

class MasilPetApp extends ConsumerWidget {
  const MasilPetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(
      masilPetControllerProvider.select((state) => state.onboardingComplete),
    );

    final router = GoRouter(
      initialLocation: onboardingComplete ? '/home' : '/onboarding',
      redirect: (context, state) {
        final onOnboarding = state.uri.path == '/onboarding';
        if (!onboardingComplete && !onOnboarding) {
          return '/onboarding';
        }
        if (onboardingComplete && onOnboarding) {
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeShell(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'MasilPet',
      debugShowCheckedModeBanner: false,
      theme: buildMasilPetTheme(),
      routerConfig: router,
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
