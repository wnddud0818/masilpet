import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state.dart';
import '../theme.dart';

class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final message = state.statusMessage;
    final displayMessage = _friendlyStatusMessage(message);
    final scheme = Theme.of(context).colorScheme;
    final presentation = _StatusBannerPresentation.resolve(
      message: message,
      isBusy: state.isBusy,
      firebaseReady: state.firebaseReady,
      scheme: scheme,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: displayMessage,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: MasilPetMotion.fast,
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: MasilPetSpacing.md,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: presentation.backgroundColor,
            borderRadius: MasilPetRadii.panelBorder,
            border: Border.all(
              color: presentation.borderColor,
              width: 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: presentation.foregroundColor.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: presentation.foregroundColor.withValues(alpha: 0.11),
                  borderRadius: MasilPetRadii.smallBorder,
                  border: Border.all(
                    color: presentation.foregroundColor.withValues(alpha: 0.15),
                  ),
                ),
                child: state.isBusy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: presentation.foregroundColor,
                        ),
                      )
                    : Icon(
                        presentation.icon,
                        size: 19,
                        color: presentation.foregroundColor,
                      ),
              ),
              const SizedBox(width: MasilPetSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    displayMessage,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: presentation.textColor,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _friendlyStatusMessage(String message) {
  if (message.contains('Firebase Web 설정값') ||
      message.contains('Firebase 연결에 실패')) {
    return '연결이 없어도 이 기기에서 돌봄과 산책을 계속할 수 있어요.';
  }
  if (message.contains('Firebase 연결 준비 완료')) {
    return '산책 기록을 안전하게 이어갈 준비가 됐어요.';
  }
  if (message.contains('계정과 진행도를 동기화')) {
    return message.contains('중')
        ? '기록을 안전하게 맞추는 중이에요.'
        : '지난 돌봄과 산책 기록을 모두 불러왔어요.';
  }
  if (message.contains('온라인 동기화에 실패')) {
    return '지금은 이 기기에 안전하게 저장하고 있어요.';
  }
  return message;
}

enum _StatusTone {
  progress,
  success,
  warning,
  error,
  online,
  offline,
}

class _StatusBannerPresentation {
  const _StatusBannerPresentation({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.textColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final Color textColor;

  static _StatusBannerPresentation resolve({
    required String message,
    required bool isBusy,
    required bool firebaseReady,
    required ColorScheme scheme,
  }) {
    final tone = _toneFor(
      message: message,
      isBusy: isBusy,
      firebaseReady: firebaseReady,
    );

    return switch (tone) {
      _StatusTone.progress => const _StatusBannerPresentation(
          icon: Icons.sync,
          backgroundColor: MasilPetPalette.mintPale,
          borderColor: MasilPetPalette.mint,
          foregroundColor: MasilPetPalette.leaf,
          textColor: MasilPetPalette.ink,
        ),
      _StatusTone.success => const _StatusBannerPresentation(
          icon: Icons.check_circle_outline,
          backgroundColor: MasilPetPalette.mintPale,
          borderColor: MasilPetPalette.mint,
          foregroundColor: MasilPetPalette.success,
          textColor: MasilPetPalette.ink,
        ),
      _StatusTone.warning => const _StatusBannerPresentation(
          icon: Icons.info_outline,
          backgroundColor: MasilPetPalette.sunPale,
          borderColor: MasilPetPalette.sun,
          foregroundColor: MasilPetPalette.warning,
          textColor: Color(0xFF654719),
        ),
      _StatusTone.error => const _StatusBannerPresentation(
          icon: Icons.error_outline,
          backgroundColor: Color(0xFFFDE7E4),
          borderColor: Color(0xFFF2B5AD),
          foregroundColor: MasilPetPalette.danger,
          textColor: Color(0xFF6D2525),
        ),
      _StatusTone.online => const _StatusBannerPresentation(
          icon: Icons.cloud_done,
          backgroundColor: MasilPetPalette.mintPale,
          borderColor: MasilPetPalette.mint,
          foregroundColor: MasilPetPalette.leaf,
          textColor: MasilPetPalette.ink,
        ),
      _StatusTone.offline => _StatusBannerPresentation(
          icon: Icons.offline_bolt,
          backgroundColor: MasilPetPalette.paper,
          borderColor: scheme.outlineVariant,
          foregroundColor: scheme.primary,
          textColor: MasilPetPalette.mutedInk,
        ),
    };
  }

  static _StatusTone _toneFor({
    required String message,
    required bool isBusy,
    required bool firebaseReady,
  }) {
    if (isBusy) {
      return _StatusTone.progress;
    }

    if (_containsAny(message, const [
      '실패',
      '못했습니다',
      '거부',
      '꺼져',
      '허용해야',
      '만족하지 못했습니다',
      '가져오지 못했습니다',
    ])) {
      return _StatusTone.error;
    }

    if (message.contains('기기 내 진행으로 시작')) {
      return _StatusTone.offline;
    }

    if (_containsAny(message, const [
      '완료',
      '반영했습니다',
      '준비되었습니다',
      '불러왔습니다',
      '변경했습니다',
      '초기화했습니다',
      '시작합니다',
    ])) {
      return _StatusTone.success;
    }

    if (_containsAny(message, const [
      '다시 확인',
      '150m 안',
      '이미',
      '모두 사용',
      '필요합니다',
      '아직',
      '잠시 후',
      '연결 후',
    ])) {
      return _StatusTone.warning;
    }

    return firebaseReady ? _StatusTone.online : _StatusTone.offline;
  }

  static bool _containsAny(String message, List<String> needles) {
    return needles.any(message.contains);
  }
}
