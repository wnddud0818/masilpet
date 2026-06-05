import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state.dart';

class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final message = state.statusMessage;
    final scheme = Theme.of(context).colorScheme;
    final presentation = _StatusBannerPresentation.resolve(
      message: message,
      isBusy: state.isBusy,
      firebaseReady: state.firebaseReady,
      scheme: scheme,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: presentation.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: presentation.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isBusy)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: presentation.foregroundColor,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                presentation.icon,
                size: 18,
                color: presentation.foregroundColor,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: presentation.textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
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
      _StatusTone.progress => _StatusBannerPresentation(
          icon: Icons.sync,
          backgroundColor: scheme.primaryContainer,
          borderColor: scheme.primary.withValues(alpha: 0.14),
          foregroundColor: scheme.onPrimaryContainer,
          textColor: scheme.onPrimaryContainer,
        ),
      _StatusTone.success => const _StatusBannerPresentation(
          icon: Icons.check_circle_outline,
          backgroundColor: Color(0xFFEAF7EF),
          borderColor: Color(0xFFCBE8D5),
          foregroundColor: Color(0xFF15803D),
          textColor: Color(0xFF14532D),
        ),
      _StatusTone.warning => const _StatusBannerPresentation(
          icon: Icons.info_outline,
          backgroundColor: Color(0xFFFFF7ED),
          borderColor: Color(0xFFFED7AA),
          foregroundColor: Color(0xFFC2410C),
          textColor: Color(0xFF7C2D12),
        ),
      _StatusTone.error => const _StatusBannerPresentation(
          icon: Icons.error_outline,
          backgroundColor: Color(0xFFFEF2F2),
          borderColor: Color(0xFFFECACA),
          foregroundColor: Color(0xFFDC2626),
          textColor: Color(0xFF7F1D1D),
        ),
      _StatusTone.online => _StatusBannerPresentation(
          icon: Icons.cloud_done,
          backgroundColor: scheme.primaryContainer,
          borderColor: scheme.primary.withValues(alpha: 0.14),
          foregroundColor: scheme.onPrimaryContainer,
          textColor: scheme.onPrimaryContainer,
        ),
      _StatusTone.offline => _StatusBannerPresentation(
          icon: Icons.offline_bolt,
          backgroundColor: scheme.surfaceContainerHighest,
          borderColor: scheme.outlineVariant,
          foregroundColor: scheme.primary,
          textColor: scheme.onSurfaceVariant,
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
