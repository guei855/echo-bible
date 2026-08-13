import 'package:flutter/material.dart';

class HighlightColorOption {
  final String key;
  final String name;
  final int colorValue;
  final bool isCustom;

  const HighlightColorOption({
    required this.key,
    required this.name,
    required this.colorValue,
    this.isCustom = false,
  });

  Color get color => Color(colorValue);

  Map<String, Object?> toJson() => {
        'key': key,
        'name': name,
        'color': colorValue,
      };

  factory HighlightColorOption.fromJson(Map<String, Object?> json) =>
      HighlightColorOption(
        key: json['key'] as String,
        name: json['name'] as String? ?? '',
        colorValue: json['color'] as int,
        isCustom: true,
      );
}
