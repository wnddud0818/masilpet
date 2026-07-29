import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/link.dart';

import '../app_build_info.dart';
import '../models.dart';
import '../pet_assets.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/paper_kit.dart';
import '../widgets/paper_shell.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/reward_chip_row.dart';
import '../widgets/status_banner.dart';

final Uri _openStreetMapCopyrightUri =
    Uri.parse('https://www.openstreetmap.org/copyright');

/// 지도: where you are, what is within stamping distance, and the walk that
/// gets you to the next one.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  int? _lastCheckInCount;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);

    _watchForNewStamp(state.todayCheckInCount);

    final focus = _heroFocus(state);
    final nearby = _visibleNearbyPois(state);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: kPaperBodyPadding,
          sliver: ResponsiveSliverList(
            children: [
              _PaperMapFrame(state: state),
              const SizedBox(height: MasilPetSpacing.xl),
              _CategoryFilterBar(
                pois: state.pois,
                selected: state.mapCategoryFocus,
                onSelected: controller.setMapCategoryFocus,
              ),
              const SizedBox(height: MasilPetSpacing.xl),
              if (focus != null)
                _CheckInHero(
                  state: state,
                  focus: focus,
                  onCheckIn: state.isBusy
                      ? null
                      : () => controller.attemptCheckIn(focus.poi),
                  onRefreshLocation:
                      state.isBusy ? null : controller.useDeviceLocation,
                  onUseStarterLocation:
                      state.isBusy ? null : controller.useStarterKoreaLocation,
                )
              else
                _NoLocationHero(
                  onUseDeviceLocation:
                      state.isBusy ? null : controller.useDeviceLocation,
                  onUseStarterLocation:
                      state.isBusy ? null : controller.useStarterKoreaLocation,
                ),
              const SizedBox(height: MasilPetSpacing.xl),
              const StatusBanner(),
              const SizedBox(height: MasilPetSpacing.xl),
              _NearbyList(
                state: state,
                pois: nearby,
                onCheckIn: (poi) => controller.attemptCheckIn(poi),
                onRefreshLocation:
                    state.isBusy ? null : controller.useDeviceLocation,
              ),
              const SizedBox(height: MasilPetSpacing.xl),
              _RouteSection(
                state: state,
                onCheckIn: (poi) => controller.attemptCheckIn(poi),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The stamp animation belongs to the moment of verification, so it fires on
  /// the frame where today's count goes up.
  void _watchForNewStamp(int count) {
    final previous = _lastCheckInCount;
    _lastCheckInCount = count;
    if (previous == null || count <= previous) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showStampOverlay(context, dateLabel: _stampDateLabel(DateTime.now()));
      }
    });
  }
}

// ────────────────────────────────────────────────────────────────── the map ──

/// The live map, framed and warmed so it sits on the same page as everything
/// else. Tiles stay real; only the chrome becomes paper.
class _PaperMapFrame extends ConsumerStatefulWidget {
  const _PaperMapFrame({required this.state});

  final MasilPetState state;

  @override
  ConsumerState<_PaperMapFrame> createState() => _PaperMapFrameState();
}

class _PaperMapFrameState extends ConsumerState<_PaperMapFrame> {
  String? _selectedPoiId;

  @override
  void didUpdateWidget(covariant _PaperMapFrame oldWidget) {
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
    final selectedPoi = _poiById(state.pois, _selectedPoiId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth >= 700 ? 320.0 : 250.0;

        return PaperCard.frame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
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
                        backgroundColor: MasilPetPalette.canvas,
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
                        // Warms the tiles toward parchment without hiding them.
                        IgnorePointer(
                          child: ColoredBox(
                            color:
                                MasilPetPalette.canvas.withValues(alpha: 0.34),
                          ),
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: currentPoint,
                              radius: checkInRadiusMeters,
                              useRadiusInMeter: true,
                              color:
                                  MasilPetPalette.stamp.withValues(alpha: 0.08),
                              borderColor:
                                  MasilPetPalette.stamp.withValues(alpha: 0.55),
                              borderStrokeWidth: 1.2,
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
                                width: 84,
                                height: 58,
                                alignment: Alignment.topCenter,
                                child: _PaperPin(
                                  poi: poi,
                                  stamped: state.hasCheckedInToday(poi),
                                  inRange: _isInRange(state, poi),
                                  selected: selectedPoi?.id == poi.id,
                                  onTap: () => setState(
                                    () => _selectedPoiId = poi.id,
                                  ),
                                ),
                              ),
                            Marker(
                              point: currentPoint,
                              width: 48,
                              height: 48,
                              child: const _HerePin(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      left: 12,
                      top: 11,
                      child: _MapNote(
                        '${state.region.name} · 산책지 ${state.pois.length}곳',
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _MapNote(_locationFreshnessLabel(state)),
                    ),
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: _MapAttribution(),
                    ),
                  ],
                ),
              ),
              if (selectedPoi != null)
                _MapFocusPanel(
                  key: ValueKey('map-focus-${selectedPoi.id}'),
                  state: state,
                  poi: selectedPoi,
                  onCheckIn: state.isBusy
                      ? null
                      : () => controller.attemptCheckIn(selectedPoi),
                  onClose: () => setState(() => _selectedPoiId = null),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A map pin drawn as a hand-inked category seal.
class _PaperPin extends StatelessWidget {
  const _PaperPin({
    required this.poi,
    required this.stamped,
    required this.inRange,
    required this.selected,
    required this.onTap,
  });

  final Poi poi;
  final bool stamped;
  final bool inRange;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = masilPetCategoryColor(poi.category.label);
    final mark = masilPetCategoryMark(poi.category.label);
    final hot = inRange && !stamped;

    return Semantics(
      button: true,
      label: '${poi.title}, ${poi.category.label}'
          '${stamped ? ', 오늘 방문 완료' : ''}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hot)
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const PulseRing(size: 34),
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MasilPetPalette.stamp,
                          border: Border.all(
                            color: MasilPetPalette.paper,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          mark,
                          style: MasilPetType.rowTitle.copyWith(
                            fontSize: 13,
                            color: MasilPetPalette.paper,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MasilPetPalette.paper,
                    border: Border.all(
                      color: stamped
                          ? MasilPetPalette.forest
                          : (selected ? MasilPetPalette.ink : color),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    mark,
                    style: MasilPetType.bodySmall.copyWith(
                      fontSize: 11,
                      height: 1,
                      color: stamped ? MasilPetPalette.forest : color,
                    ),
                  ),
                ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: MasilPetPalette.paper.withValues(alpha: 0.82),
                  borderRadius: MasilPetRadii.tightBorder,
                ),
                child: Text(
                  poi.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MasilPetType.bodySmall.copyWith(
                    fontSize: 10.5,
                    height: 1.1,
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

/// Where you are standing right now.
class _HerePin extends StatelessWidget {
  const _HerePin();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '현재 위치',
      child: Stack(
        alignment: Alignment.center,
        children: [
          const PulseRing(
            size: 14,
            color: MasilPetPalette.ink,
            period: Duration(milliseconds: 2600),
          ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MasilPetPalette.ink,
              border: Border.all(color: MasilPetPalette.sheet, width: 2.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapNote extends StatelessWidget {
  const _MapNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: MasilPetPalette.paper.withValues(alpha: 0.8),
        border: Border.all(color: MasilPetPalette.outline),
        borderRadius: MasilPetRadii.tightBorder,
      ),
      child: Text(
        text,
        style: MasilPetType.microMono.copyWith(letterSpacing: 1.14),
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
            color: MasilPetPalette.paper.withValues(alpha: 0.86),
            borderRadius: MasilPetRadii.tightBorder,
            child: InkWell(
              borderRadius: MasilPetRadii.tightBorder,
              onTap: followLink,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: MasilPetType.microMono.copyWith(fontSize: 9),
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

/// The strip that slides under the map when a pin is tapped.
class _MapFocusPanel extends StatelessWidget {
  const _MapFocusPanel({
    super.key,
    required this.state,
    required this.poi,
    required this.onCheckIn,
    required this.onClose,
  });

  final MasilPetState state;
  final Poi poi;
  final VoidCallback? onCheckIn;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final stamped = state.hasCheckedInToday(poi);
    final inRange = _isInRange(state, poi);
    final distance = _distanceMeters(state, poi);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 14),
      decoration: const BoxDecoration(
        color: MasilPetPalette.paper,
        border: Border(top: BorderSide(color: MasilPetPalette.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poi.title, style: MasilPetType.rowTitle),
                const SizedBox(height: 3),
                Text(
                  '${poi.category.label}'
                  '${distance == null ? '' : ' · ${_distanceLabel(distance)}'}',
                  style: MasilPetType.caption,
                ),
                const SizedBox(height: 5),
                Text(
                  poi.shortDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MasilPetType.bodySmall.copyWith(
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 7),
                MonoChip(_poiSourceLabel(poi)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (stamped)
                const OutlineTag(label: '완료')
              else if (inRange)
                InkTag(label: '도장', onPressed: onCheckIn)
              else
                Text(
                  _gapLabel(state, poi),
                  textAlign: TextAlign.right,
                  style: MasilPetType.caption.copyWith(
                    fontSize: 11.5,
                    height: 1.35,
                    color: MasilPetPalette.faintWarm,
                  ),
                ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  minimumSize: const Size(40, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: Text(
                  '닫기',
                  style: MasilPetType.caption.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────── filters ──

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.pois,
    required this.selected,
    required this.onSelected,
  });

  final List<Poi> pois;
  final PoiCategory? selected;
  final ValueChanged<PoiCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = pois.map((poi) => poi.category).toSet().toList()
      ..sort((left, right) => left.index.compareTo(right.index));

    return FilterPillRow<PoiCategory?>(
      values: [null, ...categories],
      labelOf: (value) => value == null ? '전체' : value.label,
      selected: selected,
      onSelected: onSelected,
    );
  }
}

// ────────────────────────────────────────────────────────────────────── hero ──

/// What the hero card is currently about: the place you can stamp, the place
/// you just stamped, or the closest place you have not reached yet.
class _HeroFocus {
  const _HeroFocus({
    required this.poi,
    required this.stamped,
    required this.inRange,
    required this.reward,
  });

  final Poi poi;
  final bool stamped;
  final bool inRange;
  final CheckInReward? reward;
}

class _CheckInHero extends ConsumerWidget {
  const _CheckInHero({
    required this.state,
    required this.focus,
    required this.onCheckIn,
    required this.onRefreshLocation,
    required this.onUseStarterLocation,
  });

  final MasilPetState state;
  final _HeroFocus focus;
  final VoidCallback? onCheckIn;
  final VoidCallback? onRefreshLocation;
  final VoidCallback? onUseStarterLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final pet = state.activePet;
    final template =
        pet == null ? null : controller.templateFor(pet.templateId);
    final distance = _distanceMeters(state, focus.poi);

    if (focus.stamped) {
      return RiseIn(
        duration: MasilPetMotion.fast,
        child: PaperCard.stamped(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow(
                          '방문 인증 완료',
                          color: MasilPetPalette.forest,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          focus.poi.title,
                          style: MasilPetType.heroTitle.copyWith(fontSize: 24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  RoundStamp(
                    top: 'VISITED',
                    middle: '인증',
                    bottom: _shortDateLabel(DateTime.now()),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (focus.reward != null) RewardChipRow(reward: focus.reward!),
              const SizedBox(height: MasilPetSpacing.lg),
              _PetAside(
                template: template,
                emotion: 'happy',
                line: '여기 냄새 좋다! 알이 방금 톡, 하고 움직였어.',
              ),
            ],
          ),
        ),
      );
    }

    if (focus.inRange) {
      return PaperCard.stamped(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Eyebrow(
              '지금 여기 · ${distance == null ? '위치 확인 필요' : _distanceLabel(distance)}',
            ),
            const SizedBox(height: 7),
            Text(focus.poi.title, style: MasilPetType.heroTitle),
            const SizedBox(height: 6),
            Text(
              focus.poi.shortDescription,
              style: MasilPetType.bodySmall.copyWith(height: 1.65),
            ),
            const SizedBox(height: MasilPetSpacing.lg),
            _PetAside(
              template: template,
              emotion: 'excited',
              line: '여기 ${checkInRadiusMeters ~/ 1}m 안이야. 지금이야, 도장 찍자!',
            ),
            const SizedBox(height: MasilPetSpacing.lg),
            PaperButton.stamp(
              label: '여기에 도장 찍기',
              onPressed: onCheckIn,
              padding: const EdgeInsets.symmetric(
                horizontal: MasilPetSpacing.xl,
                vertical: 17,
              ),
            ),
          ],
        ),
      );
    }

    return PaperCard.stamped(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('가장 가까운 산책지'),
          const SizedBox(height: 7),
          Text(focus.poi.title, style: MasilPetType.heroTitle),
          const SizedBox(height: 6),
          Text(
            focus.poi.shortDescription,
            style: MasilPetType.bodySmall.copyWith(height: 1.65),
          ),
          const SizedBox(height: MasilPetSpacing.lg),
          _PetAside(
            template: template,
            emotion: 'neutral',
            line:
                '${_gapLabel(state, focus.poi).replaceAll('\n', ' ')}. 같이 갈래?',
          ),
          const SizedBox(height: MasilPetSpacing.lg),
          PaperButton.ghost(
            label: '현재 위치 확인하기',
            onPressed: onRefreshLocation,
            padding: const EdgeInsets.symmetric(
              horizontal: MasilPetSpacing.lg,
              vertical: 15,
            ),
          ),
          const SizedBox(height: MasilPetSpacing.sm),
          PaperButton.ghost(
            label: '전국 기본 지도 보기',
            onPressed: onUseStarterLocation,
            padding: const EdgeInsets.symmetric(
              horizontal: MasilPetSpacing.lg,
              vertical: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoLocationHero extends StatelessWidget {
  const _NoLocationHero({
    required this.onUseDeviceLocation,
    required this.onUseStarterLocation,
  });

  final VoidCallback? onUseDeviceLocation;
  final VoidCallback? onUseStarterLocation;

  @override
  Widget build(BuildContext context) {
    return PaperCard.stamped(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('위치가 필요해요'),
          const SizedBox(height: 7),
          Text('어디를 걷는지 알아야\n도장을 찍어요', style: MasilPetType.heroTitle),
          const SizedBox(height: 6),
          Text(
            '현재 위치를 확인하면 주변 ${checkInRadiusMeters ~/ 1}m 안의 산책지가 수첩에 뜹니다.',
            style: MasilPetType.bodySmall.copyWith(height: 1.65),
          ),
          const SizedBox(height: MasilPetSpacing.lg),
          PaperButton(
            label: '현재 위치 확인하기',
            onPressed: onUseDeviceLocation,
          ),
          const SizedBox(height: MasilPetSpacing.sm),
          PaperButton.ghost(
            label: '전국 기본 지도 보기',
            onPressed: onUseStarterLocation,
          ),
        ],
      ),
    );
  }
}

/// The pet's aside inside a hero card: sprite plus one line, dashed off.
class _PetAside extends StatelessWidget {
  const _PetAside({
    required this.template,
    required this.emotion,
    required this.line,
  });

  final PetTemplate? template;
  final String emotion;
  final String line;

  @override
  Widget build(BuildContext context) {
    final template = this.template;

    return DashedBox(
      fill: MasilPetPalette.canvas,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          if (template != null) ...[
            PixelSprite(
              asset: PetAssets.emotion(template.assetKey, emotion),
              size: 44,
              semanticLabel: template.name,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              line,
              style: MasilPetType.bubble.copyWith(
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────── the list ──

class _NearbyList extends StatelessWidget {
  const _NearbyList({
    required this.state,
    required this.pois,
    required this.onCheckIn,
    required this.onRefreshLocation,
  });

  final MasilPetState state;
  final List<Poi> pois;
  final ValueChanged<Poi> onCheckIn;
  final VoidCallback? onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitleRow(
          title: '주변 산책지',
          trailing: MonoButton(
            label: '위치 새로고침',
            onPressed: onRefreshLocation,
          ),
        ),
        if (pois.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              '이 조건에 맞는 산책지가 없어요.\n'
              '다른 분류를 고르거나 전국 기본 장소로 둘러볼 수 있어요.',
              style: MasilPetType.bodySmall,
            ),
          )
        else
          for (final poi in pois)
            _NearbyRow(
              state: state,
              poi: poi,
              onCheckIn: () => onCheckIn(poi),
            ),
      ],
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    required this.state,
    required this.poi,
    required this.onCheckIn,
  });

  final MasilPetState state;
  final Poi poi;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final color = masilPetCategoryColor(poi.category.label);
    final stamped = state.hasCheckedInToday(poi);
    final inRange = _isInRange(state, poi);
    final distance = _distanceMeters(state, poi);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Text(
                  masilPetCategoryMark(poi.category.label),
                  style: MasilPetType.rowTitle.copyWith(
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MasilPetType.rowTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${poi.category.label} · '
                      '${stamped ? '오늘 방문 완료' : (distance == null ? '위치 확인 필요' : _distanceLabel(distance))}',
                      style: MasilPetType.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (stamped)
                const OutlineTag(label: '완료')
              else if (inRange)
                InkTag(
                  label: '도장',
                  onPressed: state.isBusy ? null : onCheckIn,
                )
              else
                Text(
                  _gapLabel(state, poi),
                  textAlign: TextAlign.right,
                  style: MasilPetType.caption.copyWith(
                    fontSize: 11.5,
                    height: 1.35,
                    color: MasilPetPalette.faintWarm,
                  ),
                ),
            ],
          ),
        ),
        const DashedRule(),
      ],
    );
  }
}

/// 오늘의 산책 코스 — the recommended loop, numbered like the onboarding steps.
class _RouteSection extends StatelessWidget {
  const _RouteSection({required this.state, required this.onCheckIn});

  final MasilPetState state;
  final ValueChanged<Poi> onCheckIn;

  @override
  Widget build(BuildContext context) {
    final route = state.recommendedRoutePois;
    if (route.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('오늘의 산책 코스'),
        for (final (index, poi) in route.indexed) ...[
          _RouteStepCard(
            number: (index + 1).toString().padLeft(2, '0'),
            state: state,
            poi: poi,
            onCheckIn: () => onCheckIn(poi),
          ),
          if (index != route.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RouteStepCard extends StatelessWidget {
  const _RouteStepCard({
    required this.number,
    required this.state,
    required this.poi,
    required this.onCheckIn,
  });

  final String number;
  final MasilPetState state;
  final Poi poi;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final stamped = state.hasCheckedInToday(poi);
    final inRange = _isInRange(state, poi);
    final distance = _distanceMeters(state, poi);

    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                number,
                style: MasilPetType.metaMono.copyWith(
                  color:
                      stamped ? MasilPetPalette.forest : MasilPetPalette.stamp,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const DashedSpine(color: MasilPetPalette.outlineSoft),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(poi.title, style: MasilPetType.sectionTitle),
                  const SizedBox(height: 4),
                  Text(
                    '${poi.category.label} · '
                    '${stamped ? '오늘 방문 완료' : (distance == null ? '위치 확인 필요' : _distanceLabel(distance))}',
                    style: MasilPetType.bodySmall.copyWith(
                      fontSize: 13.5,
                      height: 1.6,
                    ),
                  ),
                  if (!stamped && inRange) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkTag(
                        label: '여기에 도장',
                        onPressed: state.isBusy ? null : onCheckIn,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────── plumbing ──

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

/// Nearby list, filtered by the category the user picked.
List<Poi> _visibleNearbyPois(MasilPetState state) {
  final focus = state.mapCategoryFocus;
  final nearby = state.nearbyPois;
  if (focus == null) {
    return nearby;
  }
  return nearby.where((poi) => poi.category == focus).toList(growable: false);
}

/// The hero prefers a place you can stamp right now, then the one you just
/// stamped, then whatever is closest.
_HeroFocus? _heroFocus(MasilPetState state) {
  final candidates = state.nearbyPois.isEmpty ? state.pois : state.nearbyPois;
  if (candidates.isEmpty) {
    return null;
  }

  for (final poi in candidates) {
    if (!state.hasCheckedInToday(poi) && _isInRange(state, poi)) {
      return _HeroFocus(poi: poi, stamped: false, inRange: true, reward: null);
    }
  }

  final todayCheckIns = state.todayCheckIns;
  if (todayCheckIns.isNotEmpty) {
    final latest = todayCheckIns.first;
    final poi = _poiById(state.pois, latest.poiId);
    if (poi != null) {
      return _HeroFocus(
        poi: poi,
        stamped: true,
        inRange: true,
        reward: latest.reward,
      );
    }
  }

  final nearest = state.nearestPoi ?? candidates.first;
  return _HeroFocus(
    poi: nearest,
    stamped: state.hasCheckedInToday(nearest),
    inRange: false,
    reward: null,
  );
}

bool _isInRange(MasilPetState state, Poi poi) {
  if (!state.hasFreshVerifiedLocation) {
    return false;
  }
  return state.currentLocation.distanceTo(poi.coordinates) <=
      checkInRadiusMeters;
}

int? _distanceMeters(MasilPetState state, Poi poi) {
  if (!state.hasFreshVerifiedLocation) {
    return null;
  }
  return state.currentLocation.distanceTo(poi.coordinates).round();
}

/// Where a place came from — bundled seed data or a synced TourAPI record.
String _poiSourceLabel(Poi poi) {
  if (poi.tourApiContentId.startsWith('seed-')) {
    return '전국 기본 장소';
  }
  return 'TourAPI ID ${poi.tourApiContentId}';
}

String _distanceLabel(int meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
  return '${meters}m';
}

/// How much further before this place comes into stamping range.
String _gapLabel(MasilPetState state, Poi poi) {
  final distance = _distanceMeters(state, poi);
  if (distance == null) {
    return '위치 확인\n필요해요';
  }
  final gap = (distance - checkInRadiusMeters).round();
  if (gap <= 0) {
    return '거의 다 왔어요';
  }
  return '${_distanceLabel(gap)}\n더 걸어요';
}

String _locationFreshnessLabel(MasilPetState state) {
  final verifiedAt = state.locationVerifiedAt;
  if (verifiedAt == null || !state.locationVerified) {
    return '위치 미확인';
  }
  final elapsed = DateTime.now().difference(verifiedAt);
  if (elapsed.inMinutes < 1) {
    return '위치 확인 방금';
  }
  if (elapsed.inMinutes < 60) {
    return '위치 확인 ${elapsed.inMinutes}분 전';
  }
  return '위치 확인 ${elapsed.inHours}시간 전';
}

String _shortDateLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month.$day';
}

String _stampDateLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}
