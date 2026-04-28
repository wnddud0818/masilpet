import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../widgets/pet_play_field.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/status_banner.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final nearby = state.nearbyPois;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('부산 탐험'),
          floating: true,
          actions: [
            IconButton(
              tooltip: '현재 위치 사용',
              onPressed: state.isBusy ? null : controller.useDeviceLocation,
              icon: const Icon(Icons.my_location),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: ResponsiveSliverList(
            children: [
              const StatusBanner(),
              const SizedBox(height: 12),
              PetPlayField(
                templates: state.templates,
                pets: state.pets,
                eggs: state.eggs,
                activePetId: state.activePetId,
                activity: state.fieldActivity,
                activityNonce: state.fieldActivityNonce,
                height: 220,
              ),
              const SizedBox(height: 12),
              _MapPreview(state: state),
              const SizedBox(height: 16),
              Text(
                '가까운 POI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              for (final poi in nearby) _PoiTile(poi: poi),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: [Color(0xFFECFEFF), Color(0xFFF0FDF4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                state.region.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.location_on,
                size: 54,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Kakao Maps SDK 연결 전까지 데모 POI 지도로 표시합니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoiTile extends ConsumerWidget {
  const _PoiTile({required this.poi});

  final Poi poi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final distance = state.currentLocation.distanceTo(poi.coordinates);
    final canCheckIn = distance <= checkInRadiusMeters && !state.isBusy;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    poi.category.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poi.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text('${distance.round()}m'),
              ],
            ),
            const SizedBox(height: 8),
            Text(poi.shortDescription),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    canCheckIn ? () => controller.attemptCheckIn(poi) : null,
                icon: Icon(
                    canCheckIn ? Icons.check_circle : Icons.near_me_disabled),
                label: Text(
                    distance <= checkInRadiusMeters ? '체크인' : '150m 안에서 가능'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
