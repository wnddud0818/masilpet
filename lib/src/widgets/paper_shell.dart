import 'package:flutter/material.dart';

import '../theme.dart';
import 'paper_kit.dart';

/// The width of the reading column, matching the design's `max-width:760px`
/// (padding included, so the text column itself is 716px).
const kPaperBodyMaxWidth = 760.0;

/// The page margin every tab body shares.
const kPaperBodyPadding = EdgeInsets.fromLTRB(22, 20, 22, 40);

/// Below this width the shell uses the bottom tab bar instead of a side rail.
const kPaperRailBreakpoint = 760.0;

/// One entry in the navigation, numbered like a table of contents.
class PaperNavItem {
  const PaperNavItem({
    required this.label,
    required this.number,
    required this.glyph,
    required this.tooltip,
    this.badge,
  });

  final String label;
  final String number;
  final PaperGlyphKind glyph;
  final String tooltip;
  final String? badge;
}

/// The page frame: dateline header, the reading column, and navigation.
///
/// Screens supply only their scrollable body; the header and navigation live
/// here so every tab shares one masthead.
class PaperShell extends StatelessWidget {
  const PaperShell({
    super.key,
    required this.dateLine,
    required this.title,
    required this.note,
    required this.items,
    required this.activeIndex,
    required this.onSelected,
    required this.body,
    this.railFooterLabel,
    this.railFooterValue,
    this.overlay,
  });

  final String dateLine;
  final String title;
  final String note;
  final List<PaperNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final String? railFooterLabel;
  final String? railFooterValue;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MasilPetPalette.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useRail = constraints.maxWidth >= kPaperRailBreakpoint;

          final main = Column(
            children: [
              PaperHeader(
                dateLine: dateLine,
                title: title,
                note: note,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kPaperBodyMaxWidth,
                    ),
                    child: body,
                  ),
                ),
              ),
              if (!useRail)
                PaperTabBar(
                  items: items,
                  activeIndex: activeIndex,
                  onSelected: onSelected,
                ),
            ],
          );

          final shell = useRail
              ? Row(
                  children: [
                    PaperNavRail(
                      items: items,
                      activeIndex: activeIndex,
                      onSelected: onSelected,
                      footerLabel: railFooterLabel,
                      footerValue: railFooterValue,
                    ),
                    Expanded(child: main),
                  ],
                )
              : main;

          return Stack(
            children: [
              Positioned.fill(child: SafeArea(child: shell)),
              if (overlay != null) Positioned.fill(child: overlay!),
              const Positioned.fill(child: GrainOverlay()),
            ],
          );
        },
      ),
    );
  }
}

/// The masthead: a monospaced dateline, the page title, and a margin note.
class PaperHeader extends StatelessWidget {
  const PaperHeader({
    super.key,
    required this.dateLine,
    required this.title,
    required this.note,
  });

  final String dateLine;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      decoration: const BoxDecoration(
        color: MasilPetPalette.canvas,
        border: Border(
          bottom: BorderSide(color: MasilPetPalette.shadowHard),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLine, style: MasilPetType.dateLine),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MasilPetType.pageTitle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: HandNote(
              note,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// The mobile tab bar: labels only, with a stamp-red dot marking the page.
class PaperTabBar extends StatelessWidget {
  const PaperTabBar({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onSelected,
  });

  final List<PaperNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      decoration: const BoxDecoration(
        color: MasilPetPalette.navSurface,
        border: Border(
          top: BorderSide(color: MasilPetPalette.outlineStrong),
        ),
      ),
      child: Row(
        children: [
          for (final (index, item) in items.indexed)
            Expanded(
              child: _PaperTab(
                item: item,
                active: index == activeIndex,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaperTab extends StatelessWidget {
  const _PaperTab({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final PaperNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = item.badge;
    final showBadge = !active && badge != null && badge.isNotEmpty;

    return Semantics(
      button: true,
      selected: active,
      label: item.tooltip,
      child: InkWell(
        onTap: () {
          MasilPetHaptics.select();
          onTap();
        },
        borderRadius: MasilPetRadii.tightBorder,
        child: Stack(
          clipBehavior: Clip.none,
          // Passthrough so the cell fills the Expanded slot; a loose fit would
          // shrink it to the label width and pin it to the Stack's top-left.
          fit: StackFit.passthrough,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.fromLTRB(2, 7, 2, 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PaperGlyph(
                    kind: item.glyph,
                    size: 19,
                    // The glyph carries the selected state now, so it takes the
                    // stamp red the old marker dot used to own.
                    color:
                        active ? MasilPetPalette.stamp : MasilPetPalette.faint,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: MasilPetFonts.serif,
                      fontSize: 13.5,
                      height: 1.2,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color:
                          active ? MasilPetPalette.ink : MasilPetPalette.faint,
                    ),
                  ),
                ],
              ),
            ),
            // Anchored to the cell's top-right corner so badges line up on one
            // grid regardless of how wide each label is.
            if (showBadge)
              Positioned(
                top: 2,
                right: 2,
                child: _NavBadge(badge),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: const BoxDecoration(
        color: MasilPetPalette.stamp,
        borderRadius: MasilPetRadii.pillBorder,
      ),
      child: Text(
        label,
        style: MasilPetType.microMono.copyWith(
          fontSize: 9,
          letterSpacing: 0,
          color: MasilPetPalette.paper,
        ),
      ),
    );
  }
}

/// The wide-layout side rail: a numbered table of contents plus the streak.
class PaperNavRail extends StatelessWidget {
  const PaperNavRail({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onSelected,
    this.footerLabel,
    this.footerValue,
  });

  final List<PaperNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onSelected;
  final String? footerLabel;
  final String? footerValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      decoration: const BoxDecoration(
        color: MasilPetPalette.navSurface,
        border: Border(
          right: BorderSide(color: MasilPetPalette.outlineStrong),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The nav items scroll on their own when the rail is wide but
          // short (e.g. a landscape phone), so the footer below always
          // stays visible instead of overflowing off the bottom.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, right: 8, bottom: 22),
                    child: BrandMark(
                      showTagline: false,
                      sealSize: 30,
                      wordmarkSize: 16,
                    ),
                  ),
                  for (final (index, item) in items.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _RailItem(
                        item: item,
                        active: index == activeIndex,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (footerLabel != null && footerValue != null) ...[
            const DashedRule(color: MasilPetPalette.outlineStrong),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HandNote(footerLabel!, fontSize: 20),
                  Text(
                    footerValue!,
                    style: MasilPetType.rowTitle.copyWith(
                      fontSize: 26,
                      color: MasilPetPalette.stamp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final PaperNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = item.badge;
    return Semantics(
      button: true,
      selected: active,
      label: item.tooltip,
      child: InkWell(
        onTap: () {
          MasilPetHaptics.select();
          onTap();
        },
        borderRadius: MasilPetRadii.smallBorder,
        hoverColor: active ? Colors.transparent : MasilPetPalette.hover,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: active ? MasilPetPalette.ink : null,
            borderRadius: MasilPetRadii.smallBorder,
          ),
          child: Row(
            children: [
              Text(
                item.number,
                style: MasilPetType.microMono.copyWith(
                  fontSize: 10,
                  letterSpacing: 0,
                  color: active
                      ? MasilPetPalette.sheet.withValues(alpha: 0.6)
                      : MasilPetPalette.muted.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: 9),
              PaperGlyph(
                kind: item.glyph,
                size: 17,
                color:
                    active ? MasilPetPalette.stampTint : MasilPetPalette.faint,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MasilPetType.rowTitle.copyWith(
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color:
                        active ? MasilPetPalette.sheet : MasilPetPalette.muted,
                  ),
                ),
              ),
              if (badge != null && badge.isNotEmpty)
                Text(
                  badge,
                  style: MasilPetType.microMono.copyWith(
                    fontSize: 10,
                    letterSpacing: 0,
                    color: active
                        ? MasilPetPalette.stampTint
                        : MasilPetPalette.stamp,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
