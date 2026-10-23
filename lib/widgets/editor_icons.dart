import 'package:flutter/material.dart';

/// Resolves persisted legacy code points to constant icons for tree shaking.
/// Stored work data is unchanged; unknown legacy icons use a category symbol.
IconData editorIcon(int? codePoint) {
  const supported = [
    Icons.weekend,
    Icons.table_restaurant,
    Icons.chair_alt,
    Icons.local_florist,
    Icons.image_outlined,
    Icons.emoji_nature,
    Icons.lightbulb_outline,
    Icons.highlight,
    Icons.wb_incandescent_outlined,
    Icons.texture,
    Icons.curtains,
    Icons.bed,
  ];
  for (final icon in supported) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.category;
}
