import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The size of the space this widget is actually laid out in.
///
/// Not `MediaQuery.sizeOf`, which reports the *window's* metrics: those are
/// the wrong number inside a smaller surface, and under `flutter test` they
/// don't follow `setSurfaceSize` at all — so any rule written against them
/// can't be tested and ships as whatever it happened to do. This walks to the
/// root of the render tree instead, which is the space `localToGlobal` maps
/// into and the one the layout genuinely used.
///
/// Returns null before the first layout, or if this context has no render
/// object yet — callers decide what a not-yet-measured tree should do.
Size? rootViewSize(BuildContext context) {
  final box = context.findRenderObject();
  if (box == null) return null;

  RenderObject node = box;
  while (node.parent != null) {
    node = node.parent!;
  }
  return switch (node) {
    RenderView(:final size) => size,
    RenderBox(:final size) => size,
    _ => null,
  };
}
