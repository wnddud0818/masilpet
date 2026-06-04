import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/section_header.dart';

class DexScreen extends ConsumerWidget {
  const DexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('부산 도감')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: ResponsiveSliverList(
            children: [
              _DexProgressCard(state: state),
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

class _DexPetsSection extends StatelessWidget {
  const _DexPetsSection({
    required this.templates,
    required this.discoveredTemplateIds,
  });

  final List<PetTemplate> templates;
  final Set<String> discoveredTemplateIds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '수집한 마실펫',
          detail: '${discoveredTemplateIds.length}/${templates.length}',
          icon: Icons.pets_outlined,
        ),
        for (final template in templates)
          _DexPetCard(
            template: template,
            discovered: discoveredTemplateIds.contains(template.id),
          ),
      ],
    );
  }
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
          title: 'TourAPI 카테고리 매핑',
          icon: Icons.route_outlined,
        ),
        if (pois.isEmpty)
          EmptyStateCard(
            icon: Icons.route_outlined,
            title: 'TourAPI 장소 데이터가 없습니다',
            body: '현재 위치를 다시 확인하면 가까운 여행지 매핑을 다시 볼 수 있습니다.',
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
                subtitle:
                    Text('${poi.category.label} · ${poi.category.tourApiHint}'),
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
              '지역별 체크인과 부화를 통해 부산 마실펫을 수집합니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hasUndiscovered) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => controller.setTab(0),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _DexAvatar(
              template: template,
              discovered: discovered,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          discovered ? template.name : '미발견 마실펫',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      _DiscoveryBadge(discovered: discovered),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${template.primaryCategory.label} · ${template.rarity}'),
                  const SizedBox(height: 6),
                  Text(
                    discovered
                        ? template.basePersonality
                        : '${template.primaryCategory.label} 장소를 더 탐험하면 만날 수 있습니다.',
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
    final color =
        discovered ? const Color(0xFF16A34A) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        discovered ? '발견' : '탐험 필요',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _DexAvatar extends StatelessWidget {
  const _DexAvatar({
    required this.template,
    required this.discovered,
  });

  final PetTemplate template;
  final bool discovered;

  @override
  Widget build(BuildContext context) {
    if (discovered) {
      return PetAvatar(template: template, size: 58);
    }

    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.38,
            child: PetAvatar(template: template, size: 58),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.86),
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
