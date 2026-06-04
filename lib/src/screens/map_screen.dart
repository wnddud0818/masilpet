import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/link.dart';

import '../models.dart';
import '../services.dart';
import '../state.dart';
import '../widgets/metric_grid.dart';
import '../widgets/pet_play_field.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/section_header.dart';
import '../widgets/status_banner.dart';

final Uri _openStreetMapCopyrightUri =
    Uri.parse('https://www.openstreetmap.org/copyright');

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
              _ExplorationBriefing(
                state: state,
                onUseDeviceLocation:
                    state.isBusy ? null : controller.useDeviceLocation,
              ),
              const SizedBox(height: 12),
              _MapExplorationLayout(
                state: state,
                nearby: nearby,
                onUseDeviceLocation:
                    state.isBusy ? null : controller.useDeviceLocation,
              ),
              const SizedBox(height: 16),
              PetPlayField(
                templates: state.templates,
                pets: state.pets,
                eggs: state.eggs,
                activePetId: state.activePetId,
                activity: state.fieldActivity,
                activityNonce: state.fieldActivityNonce,
                height: 190,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapExplorationLayout extends StatelessWidget {
  const _MapExplorationLayout({
    required this.state,
    required this.nearby,
    required this.onUseDeviceLocation,
  });

  static const _wideBreakpoint = 840.0;

  final MasilPetState state;
  final List<Poi> nearby;
  final VoidCallback? onUseDeviceLocation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= _wideBreakpoint;
        final map = _LivePoiMap(
          state: state,
          height: useTwoColumns ? 420 : 260,
        );
        final poiList = _NearbyPoiList(
          nearby: nearby,
          onUseDeviceLocation: onUseDeviceLocation,
        );

        if (!useTwoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              map,
              const SizedBox(height: 16),
              poiList,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: map),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: poiList),
          ],
        );
      },
    );
  }
}

class _NearbyPoiList extends StatelessWidget {
  const _NearbyPoiList({
    required this.nearby,
    required this.onUseDeviceLocation,
  });

  final List<Poi> nearby;
  final VoidCallback? onUseDeviceLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '가까운 POI',
          detail: '${nearby.length}곳',
          icon: Icons.near_me_outlined,
        ),
        if (nearby.isEmpty)
          EmptyStateCard(
            icon: Icons.location_off_outlined,
            title: '근처 POI가 없습니다',
            body: '현재 위치를 다시 확인하면 가까운 여행지가 표시됩니다.',
            actionIcon: Icons.my_location,
            actionLabel: '현재 위치 다시 확인',
            onAction: onUseDeviceLocation,
          )
        else
          for (final poi in nearby) _PoiTile(poi: poi),
      ],
    );
  }
}

class _ExplorationBriefing extends StatelessWidget {
  const _ExplorationBriefing({
    required this.state,
    required this.onUseDeviceLocation,
  });

  final MasilPetState state;
  final VoidCallback? onUseDeviceLocation;

  @override
  Widget build(BuildContext context) {
    final nearest = state.nearestPoi;
    final nearestDistance = nearest == null || !state.hasFreshVerifiedLocation
        ? null
        : state.currentLocation.distanceTo(nearest.coordinates).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '오늘의 탐험 현황',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MetricGrid(
              items: [
                MetricGridItem(
                  label: '체크인 가능',
                  value: '${state.todayAvailableCheckInCount}곳',
                  icon: Icons.check_circle_outline,
                ),
                MetricGridItem(
                  label: '오늘 체크인',
                  value: '${state.todayCheckInCount}회',
                  icon: Icons.flag_outlined,
                ),
                MetricGridItem(
                  label: '가장 가까운 곳',
                  value: nearestDistance == null ? '-' : '${nearestDistance}m',
                  icon: Icons.near_me_outlined,
                ),
              ],
            ),
            if (nearest != null) ...[
              const SizedBox(height: 12),
              Text(
                state.hasFreshVerifiedLocation
                    ? '${nearest.title}부터 시작하면 ${nearest.category.label} 보상을 받을 수 있습니다.'
                    : '현재 위치를 확인하면 150m 체크인 판정이 활성화됩니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (!state.hasFreshVerifiedLocation) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onUseDeviceLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('현재 위치 확인'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LivePoiMap extends StatelessWidget {
  const _LivePoiMap({
    required this.state,
    required this.height,
  });

  final MasilPetState state;
  final double height;

  @override
  Widget build(BuildContext context) {
    final currentPoint = LatLng(
      state.currentLocation.latitude,
      state.currentLocation.longitude,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey(
                '${state.currentLocation.latitude.toStringAsFixed(6)},'
                '${state.currentLocation.longitude.toStringAsFixed(6)}',
              ),
              options: MapOptions(
                initialCenter: currentPoint,
                initialZoom: 12.7,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.masilpet.app',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: currentPoint,
                      radius: checkInRadiusMeters,
                      useRadiusInMeter: true,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.14),
                      borderColor: Theme.of(context).colorScheme.primary,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final poi in state.pois)
                      Marker(
                        point: LatLng(
                          poi.coordinates.latitude,
                          poi.coordinates.longitude,
                        ),
                        width: 44,
                        height: 44,
                        child: _PoiMarker(
                          poi: poi,
                          checked: state.hasCheckedInToday(poi),
                        ),
                      ),
                    Marker(
                      point: currentPoint,
                      width: 48,
                      height: 48,
                      child: const _CurrentLocationMarker(),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 12,
              top: 12,
              child: _MapBadge(
                text: '${state.region.name} POI ${state.pois.length}곳',
                icon: Icons.map_outlined,
              ),
            ),
            const Positioned(
              right: 8,
              bottom: 6,
              child: _MapAttribution(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoiMarker extends StatelessWidget {
  const _PoiMarker({
    required this.poi,
    required this.checked,
  });

  final Poi poi;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(poi.category);
    return Tooltip(
      message: poi.title,
      child: Icon(
        checked ? Icons.task_alt : Icons.location_on,
        color: color,
        size: checked ? 30 : 36,
        shadows: const [
          Shadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.navigation, color: Colors.white, size: 20),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Link(
      uri: _openStreetMapCopyrightUri,
      target: LinkTarget.blank,
      builder: (context, followLink) {
        return Tooltip(
          message: 'OpenStreetMap 저작권 보기',
          child: Material(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: followLink,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    final checked = state.hasCheckedInToday(poi);
    final inRange =
        state.hasFreshVerifiedLocation && distance <= checkInRadiusMeters;
    final needsLocation = !state.hasFreshVerifiedLocation;
    final canCheckIn = inRange && !checked && !state.isBusy;
    final canRequestLocation = needsLocation && !checked && !state.isBusy;
    final canRefreshLocation =
        !needsLocation && !inRange && !checked && !state.isBusy;
    final reward = const GrowthEngine().rewardFor(poi.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CategoryChip(
                  category: poi.category,
                  checked: checked,
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
                Text(
                  state.hasFreshVerifiedLocation
                      ? '${distance.round()}m'
                      : '미확인',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(poi.shortDescription),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RewardChip(
                  icon: Icons.auto_graph,
                  label: 'EXP +${reward.stats.exp}',
                ),
                _RewardChip(
                  icon: Icons.favorite_outline,
                  label: '친밀도 +${reward.stats.affinity}',
                ),
                _RewardChip(
                  icon: Icons.egg_alt_outlined,
                  label: '알 +${reward.eggProgress}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canCheckIn
                    ? () => controller.attemptCheckIn(poi)
                    : canRequestLocation || canRefreshLocation
                        ? controller.useDeviceLocation
                        : null,
                icon: Icon(checked
                    ? Icons.task_alt
                    : needsLocation || canRefreshLocation
                        ? Icons.my_location
                        : canCheckIn
                            ? Icons.check_circle
                            : Icons.near_me_disabled),
                label: Text(checked
                    ? '오늘 체크인 완료'
                    : needsLocation
                        ? '현재 위치 확인'
                        : canRefreshLocation
                            ? '현재 위치 다시 확인'
                            : inRange
                                ? '체크인'
                                : '150m 안에서 가능'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.checked,
  });

  final PoiCategory category;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final color = checked ? const Color(0xFF16A34A) : _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        checked ? '완료' : category.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

Color _categoryColor(PoiCategory category) {
  return switch (category) {
    PoiCategory.nature => const Color(0xFF0F766E),
    PoiCategory.food => const Color(0xFFF97316),
    PoiCategory.festival => const Color(0xFFDB2777),
    PoiCategory.culture => const Color(0xFF2563EB),
    PoiCategory.history => const Color(0xFF7C3AED),
    PoiCategory.shopping => const Color(0xFFB45309),
    PoiCategory.other => const Color(0xFF64748B),
  };
}
