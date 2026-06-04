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
              SectionHeader(
                title: '수집한 마실펫',
                detail:
                    '${state.discoveredTemplateIds.length}/${state.templates.length}',
                icon: Icons.pets_outlined,
              ),
              for (final template in state.templates)
                _DexPetCard(
                  template: template,
                  discovered: state.discoveredTemplateIds.contains(template.id),
                ),
              const SizedBox(height: 16),
              const SectionHeader(
                title: 'TourAPI 카테고리 매핑',
                icon: Icons.route_outlined,
              ),
              _PoiMappingCard(pois: state.pois.take(6).toList()),
            ],
          ),
        ),
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

class _DexProgressCard extends StatelessWidget {
  const _DexProgressCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final discovered = state.discoveredTemplateIds.length;
    final total = state.templates.length;

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
            Opacity(
              opacity: discovered ? 1 : 0.45,
              child: PetAvatar(template: template, size: 58),
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
        discovered ? '발견' : '잠김',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
