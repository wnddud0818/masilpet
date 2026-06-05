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
    final isActive = state.isBusy || state.firebaseReady;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color:
            isActive ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.outlineVariant,
        ),
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
                  color: isActive ? scheme.onPrimaryContainer : scheme.primary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                state.firebaseReady ? Icons.cloud_done : Icons.offline_bolt,
                size: 18,
                color: isActive ? scheme.onPrimaryContainer : scheme.primary,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isActive
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
