import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/link.dart';

import '../app_build_info.dart';
import '../models.dart';
import '../seed_data.dart';
import '../services.dart';
import '../state.dart';
import '../widgets/metric_grid.dart';
import '../widgets/pet_play_field.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/reward_chip_row.dart';
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
          title: const Text('전국 탐험'),
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
                onUseStarterLocation:
                    state.isBusy ? null : controller.useStarterKoreaLocation,
              ),
              const SizedBox(height: 12),
              _DailyRouteCard(
                state: state,
                onUseDeviceLocation:
                    state.isBusy ? null : controller.useDeviceLocation,
                onCheckInPoi: (poi) => controller.attemptCheckIn(poi),
                onOpenPet: state.isBusy ? null : () => controller.setTab(1),
                onOpenHouse: state.isBusy ? null : () => controller.setTab(2),
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

class _NearbyPoiList extends StatefulWidget {
  const _NearbyPoiList({
    required this.nearby,
    required this.onUseDeviceLocation,
  });

  final List<Poi> nearby;
  final VoidCallback? onUseDeviceLocation;

  @override
  State<_NearbyPoiList> createState() => _NearbyPoiListState();
}

class _NearbyPoiListState extends State<_NearbyPoiList> {
  PoiCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final categories = _visiblePoiCategories(widget.nearby);
    final selectedCategory =
        categories.contains(_selectedCategory) ? _selectedCategory : null;
    final filtered = selectedCategory == null
        ? widget.nearby
        : widget.nearby
            .where((poi) => poi.category == selectedCategory)
            .toList(growable: false);
    final detail = selectedCategory == null
        ? '${widget.nearby.length}곳'
        : '${filtered.length}/${widget.nearby.length}곳';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '가까운 POI',
          detail: detail,
          icon: Icons.near_me_outlined,
        ),
        if (widget.nearby.isEmpty)
          EmptyStateCard(
            icon: Icons.location_off_outlined,
            title: '근처 POI가 없습니다',
            body: '현재 위치를 다시 확인하면 가까운 여행지가 표시됩니다.',
            actionIcon: Icons.my_location,
            actionLabel: '현재 위치 다시 확인',
            onAction: widget.onUseDeviceLocation,
          )
        else ...[
          _PoiCategoryFilterBar(
            categories: categories,
            selectedCategory: selectedCategory,
            totalCount: widget.nearby.length,
            categoryCounts: _categoryCounts(widget.nearby),
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
            },
          ),
          const SizedBox(height: 8),
          for (final poi in filtered) _PoiTile(poi: poi),
        ],
      ],
    );
  }
}

class _PoiCategoryFilterBar extends StatelessWidget {
  const _PoiCategoryFilterBar({
    required this.categories,
    required this.selectedCategory,
    required this.totalCount,
    required this.categoryCounts,
    required this.onSelected,
  });

  final List<PoiCategory> categories;
  final PoiCategory? selectedCategory;
  final int totalCount;
  final Map<PoiCategory, int> categoryCounts;
  final ValueChanged<PoiCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 2),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '카테고리 필터',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  selected: selectedCategory == null,
                  showCheckmark: true,
                  label: Text('전체 $totalCount'),
                  onSelected: (_) => onSelected(null),
                ),
                for (final category in categories)
                  FilterChip(
                    selected: selectedCategory == category,
                    showCheckmark: true,
                    avatar: Icon(
                      _categoryIcon(category),
                      size: 16,
                      color: selectedCategory == category
                          ? scheme.onSecondaryContainer
                          : _categoryColor(category),
                    ),
                    label: Text(
                      '${category.label} ${categoryCounts[category] ?? 0}',
                    ),
                    onSelected: (selected) {
                      onSelected(selected ? category : null);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Map<PoiCategory, int> _categoryCounts(List<Poi> pois) {
  final counts = <PoiCategory, int>{};
  for (final poi in pois) {
    counts.update(poi.category, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}

class _ExplorationBriefing extends StatelessWidget {
  const _ExplorationBriefing({
    required this.state,
    required this.onUseDeviceLocation,
    required this.onUseStarterLocation,
  });

  final MasilPetState state;
  final VoidCallback? onUseDeviceLocation;
  final VoidCallback? onUseStarterLocation;

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
                  label: '남은 체크인',
                  value: state.remainingDailyCheckIns == 0
                      ? '완료'
                      : '${state.remainingDailyCheckIns}회',
                  icon: Icons.event_available_outlined,
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
                _explorationBriefingText(state, nearest),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (!state.hasFreshVerifiedLocation &&
                  state.remainingDailyCheckIns > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onUseDeviceLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('현재 위치 확인'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onUseStarterLocation,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        state.firebaseReady ? '전국 기본 지도 보기' : '기본 위치로 체험',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

String _explorationBriefingText(MasilPetState state, Poi nearest) {
  if (state.remainingDailyCheckIns == 0) {
    return '오늘 체크인 한도 $dailyCheckInLimit회를 모두 사용했습니다. 내일 다시 성장 보상을 이어갈 수 있습니다.';
  }
  if (!state.hasFreshVerifiedLocation) {
    return '현재 위치를 확인하면 150m 체크인 판정이 활성화됩니다.';
  }
  return '${nearest.title}부터 시작하면 ${nearest.category.label} 보상을 받을 수 있습니다.';
}

class _DailyRouteCard extends StatelessWidget {
  const _DailyRouteCard({
    required this.state,
    required this.onUseDeviceLocation,
    required this.onCheckInPoi,
    required this.onOpenPet,
    required this.onOpenHouse,
  });

  final MasilPetState state;
  final VoidCallback? onUseDeviceLocation;
  final ValueChanged<Poi> onCheckInPoi;
  final VoidCallback? onOpenPet;
  final VoidCallback? onOpenHouse;

  @override
  Widget build(BuildContext context) {
    final recommended = state.nextRecommendedPoi;
    final routePois = state.recommendedRoutePois;
    final recommendedDistance =
        recommended == null || !state.hasFreshVerifiedLocation
            ? null
            : state.currentLocation.distanceTo(recommended.coordinates).round();
    final nextEgg = state.nextEgg;
    final eggRemainingSteps = nextEgg == null
        ? null
        : (nextEgg.requiredSteps - nextEgg.progress)
            .clamp(0, nextEgg.requiredSteps);
    final talkedToday = _hasTalkedToday(state);
    final recommendationReasons = _recommendationReasons(
      state: state,
      recommended: recommended,
    );
    final completedSteps = [
      state.hasFreshVerifiedLocation,
      state.todayCheckInCount > 0,
      talkedToday,
      nextEgg?.status == EggStatus.hatchable,
    ].where((done) => done).length;
    final action = _nextRouteAction(
      state: state,
      recommended: recommended,
      talkedToday: talkedToday,
      onUseDeviceLocation: onUseDeviceLocation,
      onCheckInPoi: onCheckInPoi,
      onOpenPet: onOpenPet,
      onOpenHouse: onOpenHouse,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.signpost_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '오늘의 산책 루트',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$completedSteps/4',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _recommendationText(state, recommended, recommendedDistance),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (recommendationReasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              _RecommendationReasonWrap(reasons: recommendationReasons),
            ],
            const SizedBox(height: 12),
            MetricGrid(
              items: [
                MetricGridItem(
                  icon: Icons.category_outlined,
                  label: '방문 카테고리',
                  value:
                      '${state.todayVisitedCategoryCount}/${PoiCategory.values.length}',
                ),
                MetricGridItem(
                  icon: Icons.place_outlined,
                  label: '남은 POI',
                  value: state.unvisitedPoiCountToday == 0
                      ? '완료'
                      : '${state.unvisitedPoiCountToday}곳',
                ),
                MetricGridItem(
                  icon: Icons.near_me_outlined,
                  label: '추천 거리',
                  value: recommendedDistance == null
                      ? '-'
                      : '${recommendedDistance}m',
                ),
              ],
            ),
            if (state.hasFreshVerifiedLocation && routePois.length > 1) ...[
              const SizedBox(height: 12),
              _RecommendedRoutePreview(
                state: state,
                pois: routePois,
              ),
            ],
            const SizedBox(height: 12),
            _RouteStep(
              complete: state.hasFreshVerifiedLocation,
              icon: Icons.my_location,
              title: '위치 확인',
              detail: state.hasFreshVerifiedLocation
                  ? '최근 위치 기준으로 체크인 반경을 계산 중입니다.'
                  : '체크인은 최근 15분 안에 확인한 위치에서만 열립니다.',
            ),
            _RouteStep(
              complete: state.todayCheckInCount > 0,
              icon: Icons.task_alt,
              title: '첫 체크인',
              detail: state.todayCheckInCount > 0
                  ? '${state.todayCheckInCount}회 체크인을 기록했습니다.'
                  : recommended == null
                      ? '현재 지역의 POI를 다시 조회해 보세요.'
                      : '${recommended.title}부터 살펴보세요.',
            ),
            _RouteStep(
              complete: talkedToday,
              icon: Icons.forum_outlined,
              title: '마실펫 교감',
              detail: talkedToday
                  ? '오늘 ${state.dialogueCountToday}/5회 대화했습니다.'
                  : '방문 맥락에 맞춘 대사를 한 번 들어보세요.',
            ),
            _RouteStep(
              complete: nextEgg?.status == EggStatus.hatchable,
              icon: Icons.egg_alt_outlined,
              title: '알 부화 준비',
              detail: nextEgg == null
                  ? '체크인 보상으로 새 알을 발견할 수 있습니다.'
                  : nextEgg.status == EggStatus.hatchable
                      ? '부화 가능한 알이 하우스에 있습니다.'
                      : '$eggRemainingSteps 걸음이 더 필요합니다.',
              isLast: action == null,
            ),
            if (action != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: action.onPressed,
                  icon: Icon(action.icon),
                  label: Text(action.label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _recommendationText(
    MasilPetState state,
    Poi? recommended,
    int? recommendedDistance,
  ) {
    if (recommended == null) {
      return '현재 위치를 확인하면 가까운 장소와 다음 성장 보상이 표시됩니다.';
    }
    if (state.remainingDailyCheckIns == 0) {
      return '오늘 체크인 한도 $dailyCheckInLimit회를 모두 사용했습니다. 내일 다시 새로운 보상을 이어가세요.';
    }
    if (state.hasCheckedInToday(recommended)) {
      return '오늘 방문 가능한 POI를 모두 기록했습니다. 내일 다시 성장 보상을 이어갈 수 있습니다.';
    }
    if (recommendedDistance == null) {
      return '${recommended.title}의 ${recommended.category.label} 보상을 먼저 노려보세요.';
    }
    return '${recommended.title}까지 ${recommendedDistance}m · ${recommended.category.label} 보상';
  }
}

class _RecommendedRoutePreview extends StatelessWidget {
  const _RecommendedRoutePreview({
    required this.state,
    required this.pois,
  });

  final MasilPetState state;
  final List<Poi> pois;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.alt_route_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '추천 코스',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '${pois.length}곳',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < pois.length; index++)
              _RecommendedRoutePoiRow(
                state: state,
                poi: pois[index],
                rank: index + 1,
                isFirst: index == 0,
                isLast: index == pois.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedRoutePoiRow extends StatelessWidget {
  const _RecommendedRoutePoiRow({
    required this.state,
    required this.poi,
    required this.rank,
    required this.isFirst,
    required this.isLast,
  });

  final MasilPetState state;
  final Poi poi;
  final int rank;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categoryColor = _categoryColor(poi.category);
    final reward = const GrowthEngine().rewardFor(poi.category);
    final checked = state.hasCheckedInToday(poi);
    final target =
        checked ? null : _discoveryTargetForCategory(state, poi.category);
    final distance = state.hasFreshVerifiedLocation
        ? '${state.currentLocation.distanceTo(poi.coordinates).round()}m'
        : '거리 확인 전';

    return Padding(
      key: ValueKey('recommended-route-${poi.id}'),
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isFirst
                  ? scheme.primary.withValues(alpha: 0.14)
                  : scheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFirst ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isFirst ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        poi.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (isFirst) ...[
                      const SizedBox(width: 6),
                      _RoutePreviewPill(
                        icon: Icons.near_me_outlined,
                        label: '다음',
                        color: scheme.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _RoutePreviewPill(
                      icon: _categoryIcon(poi.category),
                      label: poi.category.label,
                      color: categoryColor,
                    ),
                    _RoutePreviewPill(
                      icon: Icons.social_distance_outlined,
                      label: distance,
                      color: scheme.onSurfaceVariant,
                    ),
                    if (checked)
                      const _RoutePreviewPill(
                        icon: Icons.task_alt,
                        label: '완료',
                        color: Color(0xFF16A34A),
                      )
                    else if (state.canCheckInToday(poi))
                      const _RoutePreviewPill(
                        icon: Icons.check_circle_outline,
                        label: '체크인 가능',
                        color: Color(0xFF16A34A),
                      ),
                    _RoutePreviewPill(
                      icon: Icons.egg_alt_outlined,
                      label: '알 +${reward.eggProgress}',
                      color: const Color(0xFFB45309),
                    ),
                    if (target != null)
                      _RoutePreviewPill(
                        icon: Icons.pets_outlined,
                        label: target.name,
                        color: Color(target.colorValue),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePreviewPill extends StatelessWidget {
  const _RoutePreviewPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationReason {
  const _RecommendationReason({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

class _RecommendationReasonWrap extends StatelessWidget {
  const _RecommendationReasonWrap({required this.reasons});

  final List<_RecommendationReason> reasons;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final reason in reasons) _RecommendationReasonChip(reason: reason),
      ],
    );
  }
}

class _RecommendationReasonChip extends StatelessWidget {
  const _RecommendationReasonChip({required this.reason});

  final _RecommendationReason reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: reason.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(reason.icon, size: 15, color: reason.color),
          const SizedBox(width: 5),
          Text(
            reason.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: reason.color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

List<_RecommendationReason> _recommendationReasons({
  required MasilPetState state,
  required Poi? recommended,
}) {
  if (recommended == null) {
    return const [];
  }

  final reward = const GrowthEngine().rewardFor(recommended.category);
  final checked = state.hasCheckedInToday(recommended);
  final discoveryTarget = _discoveryTargetForCategory(
    state,
    recommended.category,
  );
  return [
    if (checked)
      const _RecommendationReason(
        icon: Icons.task_alt,
        label: '오늘 방문 완료',
        color: Color(0xFF16A34A),
      ),
    if (state.canCheckInToday(recommended))
      const _RecommendationReason(
        icon: Icons.check_circle_outline,
        label: '지금 체크인 가능',
        color: Color(0xFF16A34A),
      ),
    if (!checked &&
        !state.todayVisitedCategories.contains(recommended.category))
      _RecommendationReason(
        icon: Icons.category_outlined,
        label: '오늘 새 카테고리',
        color: _categoryColor(recommended.category),
      ),
    if (!checked &&
        state.undiscoveredCategoryGoals.contains(recommended.category))
      const _RecommendationReason(
        icon: Icons.auto_awesome_outlined,
        label: '도감 후보',
        color: Color(0xFF7C3AED),
      ),
    if (!checked && discoveryTarget != null)
      _RecommendationReason(
        icon: Icons.pets_outlined,
        label: discoveryTarget.name,
        color: Color(discoveryTarget.colorValue),
      ),
    if (!checked)
      _RecommendationReason(
        icon: Icons.egg_alt_outlined,
        label: '알 +${reward.eggProgress}',
        color: const Color(0xFFB45309),
      ),
  ];
}

PetTemplate? _discoveryTargetForCategory(
  MasilPetState state,
  PoiCategory category,
) {
  for (final template in state.templates) {
    if (template.primaryCategory == category &&
        !state.discoveredTemplateIds.contains(template.id)) {
      return template;
    }
  }
  return null;
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({
    required this.complete,
    required this.icon,
    required this.title,
    required this.detail,
    this.isLast = false,
  });

  final bool complete;
  final IconData icon;
  final String title;
  final String detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = complete ? const Color(0xFF16A34A) : scheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              complete ? Icons.check_circle : icon,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteAction {
  const _RouteAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
}

_RouteAction? _nextRouteAction({
  required MasilPetState state,
  required Poi? recommended,
  required bool talkedToday,
  required VoidCallback? onUseDeviceLocation,
  required ValueChanged<Poi> onCheckInPoi,
  required VoidCallback? onOpenPet,
  required VoidCallback? onOpenHouse,
}) {
  if (!state.hasFreshVerifiedLocation) {
    return _RouteAction(
      icon: Icons.my_location,
      label: '현재 위치 확인',
      onPressed: onUseDeviceLocation,
    );
  }
  if (recommended != null &&
      state.todayCheckInCount == 0 &&
      state.canCheckInToday(recommended)) {
    return _RouteAction(
      icon: Icons.check_circle_outline,
      label: '추천 장소 체크인하기',
      onPressed: state.isBusy ? null : () => onCheckInPoi(recommended),
    );
  }
  if (state.todayCheckInCount > 0 && !talkedToday) {
    return _RouteAction(
      icon: Icons.forum_outlined,
      label: '마실펫과 대화하기',
      onPressed: onOpenPet,
    );
  }
  if (state.hatchableEggCount > 0) {
    return _RouteAction(
      icon: Icons.egg_alt_outlined,
      label: '하우스에서 부화하기',
      onPressed: onOpenHouse,
    );
  }
  return null;
}

bool _hasTalkedToday(MasilPetState state) {
  return isSameLocalDay(state.dialogueDay, DateTime.now()) &&
      state.dialogueCountToday > 0;
}

class _LivePoiMap extends ConsumerStatefulWidget {
  const _LivePoiMap({
    required this.state,
    required this.height,
  });

  final MasilPetState state;
  final double height;

  @override
  ConsumerState<_LivePoiMap> createState() => _LivePoiMapState();
}

class _LivePoiMapState extends ConsumerState<_LivePoiMap> {
  String? _selectedPoiId;

  @override
  void didUpdateWidget(covariant _LivePoiMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedPoiId = _selectedPoiId;
    if (selectedPoiId != null &&
        !widget.state.pois.any((poi) => poi.id == selectedPoiId)) {
      _selectedPoiId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = ref.read(masilPetControllerProvider.notifier);
    final currentPoint = LatLng(
      state.currentLocation.latitude,
      state.currentLocation.longitude,
    );
    final legendCategories = _visiblePoiCategories(state.pois);
    final selectedPoi = _poiById(state.pois, _selectedPoiId);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
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
                      urlTemplate: mapTileBuildConfig.urlTemplate,
                      userAgentPackageName:
                          mapTileBuildConfig.userAgentPackageName,
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
                              selected: selectedPoi?.id == poi.id,
                              onTap: () {
                                setState(() {
                                  _selectedPoiId = poi.id;
                                });
                              },
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
          if (selectedPoi != null)
            _MapPoiFocusPanel(
              key: ValueKey('map-focus-${selectedPoi.id}'),
              state: state,
              poi: selectedPoi,
              onUseDeviceLocation:
                  state.isBusy ? null : () => controller.useDeviceLocation(),
              onCheckIn: state.isBusy
                  ? null
                  : () => controller.attemptCheckIn(selectedPoi),
            ),
          _MapLegend(categories: legendCategories),
        ],
      ),
    );
  }
}

Poi? _poiById(List<Poi> pois, String? id) {
  if (id == null) {
    return null;
  }
  for (final poi in pois) {
    if (poi.id == id) {
      return poi;
    }
  }
  return null;
}

class _MapPoiFocusPanel extends StatelessWidget {
  const _MapPoiFocusPanel({
    super.key,
    required this.state,
    required this.poi,
    required this.onUseDeviceLocation,
    required this.onCheckIn,
  });

  final MasilPetState state;
  final Poi poi;
  final VoidCallback? onUseDeviceLocation;
  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final distance = state.currentLocation.distanceTo(poi.coordinates);
    final checked = state.hasCheckedInToday(poi);
    final inRange =
        state.hasFreshVerifiedLocation && distance <= checkInRadiusMeters;
    final needsLocation = !state.hasFreshVerifiedLocation;
    final limitReached = state.remainingDailyCheckIns == 0;
    final canCheckIn = inRange && !checked && !limitReached && !state.isBusy;
    final canRequestLocation =
        needsLocation && !checked && !limitReached && !state.isBusy;
    final canRefreshLocation = !needsLocation &&
        !inRange &&
        !checked &&
        !limitReached &&
        !state.isBusy;
    final reward = const GrowthEngine().rewardFor(poi.category);
    final target = checked
        ? null
        : _discoveryTargetForCategory(
            state,
            poi.category,
          );
    final categoryColor = _categoryColor(poi.category);
    final actionIcon = checked
        ? Icons.task_alt
        : limitReached
            ? Icons.event_busy_outlined
            : needsLocation || canRefreshLocation
                ? Icons.my_location
                : canCheckIn
                    ? Icons.check_circle_outline
                    : Icons.near_me_disabled;
    final actionLabel = checked
        ? '오늘 체크인 완료'
        : limitReached
            ? '오늘 한도 완료'
            : needsLocation
                ? '현재 위치 확인'
                : canRefreshLocation
                    ? '현재 위치 다시 확인'
                    : inRange
                        ? '선택 장소 체크인'
                        : '150m 안에서 가능';
    final action = canCheckIn
        ? onCheckIn
        : canRequestLocation || canRefreshLocation
            ? onUseDeviceLocation
            : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _categoryIcon(poi.category),
                    color: categoryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '선택 장소',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        poi.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RoutePreviewPill(
                  icon: state.hasFreshVerifiedLocation
                      ? Icons.social_distance_outlined
                      : Icons.location_searching,
                  label: state.hasFreshVerifiedLocation
                      ? '${distance.round()}m'
                      : '거리 확인 전',
                  color: state.hasFreshVerifiedLocation
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              poi.shortDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _RoutePreviewPill(
                  icon: _categoryIcon(poi.category),
                  label: poi.category.label,
                  color: categoryColor,
                ),
                _RoutePreviewPill(
                  icon: Icons.dataset_linked_outlined,
                  label: _poiSourceLabel(poi),
                  color: const Color(0xFFB45309),
                ),
                if (checked)
                  const _RoutePreviewPill(
                    icon: Icons.task_alt,
                    label: '오늘 방문 완료',
                    color: Color(0xFF16A34A),
                  )
                else if (state.canCheckInToday(poi))
                  const _RoutePreviewPill(
                    icon: Icons.check_circle_outline,
                    label: '지금 체크인 가능',
                    color: Color(0xFF16A34A),
                  ),
                if (target != null)
                  _RoutePreviewPill(
                    icon: Icons.pets_outlined,
                    label: target.name,
                    color: Color(target.colorValue),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            RewardChipRow(
              reward: reward,
              spacing: 6,
              runSpacing: 6,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: action,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<PoiCategory> _visiblePoiCategories(List<Poi> pois) {
  final categories = pois.map((poi) => poi.category).toSet().toList();
  categories.sort((left, right) => left.index.compareTo(right.index));
  return categories;
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.categories});

  final List<PoiCategory> categories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: '지도 마커 범례',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _LegendChip(
                icon: Icons.navigation,
                label: '현재 위치',
                color: scheme.primary,
              ),
              const _LegendChip(
                icon: Icons.task_alt,
                label: '체크인 완료',
                color: Color(0xFF16A34A),
              ),
              for (final category in categories)
                _LegendChip(
                  icon: Icons.location_on,
                  label: category.label,
                  color: _categoryColor(category),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _PoiMarker extends StatelessWidget {
  const _PoiMarker({
    required this.poi,
    required this.checked,
    required this.selected,
    required this.onTap,
  });

  final Poi poi;
  final bool checked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(poi.category);
    final statusLabel = checked ? '오늘 체크인 완료' : '체크인 후보';

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      onTap: onTap,
      onTapHint: '장소 정보 보기',
      label: 'POI 마커: ${poi.title}, ${poi.category.label}, $statusLabel',
      child: Tooltip(
        message: poi.title,
        excludeFromSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: ValueKey('map-marker-${poi.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedScale(
              scale: selected ? 1.16 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '현재 위치 마커: 150m 체크인 반경 중심',
      child: DecoratedBox(
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
      ),
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
    final limitReached = state.remainingDailyCheckIns == 0;
    final canCheckIn = inRange && !checked && !limitReached && !state.isBusy;
    final canRequestLocation =
        needsLocation && !checked && !limitReached && !state.isBusy;
    final canRefreshLocation = !needsLocation &&
        !inRange &&
        !checked &&
        !limitReached &&
        !state.isBusy;
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
            const SizedBox(height: 8),
            _PoiSourceLine(
              label:
                  '${regionNameForId(poi.regionId)} · ${_poiSourceLabel(poi)}',
            ),
            const SizedBox(height: 10),
            RewardChipRow(reward: reward),
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
                    : limitReached
                        ? Icons.event_busy_outlined
                        : needsLocation || canRefreshLocation
                            ? Icons.my_location
                            : canCheckIn
                                ? Icons.check_circle
                                : Icons.near_me_disabled),
                label: Text(checked
                    ? '오늘 체크인 완료'
                    : limitReached
                        ? '오늘 한도 완료'
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

class _PoiSourceLine extends StatelessWidget {
  const _PoiSourceLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.dataset_linked_outlined,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

String _poiSourceLabel(Poi poi) {
  final contentId = poi.tourApiContentId.trim();
  if (contentId.isEmpty || contentId.startsWith('seed-')) {
    return '전국 기본 장소';
  }
  return 'TourAPI ID $contentId';
}

IconData _categoryIcon(PoiCategory category) {
  return switch (category) {
    PoiCategory.nature => Icons.park_outlined,
    PoiCategory.food => Icons.restaurant_outlined,
    PoiCategory.festival => Icons.celebration_outlined,
    PoiCategory.culture => Icons.theater_comedy_outlined,
    PoiCategory.history => Icons.account_balance_outlined,
    PoiCategory.shopping => Icons.storefront_outlined,
    PoiCategory.other => Icons.place_outlined,
  };
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
