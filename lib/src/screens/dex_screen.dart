import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/rarity_badge.dart';
import '../widgets/reward_chip_row.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/section_header.dart';

class DexScreen extends ConsumerWidget {
  const DexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('전국 도감')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: ResponsiveSliverList(
            children: [
              _DexProgressCard(state: state),
              const SizedBox(height: 16),
              _NextDiscoveryCard(state: state),
              const SizedBox(height: 16),
              _DexPassportCard(state: state),
              const SizedBox(height: 16),
              _DexCollectionLayout(
                templates: state.templates,
                discoveredTemplateIds: state.discoveredTemplateIds,
                pois: state.pois.take(6).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextDiscoveryCard extends ConsumerWidget {
  const _NextDiscoveryCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final target = _nextDiscoveryTemplate(state);
    final scheme = Theme.of(context).colorScheme;

    if (target == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.workspace_premium_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '전국 도감 완성',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text('모든 마실펫을 발견했습니다. 방문 기록을 더 쌓아 지역 친밀도를 높여보세요.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final poi = _nextDiscoveryPoi(state, target.primaryCategory);
    final reward = const GrowthEngine().rewardFor(target.primaryCategory);
    final routeLabel = poi == null
        ? '${target.primaryCategory.label} 장소 탐험'
        : '${poi.title} · ${target.primaryCategory.label}';
    final sourceLabel = poi == null
        ? '${target.primaryCategory.label} 산책지 힌트'
        : _poiSourceLabel(poi);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DexAvatar(
                  template: target,
                  discovered: false,
                  size: 70,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '다음 발견 후보',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${target.name} · ${target.primaryCategory.label} 카테고리',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _DiscoveryHintChip(
                            icon: Icons.place_outlined,
                            label: routeLabel,
                            color: const Color(0xFF0F766E),
                          ),
                          _DiscoveryHintChip(
                            icon: Icons.near_me_outlined,
                            label: _discoveryDistanceLabel(state, poi),
                            color: const Color(0xFF2563EB),
                          ),
                          _DiscoveryHintChip(
                            icon: Icons.dataset_linked_outlined,
                            label: sourceLabel,
                            color: const Color(0xFFB45309),
                          ),
                          _DiscoveryHintChip(
                            icon: Icons.auto_awesome_outlined,
                            label: target.rarityLabel,
                            color: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              poi == null
                  ? '${target.primaryCategory.label} 장소 체크인과 알 부화를 이어가면 새 스탬프가 열립니다.'
                  : '${poi.title} 같은 ${target.primaryCategory.label} 장소를 방문하면 도감 후보와 알 진행도가 함께 가까워집니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '체크인 시 예상 보상',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  RewardChipRow(
                    reward: reward,
                    spacing: 6,
                    runSpacing: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    poi == null
                        ? '가까운 ${target.primaryCategory.label} 장소를 찾으면 새로운 힌트가 열려요.'
                        : '${poi.title}을 방문하면 새로운 만남에 가까워져요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => controller.setTab(
                  0,
                  mapCategoryFocus: target.primaryCategory,
                ),
                icon: const Icon(Icons.map_outlined),
                label: Text('지도에서 ${target.primaryCategory.label} 장소 찾기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryHintChip extends StatelessWidget {
  const _DiscoveryHintChip({
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
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

PetTemplate? _nextDiscoveryTemplate(MasilPetState state) {
  final discovered = state.discoveredTemplateIds;
  for (final template in state.templates) {
    if (!discovered.contains(template.id)) {
      return template;
    }
  }
  return null;
}

Poi? _nextDiscoveryPoi(MasilPetState state, PoiCategory category) {
  final candidates = state.pois
      .where((poi) => poi.category == category && !state.hasCheckedInToday(poi))
      .toList();
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort(
    (left, right) => state.currentLocation
        .distanceTo(left.coordinates)
        .compareTo(state.currentLocation.distanceTo(right.coordinates)),
  );
  return candidates.first;
}

String _discoveryDistanceLabel(MasilPetState state, Poi? poi) {
  if (poi == null) {
    return '장소 확인 필요';
  }
  if (!state.hasFreshVerifiedLocation) {
    return '위치 확인 필요';
  }
  return '${state.currentLocation.distanceTo(poi.coordinates).round()}m';
}

String _poiSourceLabel(Poi poi) {
  if (poi.tourApiContentId.isEmpty ||
      poi.tourApiContentId.startsWith('seed-')) {
    return '추천 산책지';
  }
  return '지역 산책지';
}

class _DexCollectionLayout extends StatelessWidget {
  const _DexCollectionLayout({
    required this.templates,
    required this.discoveredTemplateIds,
    required this.pois,
  });

  static const _wideBreakpoint = 840.0;

  final List<PetTemplate> templates;
  final Set<String> discoveredTemplateIds;
  final List<Poi> pois;

  @override
  Widget build(BuildContext context) {
    final pets = _DexPetsSection(
      templates: templates,
      discoveredTemplateIds: discoveredTemplateIds,
    );
    final mapping = _TourApiMappingSection(pois: pois);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= _wideBreakpoint;
        if (!useTwoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pets,
              const SizedBox(height: 16),
              mapping,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: pets),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: mapping),
          ],
        );
      },
    );
  }
}

class _DexPassportCard extends ConsumerWidget {
  const _DexPassportCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final discovered = state.discoveredTemplateIds.length;
    final total = state.templates.length;
    final target = _nextDiscoveryTemplate(state);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '전국 탐험 여권',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$discovered/$total',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '장소 카테고리마다 연결된 마실펫을 발견해 전국 여권을 채웁니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _PassportStampGrid(
              templates: state.templates,
              discoveredTemplateIds: state.discoveredTemplateIds,
            ),
            if (discovered < total) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => controller.setTab(
                    0,
                    mapCategoryFocus: target?.primaryCategory,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('다음 스탬프 찾기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PassportStampGrid extends StatelessWidget {
  const _PassportStampGrid({
    required this.templates,
    required this.discoveredTemplateIds,
  });

  final List<PetTemplate> templates;
  final Set<String> discoveredTemplateIds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 ? 1 : 2;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final template in templates)
              SizedBox(
                width: itemWidth,
                child: _PassportStamp(
                  template: template,
                  discovered: discoveredTemplateIds.contains(template.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PassportStamp extends StatelessWidget {
  const _PassportStamp({
    required this.template,
    required this.discovered,
  });

  final PetTemplate template;
  final bool discovered;

  @override
  Widget build(BuildContext context) {
    final color = Color(template.colorValue);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: discovered
            ? color.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: discovered
              ? color.withValues(alpha: 0.44)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: discovered
                  ? color.withValues(alpha: 0.16)
                  : scheme.surface.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              discovered ? Icons.verified_outlined : Icons.explore_outlined,
              color: discovered ? color : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.primaryCategory.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: discovered ? color : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  discovered ? template.name : '스탬프 대기',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (discovered)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RarityBadge(rarity: template.rarity, compact: true),
                  )
                else
                  Text(
                    '체크인과 부화로 발견',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _DexDiscoveryFilter {
  all,
  discovered,
  undiscovered,
}

class _DexPetsSection extends StatefulWidget {
  const _DexPetsSection({
    required this.templates,
    required this.discoveredTemplateIds,
  });

  final List<PetTemplate> templates;
  final Set<String> discoveredTemplateIds;

  @override
  State<_DexPetsSection> createState() => _DexPetsSectionState();
}

class _DexPetsSectionState extends State<_DexPetsSection> {
  _DexDiscoveryFilter _discoveryFilter = _DexDiscoveryFilter.all;
  PoiCategory? _categoryFilter;

  @override
  void didUpdateWidget(covariant _DexPetsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final category = _categoryFilter;
    if (category != null &&
        !widget.templates.any(
          (template) => template.primaryCategory == category,
        )) {
      _categoryFilter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.templates
        .map((template) => template.primaryCategory)
        .toSet()
        .toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    final filteredTemplates = widget.templates.where((template) {
      final discovered = widget.discoveredTemplateIds.contains(template.id);
      final matchesDiscovery = switch (_discoveryFilter) {
        _DexDiscoveryFilter.all => true,
        _DexDiscoveryFilter.discovered => discovered,
        _DexDiscoveryFilter.undiscovered => !discovered,
      };
      final matchesCategory = _categoryFilter == null ||
          template.primaryCategory == _categoryFilter;
      return matchesDiscovery && matchesCategory;
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '수집한 마실펫',
          detail:
              '${widget.discoveredTemplateIds.length}/${widget.templates.length}',
          icon: Icons.pets_outlined,
        ),
        _DexAlbumFilters(
          discoveryFilter: _discoveryFilter,
          categoryFilter: _categoryFilter,
          categories: categories,
          visibleCount: filteredTemplates.length,
          onDiscoveryFilterChanged: (filter) {
            setState(() {
              _discoveryFilter = filter;
            });
          },
          onCategoryFilterChanged: (category) {
            setState(() {
              _categoryFilter = category;
            });
          },
        ),
        const SizedBox(height: 12),
        if (filteredTemplates.isEmpty)
          EmptyStateCard(
            icon: Icons.filter_alt_off_outlined,
            title: '조건에 맞는 스티커가 없습니다',
            body: '다른 발견 상태나 장소 힌트를 선택해 앨범을 다시 살펴보세요.',
            actionIcon: Icons.restart_alt,
            actionLabel: '필터 초기화',
            onAction: () {
              setState(() {
                _discoveryFilter = _DexDiscoveryFilter.all;
                _categoryFilter = null;
              });
            },
          ),
        if (filteredTemplates.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = switch (constraints.maxWidth) {
                < 330 => 1,
                < 680 => 2,
                < 940 => 3,
                _ => 4,
              };
              const spacing = 12.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final template in filteredTemplates)
                    SizedBox(
                      width: itemWidth,
                      child: _DexPetCard(
                        template: template,
                        discovered:
                            widget.discoveredTemplateIds.contains(template.id),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _DexAlbumFilters extends StatelessWidget {
  const _DexAlbumFilters({
    required this.discoveryFilter,
    required this.categoryFilter,
    required this.categories,
    required this.visibleCount,
    required this.onDiscoveryFilterChanged,
    required this.onCategoryFilterChanged,
  });

  final _DexDiscoveryFilter discoveryFilter;
  final PoiCategory? categoryFilter;
  final List<PoiCategory> categories;
  final int visibleCount;
  final ValueChanged<_DexDiscoveryFilter> onDiscoveryFilterChanged;
  final ValueChanged<PoiCategory?> onCategoryFilterChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.masilPetTheme;

    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tokens.sun.withValues(alpha: 0.38),
                    borderRadius: MasilPetRadii.smallBorder,
                  ),
                  child: Icon(
                    Icons.auto_awesome_mosaic_outlined,
                    color: scheme.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '스티커 앨범 필터',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: tokens.paper,
                    borderRadius: MasilPetRadii.pillBorder,
                    border: Border.all(color: tokens.outline),
                  ),
                  child: Text(
                    '$visibleCount종 표시',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.mutedInk,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '발견 상태',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: tokens.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final filter in _DexDiscoveryFilter.values)
                  ChoiceChip(
                    key: ValueKey('dex-discovery-filter-${filter.name}'),
                    selected: discoveryFilter == filter,
                    avatar: Icon(
                      _discoveryFilterIcon(filter),
                      size: 16,
                    ),
                    label: Text(_discoveryFilterLabel(filter)),
                    onSelected: (_) => onDiscoveryFilterChanged(filter),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '장소 힌트',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: tokens.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  key: const ValueKey('dex-category-filter-all'),
                  selected: categoryFilter == null,
                  avatar: const Icon(Icons.public, size: 16),
                  label: const Text('모든 장소'),
                  onSelected: (_) => onCategoryFilterChanged(null),
                ),
                for (final category in categories)
                  FilterChip(
                    key: ValueKey('dex-category-filter-${category.name}'),
                    selected: categoryFilter == category,
                    avatar: Icon(_dexCategoryIcon(category), size: 16),
                    label: Text(category.label),
                    onSelected: (selected) => onCategoryFilterChanged(
                      selected ? category : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _discoveryFilterLabel(_DexDiscoveryFilter filter) {
  return switch (filter) {
    _DexDiscoveryFilter.all => '전체',
    _DexDiscoveryFilter.discovered => '발견',
    _DexDiscoveryFilter.undiscovered => '미발견',
  };
}

IconData _discoveryFilterIcon(_DexDiscoveryFilter filter) {
  return switch (filter) {
    _DexDiscoveryFilter.all => Icons.grid_view_rounded,
    _DexDiscoveryFilter.discovered => Icons.verified_rounded,
    _DexDiscoveryFilter.undiscovered => Icons.help_outline_rounded,
  };
}

IconData _dexCategoryIcon(PoiCategory category) {
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

class _TourApiMappingSection extends ConsumerWidget {
  const _TourApiMappingSection({required this.pois});

  final List<Poi> pois;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: '발견 힌트가 있는 산책지',
          icon: Icons.route_outlined,
        ),
        if (pois.isEmpty)
          EmptyStateCard(
            icon: Icons.route_outlined,
            title: '아직 등록된 산책지가 없습니다',
            body: '현재 위치를 다시 확인하면 가까운 산책지 힌트를 볼 수 있습니다.',
            actionIcon: Icons.map_outlined,
            actionLabel: '지도에서 다시 조회',
            onAction: () => controller.setTab(0),
          )
        else
          _PoiMappingCard(pois: pois),
      ],
    );
  }
}

class _PoiMappingCard extends StatelessWidget {
  const _PoiMappingCard({required this.pois});

  final List<Poi> pois;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final poi in pois)
              ListTile(
                dense: true,
                leading: const Icon(Icons.place_outlined),
                title: Text(poi.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${poi.category.label} · 새로운 친구 발견 힌트'),
                    const SizedBox(height: 2),
                    Text(
                      _poiSourceLabel(poi),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DexProgressCard extends ConsumerWidget {
  const _DexProgressCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final discovered = state.discoveredTemplateIds.length;
    final total = state.templates.length;
    final hasUndiscovered = discovered < total;
    final target = _nextDiscoveryTemplate(state);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '마실펫 도감',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$discovered / $total',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: state.dexCompletionRatio,
                backgroundColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '지역별 체크인과 부화를 통해 전국 마실펫을 수집합니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hasUndiscovered) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => controller.setTab(
                    0,
                    mapCategoryFocus: target?.primaryCategory,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('지도에서 탐험하기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DexPetCard extends StatelessWidget {
  const _DexPetCard({
    required this.template,
    required this.discovered,
  });

  final PetTemplate template;
  final bool discovered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.masilPetTheme;
    final color = Color(template.colorValue);
    final surfaceColor = discovered
        ? Color.alphaBlend(color.withValues(alpha: 0.08), tokens.paper)
        : scheme.surfaceContainerLow;

    return SizedBox(
      height: 310,
      child: Card(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: MasilPetRadii.cardBorder,
          side: BorderSide(
            color: discovered ? color.withValues(alpha: 0.38) : tokens.outline,
            width: 1.2,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Transform.rotate(
                angle: -0.035,
                child: Container(
                  width: 54,
                  height: 11,
                  decoration: BoxDecoration(
                    color: discovered
                        ? tokens.sun.withValues(alpha: 0.56)
                        : tokens.outline.withValues(alpha: 0.62),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: MasilPetRadii.pillBorder,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _dexCategoryIcon(template.primaryCategory),
                            size: 13,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              template.primaryCategory.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: _DexAvatar(
                      template: template,
                      discovered: discovered,
                      size: 94,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: _DiscoveryBadge(discovered: discovered)),
                  const SizedBox(height: 6),
                  Text(
                    discovered ? template.name : '미발견 마실펫',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 25,
                    child: Center(
                      child: discovered
                          ? RarityBadge(
                              rarity: template.rarity,
                              compact: true,
                            )
                          : Text(
                              '어떤 친구일까요?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: tokens.mutedInk,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    child: Text(
                      discovered
                          ? template.basePersonality
                          : '${template.primaryCategory.label} 장소를 더 탐험하면 만날 수 있습니다.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.mutedInk,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryBadge extends StatelessWidget {
  const _DiscoveryBadge({required this.discovered});

  final bool discovered;

  @override
  Widget build(BuildContext context) {
    final tokens = context.masilPetTheme;
    final color = discovered ? tokens.success : tokens.mutedInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: MasilPetRadii.pillBorder,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            discovered ? Icons.check_rounded : Icons.help_outline_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            discovered ? '발견' : '탐험 필요',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _DexAvatar extends StatelessWidget {
  const _DexAvatar({
    required this.template,
    required this.discovered,
    this.size = 58,
  });

  final PetTemplate template;
  final bool discovered;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (discovered) {
      return PetAvatar(template: template, size: size);
    }

    final scheme = Theme.of(context).colorScheme;
    final color = Color(template.colorValue);
    return Semantics(
      container: true,
      label: '미발견 마실펫, ${template.primaryCategory.label} 장소 힌트',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(size * 0.28),
              border: Border.all(
                color: color.withValues(alpha: 0.38),
                width: 1.3,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.cruelty_free_rounded,
                  size: size * 0.62,
                  color: color.withValues(alpha: 0.42),
                ),
                Positioned(
                  right: size * 0.08,
                  bottom: size * 0.08,
                  child: Container(
                    width: size * 0.31,
                    height: size * 0.31,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outlineVariant),
                      boxShadow: MasilPetShadows.soft,
                    ),
                    child: Text(
                      '?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
