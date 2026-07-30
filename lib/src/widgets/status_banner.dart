import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state.dart';
import '../theme.dart';
import 'paper_kit.dart';

/// The margin note that reports what the app is doing — a monospaced tag and
/// one plain sentence, never an alert box.
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final message = state.statusMessage;
    final displayMessage = _friendlyStatusMessage(message);
    final tone = _statusTone(
      message: message,
      isBusy: state.isBusy,
      firebaseReady: state.firebaseReady,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: displayMessage,
      child: ExcludeSemantics(
        child: DashedBox(
          color: tone.rule,
          fill: MasilPetPalette.subtle,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  tone.label,
                  style: MasilPetType.eyebrow.copyWith(color: tone.ink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayMessage,
                  style: MasilPetType.bodySmall.copyWith(
                    fontSize: 13.5,
                    height: 1.5,
                    color: MasilPetPalette.inkSoft,
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
      message.contains('Firebase 앱 설정값') ||
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

class _StatusTone {
  const _StatusTone({
    required this.label,
    required this.ink,
    required this.rule,
  });

  final String label;
  final Color ink;
  final Color rule;

  static const progress = _StatusTone(
    label: '동기화 중',
    ink: MasilPetPalette.forest,
    rule: MasilPetPalette.forestPale,
  );
  static const success = _StatusTone(
    label: '완료',
    ink: MasilPetPalette.forest,
    rule: MasilPetPalette.forestPale,
  );
  static const warning = _StatusTone(
    label: '확인 필요',
    ink: MasilPetPalette.statSatiety,
    rule: MasilPetPalette.sunDeep,
  );
  static const error = _StatusTone(
    label: '실패',
    ink: MasilPetPalette.stamp,
    rule: MasilPetPalette.stampPale,
  );
  static const online = _StatusTone(
    label: '연결됨',
    ink: MasilPetPalette.forest,
    rule: MasilPetPalette.forestPale,
  );
  static const offline = _StatusTone(
    label: '이 기기에 저장',
    ink: MasilPetPalette.mutedWarm,
    rule: MasilPetPalette.outline,
  );
}

_StatusTone _statusTone({
  required String message,
  required bool isBusy,
  required bool firebaseReady,
}) {
  if (isBusy) {
    return _StatusTone.progress;
  }

  if (_containsAny(message, const [
    '실패',
    '못했어요',
    '거부',
    '꺼져',
    '허용해야',
    '만족하지 못했어요',
    '가져오지 못했어요',
  ])) {
    return _StatusTone.error;
  }

  if (message.contains('기기 내 진행으로 시작')) {
    return _StatusTone.offline;
  }

  if (_containsAny(message, const [
    '완료',
    '반영했어요',
    '준비됐어요',
    '불러왔어요',
    '바꿨어요',
    '초기화했어요',
    '시작해요',
  ])) {
    return _StatusTone.success;
  }

  if (_containsAny(message, const [
    '다시 확인',
    '150m 안',
    '이미',
    '모두 썼어요',
    '필요해요',
    '아직',
    '잠시 후',
    '연결 후',
  ])) {
    return _StatusTone.warning;
  }

  return firebaseReady ? _StatusTone.online : _StatusTone.offline;
}

bool _containsAny(String message, List<String> needles) {
  return needles.any(message.contains);
}
