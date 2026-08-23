import 'package:flutter/material.dart';

/// A group of [CircleIconButton]s pinned to a screen corner.
///
/// Uses [Wrap] rather than a [Column] so a cluster that outgrows the screen
/// spills into a second line instead of overflowing — the same reasoning as
/// `InventoryGrid` and `StagingBar`.
class CircleButtonCluster extends StatelessWidget {
  const CircleButtonCluster({
    super.key,
    required this.children,
    this.direction = Axis.vertical,
    this.growUpwards = false,
    this.spacing = 8,
  });

  final List<Widget> children;

  final Axis direction;

  /// Stacks from the bottom up. Set on a bottom-anchored cluster so added
  /// buttons grow away from the corner rather than pushing through it.
  final bool growUpwards;

  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      direction: direction,
      spacing: spacing,
      runSpacing: spacing,
      verticalDirection: growUpwards
          ? VerticalDirection.up
          : VerticalDirection.down,
      children: children,
    );
  }
}
