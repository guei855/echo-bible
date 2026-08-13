import 'package:echo_bible/core/services/settings_service.dart';
import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/models/reader_theme.dart';
import 'package:flutter/material.dart';

class ReaderSettingsSheet extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final double initialFontSize;
  final String initialFontFamily;
  final bool initialDarkMode;
  final ReaderThemeId? initialTheme;
  final double initialLineHeight;

  const ReaderSettingsSheet({
    super.key,
    required this.onSettingsChanged,
    required this.initialFontSize,
    required this.initialFontFamily,
    required this.initialDarkMode,
    this.initialTheme,
    this.initialLineHeight = 1.7,
  });

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  static const _fonts = ['Roboto', 'Lora', 'Merriweather', 'Open Sans'];
  late double _fontSize = widget.initialFontSize;
  late String _fontFamily = widget.initialFontFamily;
  late double _lineHeight = widget.initialLineHeight;
  late ReaderThemeId _theme = widget.initialTheme ??
      (widget.initialDarkMode ? ReaderThemeId.dark : ReaderThemeId.light);

  ReaderPalette get _palette => readerPaletteFor(_theme);

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final border = palette.secondaryText.withValues(alpha: 0.45);
    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Paramètres de lecture',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    color: palette.text,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Thème', style: TextStyle(color: palette.text)),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 0.92,
                ),
                itemCount: readerPalettes.length,
                itemBuilder: (context, index) {
                  final item = readerPalettes[index];
                  final selected = item.id == _theme;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _setTheme(item.id),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: item.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppColors.secondary : border,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: item.text,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              item.label,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: item.text,
                                fontSize: 10,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Divider(height: 28, color: border),
              _valueRow(
                label: 'Taille du texte',
                value: _fontSize.toInt().toString(),
                onRemove: _fontSize > 12 ? () => _setFontSize(-1) : null,
                onAdd: _fontSize < 32 ? () => _setFontSize(1) : null,
              ),
              const SizedBox(height: 12),
              Text('Police', style: TextStyle(color: palette.text)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue:
                    _fonts.contains(_fontFamily) ? _fontFamily : 'Roboto',
                dropdownColor: palette.surface,
                iconEnabledColor: palette.text,
                style: TextStyle(color: palette.text),
                items: _fonts
                    .map(
                      (font) => DropdownMenuItem(
                        value: font,
                        child: Text(
                          font,
                          style: TextStyle(
                            color: palette.text,
                            fontFamily: font,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _fontFamily = value);
                  await SettingsService.setFontFamily(value);
                  widget.onSettingsChanged();
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: palette.background,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.secondary),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Interligne',
                      style: TextStyle(color: palette.text),
                    ),
                  ),
                  Text(
                    _lineHeight.toStringAsFixed(1),
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _lineHeight,
                min: 1.2,
                max: 2.2,
                divisions: 10,
                activeColor: AppColors.secondary,
                inactiveColor: border,
                onChanged: (value) => setState(() => _lineHeight = value),
                onChangeEnd: (value) async {
                  await SettingsService.setLineHeight(value);
                  widget.onSettingsChanged();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueRow({
    required String label,
    required String value,
    required VoidCallback? onRemove,
    required VoidCallback? onAdd,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: _palette.text))),
        IconButton(
          onPressed: onRemove,
          color: _palette.text,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          value,
          style: TextStyle(
            color: _palette.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: onAdd,
          color: _palette.text,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Future<void> _setTheme(ReaderThemeId value) async {
    setState(() => _theme = value);
    await SettingsService.setReaderTheme(value);
    widget.onSettingsChanged();
  }

  Future<void> _setFontSize(double delta) async {
    setState(() => _fontSize += delta);
    await SettingsService.setFontSize(_fontSize);
    widget.onSettingsChanged();
  }
}
