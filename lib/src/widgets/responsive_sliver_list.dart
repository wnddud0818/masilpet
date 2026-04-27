import 'package:flutter/widgets.dart';

class ResponsiveSliverList extends StatelessWidget {
  const ResponsiveSliverList({
    required this.children,
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate(children),
    );
  }
}
