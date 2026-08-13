import 'dart:convert';

import 'package:echo_bible/features/bible/models/highlight_color_option.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HighlightPaletteService {
  const HighlightPaletteService._();

  static const _preferenceKey = 'custom_highlight_colors_v1';

  static const defaults = <HighlightColorOption>[
    HighlightColorOption(
      key: 'yellow',
      name: 'Jaune',
      colorValue: 0xFFFFC107,
    ),
    HighlightColorOption(
      key: 'green',
      name: 'Vert',
      colorValue: 0xFF4CAF50,
    ),
    HighlightColorOption(
      key: 'blue',
      name: 'Bleu',
      colorValue: 0xFF03A9F4,
    ),
    HighlightColorOption(
      key: 'pink',
      name: 'Rose',
      colorValue: 0xFFE91E63,
    ),
    HighlightColorOption(
      key: 'orange',
      name: 'Orange',
      colorValue: 0xFFFF9800,
    ),
  ];

  static const availableCustomColors = <int>[
    0xFF7E57C2,
    0xFF26A69A,
    0xFFEF5350,
    0xFF5C6BC0,
    0xFF8D6E63,
    0xFF78909C,
    0xFFD4E157,
    0xFFAB47BC,
  ];

  static Future<List<HighlightColorOption>> loadCustomColors() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_preferenceKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .map(
            (value) => HighlightColorOption.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveCustomColors(
    List<HighlightColorOption> colors,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _preferenceKey,
      jsonEncode(colors.map((color) => color.toJson()).toList()),
    );
  }

  static HighlightColorOption create(int colorValue, {String? legacyName}) {
    final hex = colorValue.toRadixString(16).padLeft(8, '0');
    return HighlightColorOption(
      key: 'custom_$hex',
      // `name` remains in persisted JSON for backwards compatibility only.
      name: legacyName?.trim() ?? '',
      colorValue: colorValue,
      isCustom: true,
    );
  }

  static Color? resolveColor(
    String? key, {
    Iterable<HighlightColorOption> customColors = const [],
  }) {
    if (key == null) return null;
    for (final color in [...defaults, ...customColors]) {
      if (color.key == key) return color.color;
    }
    if (key.startsWith('custom_')) {
      final value = int.tryParse(key.substring(7), radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }
}
