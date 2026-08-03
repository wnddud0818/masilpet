import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../pet_assets.dart';
import '../seed_data.dart';
import '../services.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/paper_kit.dart';
import '../widgets/paper_shell.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/reward_chip_row.dart';
import '../widgets/section_header.dart';

/// 도감: a sticker album of every 마실펫, filtered by region and discovery.
class DexScreen extends ConsumerStatefulWidget {
  const DexScreen({super.key});

  @override
  ConsumerState<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends ConsumerState<DexScreen> {
  static const _allRegions = 'korea';

  String _regionId = _allRegions;
  _DexDiscoveryFilter _discoveryFilter = _DexDiscoveryFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final discovered = state.discoveredTemplateIds;

    final regionIds = <String>[
      _allRegions,
      ...{
        for (final template in state.templates)
          if (template.regionId != _allRegions) template.regionId,
      },
    ];
    if (!regionIds.contains(_regionId)) {
      _regionId = _allRegions;
    }

    final entries = state.templates.where((template) {
      final isDiscovered = discovered.contains(template.id);
      final matchesRegion =
          _regionId == _allRegions || template.regionId == _regionId;
      final matchesDiscovery = switch (_discoveryFilter) {
        _DexDiscoveryFilter.all => true,
        _DexDiscoveryFilter.discovered => isDiscovered,
        _DexDiscoveryFilter.undiscovered => !isDiscovered,
      };
      return matchesRegion && matchesDiscovery;
    }).toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: kPaperBodyPadding,
          sliver: ResponsiveSliverList(
            children: [
              _DexSummaryCard(state: state),
              const SizedBox(height: MasilPetSpacing.lg),
              FilterPillRow<String>(
                values: regionIds,
                labelOf: shortRegionLabelForId,
                selected: _regionId,
                onSelected: (value) => setState(() => _regionId = value),
              ),
              const SizedBox(height: MasilPetSpacing.sm),
              FilterPillRow<_DexDiscoveryFilter>(
                values: _DexDiscoveryFilter.values,
                labelOf: _discoveryFilterLabel,
                selected: _discoveryFilter,
                onSelected: (value) => setState(() => _discoveryFilter = value),
              ),
              const SizedBox(height: MasilPetSpacing.lg),
              if (entries.isEmpty)
                EmptyStateCard(
                  note: '비어 있어요',
                  title: '조건에 맞는 스티커가 없어요',
                  body: '다른 지역이나 발견 상태를 골라 앨범을 다시 살펴보세요.',
                  actionLabel: '필터 초기화',
                  onAction: () => setState(() {
                    _regionId = _allRegions;
                    _discoveryFilter = _DexDiscoveryFilter.all;
                  }),
                )
              else
                _DexGrid(
                  templates: entries,
                  discoveredTemplateIds: discovered,
                  onOpen: (template) => _openSheet(
                    context: context,
                    template: template,
                    state: state,
                    discovered: discovered.contains(template.id),
                  ),
                ),
              const SizedBox(height: MasilPetSpacing.xl),
              _NextDiscoveryNote(
                state: state,
                onOpenMap: (category) => controller.setTab(
                  0,
                  mapCategoryFocus: category,
                ),
              ),
              const SizedBox(height: MasilPetSpacing.xl),
              _DiscoveryHintList(
                pois: state.pois.take(6).toList(),
                onOpenMap: () => controller.setTab(0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openSheet({
    required BuildContext context,
    required PetTemplate template,
    required MasilPetState state,
    required bool discovered,
  }) {
    if (!discovered) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content:
                Text('${shortRegionLabelForId(template.regionId)}에서 만날 수 있어요'),
          ),
        );
      return;
    }

    Pet? owned;
    for (final pet in state.pets) {
      if (pet.templateId == template.id) {
        owned = pet;
        break;
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DexDetailSheet(template: template, pet: owned),
    );
  }
}

enum _DexDiscoveryFilter { all, discovered, undiscovered }

String _discoveryFilterLabel(_DexDiscoveryFilter filter) {
  return switch (filter) {
    _DexDiscoveryFilter.all => '전체',
    _DexDiscoveryFilter.discovered => '발견',
    _DexDiscoveryFilter.undiscovered => '미발견',
  };
}

/// The album cover: how many of the nation's pets are pressed into the book.
class _DexSummaryCard extends StatelessWidget {
  const _DexSummaryCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final found = state.discoveredTemplateIds.length;
    final total = state.templates.length;

    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HandNote('전국 도감'),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$found',
                      style: MasilPetType.heroTitle.copyWith(
                        fontSize: 28,
                        letterSpacing: -0.56,
                      ),
                    ),
                    Text(
                      ' / $total종',
                      style: MasilPetType.bodySmall.copyWith(
                        fontSize: 17,
                        color: MasilPetPalette.mutedWarm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PaperTrack(
                  ratio: state.dexCompletionRatio,
                  color: MasilPetPalette.forest,
                  height: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          RoundStamp(
            top: 'COLLECTED',
            middle: '$found',
            size: 74,
            angleDegrees: -7,
            middleFontSize: 19,
          ),
        ],
      ),
    );
  }
}

class _DexGrid extends StatelessWidget {
  const _DexGrid({
    required this.templates,
    required this.discoveredTemplateIds,
    required this.onOpen,
  });

  final List<PetTemplate> templates;
  final Set<String> discoveredTemplateIds;
  final ValueChanged<PetTemplate> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 9.0;
        const minCell = 104.0;
        final columns = ((constraints.maxWidth + spacing) / (minCell + spacing))
            .floor()
            .clamp(2, 8);
        final itemWidth =
            ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                .clamp(0.0, double.infinity);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final template in templates)
              SizedBox(
                width: itemWidth,
                child: _DexCell(
                  template: template,
                  discovered: discoveredTemplateIds.contains(template.id),
                  onTap: () => onOpen(template),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DexCell extends StatelessWidget {
  const _DexCell({
    required this.template,
    required this.discovered,
    required this.onTap,
  });

  final PetTemplate template;
  final bool discovered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: discovered
          ? '${template.name}, ${shortRegionLabelForId(template.regionId)}'
          : '미발견, ${shortRegionLabelForId(template.regionId)}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: MasilPetRadii.cardBorder,
          child: PaperCard(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 9),
            child: Column(
              children: [
                if (discovered)
                  PixelSprite(
                    asset: PetAssets.growth(template.assetKey, 'grown'),
                    size: 62,
                    fallback: SizedBox(
                      width: 62,
                      height: 62,
                      child: Center(
                        child: Text(
                          template.initials,
                          style: MasilPetType.rowTitle.copyWith(
                            fontSize: 22,
                            color: Color(template.colorValue),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    width: 62,
                    height: 62,
                    child: Center(
                      child: HandNote(
                        '?',
                        fontSize: 34,
                        color: MasilPetPalette.disabledFaint,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  discovered ? template.name : '미발견',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MasilPetType.rowTitle.copyWith(
                    fontSize: 13.5,
                    fontWeight: discovered ? FontWeight.w700 : FontWeight.w400,
                    color: discovered
                        ? MasilPetPalette.ink
                        : MasilPetPalette.disabled,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  discovered ? shortRegionLabelForId(template.regionId) : '???',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MasilPetType.microMono.copyWith(
                    fontSize: discovered ? 10.5 : 8.5,
                    letterSpacing: 0.6,
                    color: discovered
                        ? const Color(0xFF7A6B57)
                        : MasilPetPalette.disabledFaint,
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

/// The detail page torn out of the album.
class _DexDetailSheet extends StatelessWidget {
  const _DexDetailSheet({required this.template, required this.pet});

  final PetTemplate template;
  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    final pet = this.pet;

    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PixelSprite(
                    asset: PetAssets.growth(template.assetKey, 'grown'),
                    size: 96,
                    semanticLabel: template.name,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${template.rarityLabel} · '
                          '${regionNameForId(template.regionId)}',
                          style: MasilPetType.eyebrow.copyWith(
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          template.name,
                          style: MasilPetType.heroTitle.copyWith(fontSize: 27),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const DashedRule(),
              const SizedBox(height: 16),
              Text(
                template.basePersonality,
                style: MasilPetType.prose,
              ),
              const SizedBox(height: 16),
              const DashedRule(),
              const SizedBox(height: 14),
              _SheetFactRow(
                label: '즐겨 찾는 곳',
                value: template.primaryCategory.label,
              ),
              const SizedBox(height: 8),
              _SheetFactRow(
                label: '첫 만남',
                value: pet == null
                    ? '아직 만나지 못했어요'
                    : '${_dateLabel(pet.hatchedAt)} · '
                        '${regionNameForId(pet.originRegionId)}',
              ),
              if (pet != null) ...[
                const SizedBox(height: 8),
                _SheetFactRow(
                  label: '함께한 기록',
                  value: 'Lv.${pet.level} · ${pet.stage.label} 단계',
                ),
              ],
              const SizedBox(height: 20),
              PaperButton(
                label: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                fontSize: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: MasilPetSpacing.xl,
                  vertical: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetFactRow extends StatelessWidget {
  const _SheetFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MasilPetType.caption.copyWith(fontSize: 12.5),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: MasilPetType.caption.copyWith(
              fontSize: 12.5,
              color: MasilPetPalette.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

/// Who is next, and where to look for them.
class _NextDiscoveryNote extends StatelessWidget {
  const _NextDiscoveryNote({required this.state, required this.onOpenMap});

  final MasilPetState state;
  final ValueChanged<PoiCategory?> onOpenMap;

  @override
  Widget build(BuildContext context) {
    final target = _nextDiscoveryTemplate(state);

    if (target == null) {
      return DashedBox(
        fill: MasilPetPalette.subtle,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HandNote('도감을 다 채웠어요'),
            const SizedBox(height: MasilPetSpacing.sm),
            Text(
              '전국의 마실펫을 모두 만났어요.\n이제는 같은 길을 더 자주 걸어 친밀도를 쌓아보세요.',
              style: MasilPetType.prose.copyWith(fontSize: 15),
            ),
          ],
        ),
      );
    }

    final poi = _nextDiscoveryPoi(state, target.primaryCategory);
    final reward = const GrowthEngine().rewardFor(target.primaryCategory);

    return DashedBox(
      fill: MasilPetPalette.subtle,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HandNote('다음 발견 후보'),
          const SizedBox(height: MasilPetSpacing.sm),
          Text(
            poi == null
                ? '${target.primaryCategory.label} 산책지를 걸으면 새 친구를 만날 수 있어요.'
                : '${poi.title} · ${target.primaryCategory.label}'
                    '${_discoveryDistanceSuffix(state, poi)}',
            style: MasilPetType.prose.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          RewardChipRow(reward: reward),
          const SizedBox(height: 14),
          PaperButton.ghost(
            label: '지도에서 탐험하기',
            onPressed:
                state.isBusy ? null : () => onOpenMap(target.primaryCategory),
            expand: false,
            fontSize: 14,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryHintList extends StatelessWidget {
  const _DiscoveryHintList({required this.pois, required this.onOpenMap});

  final List<Poi> pois;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    if (pois.isEmpty) {
      return EmptyStateCard(
        note: '힌트 없음',
        title: '아직 등록된 산책지가 없어요',
        body: '현재 위치를 다시 확인하면 가까운 산책지 힌트를 볼 수 있어요.',
        actionLabel: '지도에서 다시 조회',
        onAction: onOpenMap,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '발견 힌트가 있는 산책지'),
        for (final (index, poi) in pois.indexed) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: masilPetCategoryColor(poi.category.label),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    masilPetCategoryMark(poi.category.label),
                    style: MasilPetType.rowTitle.copyWith(
                      fontSize: 13,
                      color: masilPetCategoryColor(poi.category.label),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(poi.title, style: MasilPetType.rowTitle),
                      const SizedBox(height: 2),
                      Text(
                        '${poi.category.label} · ${_poiSourceLabel(poi)}',
                        style: MasilPetType.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (index != pois.length - 1) const DashedRule(),
        ],
      ],
    );
  }
}

PetTemplate? _nextDiscoveryTemplate(MasilPetState state) {
  for (final template in state.templates) {
    if (!state.discoveredTemplateIds.contains(template.id)) {
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

String _discoveryDistanceSuffix(MasilPetState state, Poi poi) {
  if (!state.hasFreshVerifiedLocation) {
    return '';
  }
  final meters = state.currentLocation.distanceTo(poi.coordinates).round();
  if (meters >= 1000) {
    return ' · ${(meters / 1000).toStringAsFixed(1)}km';
  }
  return ' · ${meters}m';
}

String _poiSourceLabel(Poi poi) {
  return poi.tourApiContentId.startsWith('seed-')
      ? '기본 수록 산책지'
      : '한국관광공사 자료 연동';
}

String _dateLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}
