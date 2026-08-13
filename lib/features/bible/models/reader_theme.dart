import 'package:flutter/material.dart';

enum ReaderThemeId {
  light,
  sepia,
  nature,
  sunset,
  dark,
  black,
  mauve,
  night,
}

class ReaderPalette {
  final ReaderThemeId id;
  final String label;
  final Color background;
  final Color surface;
  final Color text;
  final Color secondaryText;
  final bool isDark;

  const ReaderPalette({
    required this.id,
    required this.label,
    required this.background,
    required this.surface,
    required this.text,
    required this.secondaryText,
    required this.isDark,
  });
}

const readerPalettes = <ReaderPalette>[
  ReaderPalette(
    id: ReaderThemeId.light,
    label: 'Clair',
    background: Color(0xFFF8FAFC),
    surface: Colors.white,
    text: Color(0xFF172033),
    secondaryText: Color(0xFF64748B),
    isDark: false,
  ),
  ReaderPalette(
    id: ReaderThemeId.sepia,
    label: 'Sépia',
    background: Color(0xFFF4ECD8),
    surface: Color(0xFFFFF8E8),
    text: Color(0xFF4B3B2A),
    secondaryText: Color(0xFF796550),
    isDark: false,
  ),
  ReaderPalette(
    id: ReaderThemeId.nature,
    label: 'Nature',
    background: Color(0xFFEAF4E5),
    surface: Color(0xFFF5FAF2),
    text: Color(0xFF263B2B),
    secondaryText: Color(0xFF58705E),
    isDark: false,
  ),
  ReaderPalette(
    id: ReaderThemeId.sunset,
    label: 'Coucher de soleil',
    background: Color(0xFFFCE8D5),
    surface: Color(0xFFFFF4E9),
    text: Color(0xFF5B2F2F),
    secondaryText: Color(0xFF8A5B50),
    isDark: false,
  ),
  ReaderPalette(
    id: ReaderThemeId.dark,
    label: 'Sombre',
    background: Color(0xFF17191D),
    surface: Color(0xFF1B1D21),
    text: Color(0xFFF8FAFC),
    secondaryText: Color(0xFF94A3B8),
    isDark: true,
  ),
  ReaderPalette(
    id: ReaderThemeId.black,
    label: 'Noir',
    background: Colors.black,
    surface: Color(0xFF111111),
    text: Colors.white,
    secondaryText: Color(0xFFBDBDBD),
    isDark: true,
  ),
  ReaderPalette(
    id: ReaderThemeId.mauve,
    label: 'Mauve',
    background: Color(0xFFF1E8F5),
    surface: Color(0xFFFAF4FC),
    text: Color(0xFF402A4D),
    secondaryText: Color(0xFF765D80),
    isDark: false,
  ),
  ReaderPalette(
    id: ReaderThemeId.night,
    label: 'Nuit',
    background: Color(0xFF0B1930),
    surface: Color(0xFF142742),
    text: Color(0xFFDCE8FF),
    secondaryText: Color(0xFFA9BBD6),
    isDark: true,
  ),
];

ReaderPalette readerPaletteFor(ReaderThemeId id) =>
    readerPalettes.firstWhere((palette) => palette.id == id);
