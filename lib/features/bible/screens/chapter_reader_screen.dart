import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/core/services/settings_service.dart';
import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/data/database/database_helper.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/models/bible_version.dart';
import 'package:echo_bible/features/bible/models/highlight_color_option.dart';
import 'package:echo_bible/features/bible/models/reader_theme.dart';
import 'package:echo_bible/features/bible/models/text_marking.dart';
import 'package:echo_bible/features/bible/screens/note_editor_screen.dart';
import 'package:echo_bible/features/bible/screens/parallel_comparison_screen.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
import 'package:echo_bible/features/bible/services/highlight_palette_service.dart';
import 'package:echo_bible/features/bible/services/text_marking_service.dart';
import 'package:echo_bible/features/bible/services/verse_action_service.dart';
import 'package:echo_bible/features/bible/widgets/book_chapter_selector_sheet.dart';
import 'package:echo_bible/features/bible/widgets/reader_settings_sheet.dart';
import 'package:echo_bible/features/bible/widgets/reader_host_bindings.dart';
import 'package:echo_bible/features/bible/widgets/highlight_palette_sheet.dart';
import 'package:echo_bible/features/bible/widgets/annotated_selectable_text.dart';
import 'package:echo_bible/features/bible/widgets/verse_selection_action_bar.dart';
import 'package:echo_bible/features/study/widgets/verse_study_sheet.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/screens/personal_study_editor_screen.dart';
import 'package:echo_bible/features/study/widgets/study_destination_sheet.dart';
import 'package:echo_bible/features/bible/widgets/verse_quick_actions_sheet.dart';
import 'package:echo_bible/features/study/screens/cross_references_screen.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';

class ChapterReaderScreen extends StatefulWidget {
  final BibleBook book;
  final int initialChapter;
  final int? initialVerse;
  final int? initialVersionId;
  final List<Map<String, dynamic>>? initialVerses;

  const ChapterReaderScreen({
    super.key,
    required this.book,
    this.initialChapter = 1,
    this.initialVerse,
    this.initialVersionId,
    this.initialVerses,
  });

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _PartialTextSelection {
  final int verseId;
  final int verseNumber;
  final int start;
  final int end;
  final String text;

  const _PartialTextSelection({
    required this.verseId,
    required this.verseNumber,
    required this.start,
    required this.end,
    required this.text,
  });
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  late int _currentChapter;
  List<Map<String, dynamic>> _verses = [];
  List<BibleVersion> _versions = [];
  int _selectedVersionId = 1;
  Map<int, String> _highlightColors = {};
  Map<int, List<TextMarking>> _textMarkings = {};
  Map<int, String> _notes = {};
  Map<int, String> _noteTitles = {};
  Set<int> _favoriteVerseIds = {};
  final Set<int> _selectedVerseNumbers = {};
  List<HighlightColorOption> _customHighlightColors = const [];
  bool _isLoading = true;
  double _fontSize = 18;
  String _fontFamily = 'Roboto';
  double _lineHeight = 1.7;
  ReaderThemeId _readerTheme = ReaderThemeId.light;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {};
  int? _focusedVerseNumber;
  _PartialTextSelection? _partialSelection;

  ReaderPalette get _palette => readerPaletteFor(_readerTheme);
  bool get _isDarkMode => _palette.isDark;

  bool get _selectionContainsHighlight => _verses.any(
        (verse) =>
            _selectedVerseNumbers.contains(verse['verse_number'] as int) &&
            (_highlightColors.containsKey(verse['id'] as int) ||
                (_textMarkings[verse['verse_number'] as int] ?? const []).any(
                    (marking) => marking.type == TextMarkingType.highlight)),
      );

  bool get _selectionIsFavorite {
    final selectedIds = _verses
        .where((verse) =>
            _selectedVerseNumbers.contains(verse['verse_number'] as int))
        .map((verse) => verse['id'] as int)
        .toList();
    return selectedIds.isNotEmpty &&
        selectedIds.every(_favoriteVerseIds.contains);
  }

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialChapter;
    _focusedVerseNumber = widget.initialVerse;
    if (widget.initialVerses == null) {
      _initializeVersions();
    } else {
      _verses = widget.initialVerses!;
      _isLoading = false;
      _scheduleInitialVersePosition();
    }
    _loadReaderSettings();
    _loadHighlightPalette();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHighlightPalette() async {
    final colors = await HighlightPaletteService.loadCustomColors();
    if (!mounted) return;
    setState(() => _customHighlightColors = colors);
  }

  Future<void> _initializeVersions() async {
    try {
      final versions = await BibleVersionRepository.getInstalledVersions();
      final savedId =
          await BibleVersionRepository.getSelectedVersionId(versions);
      if (!mounted) return;
      final tabVersionId = widget.initialVersionId ??
          ReaderHostBindings.maybeRead(context)?.initialVersionId;
      final selectedId = versions.any(
        (version) => version.id == tabVersionId,
      )
          ? tabVersionId!
          : savedId;
      setState(() {
        _versions = versions;
        _selectedVersionId = selectedId;
      });
    } catch (_) {
      // La version historique reste lisible si les métadonnées sont absentes.
    }
    await _loadVersesForChapter(_currentChapter);
  }

  Future<void> _loadReaderSettings() async {
    final fontSize = await SettingsService.getFontSize();
    final fontFamily = await SettingsService.getFontFamily();
    final lineHeight = await SettingsService.getLineHeight();
    final readerTheme = await SettingsService.getReaderTheme();
    if (!mounted) return;
    setState(() {
      _fontSize = fontSize;
      _fontFamily = fontFamily;
      _lineHeight = lineHeight;
      _readerTheme = readerTheme;
    });
  }

  Future<void> _loadVersesForChapter(int chapterNumber) async {
    setState(() {
      _isLoading = true;
      _currentChapter = chapterNumber;
      _selectedVerseNumbers.clear();
    });
    ReaderHostBindings.maybeRead(context)?.onChapterChanged(chapterNumber);

    final db = await DatabaseHelper.instance.database;
    final result = await BibleVersionRepository.getChapter(
      bookId: widget.book.id,
      chapterNumber: chapterNumber,
      versionId: _selectedVersionId,
    );
    try {
      await DatabaseService.saveReadingHistory(
        widget.book.id,
        chapterNumber,
        chapterNumber == widget.initialChapter ? widget.initialVerse ?? 1 : 1,
        versionId: _selectedVersionId,
      );
    } catch (_) {}

    final verseIds = result.map((verse) => verse['id'] as int).toList();
    final highlights = verseIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await db.query(
            'highlights',
            where:
                'verse_id IN (${List.filled(verseIds.length, '?').join(', ')})',
            whereArgs: verseIds,
          );
    final markings = await const TextMarkingService().forChapter(
      bookId: widget.book.id,
      chapter: chapterNumber,
      versionId: _selectedVersionId,
    );
    final loadedMarkings = <int, List<TextMarking>>{};
    for (final marking in markings) {
      loadedMarkings.putIfAbsent(marking.verseNumber, () => []).add(marking);
    }
    final notes = verseIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await db.query(
            'notes',
            where:
                'verse_id IN (${List.filled(verseIds.length, '?').join(', ')})',
            whereArgs: verseIds,
            orderBy: 'id DESC',
          );
    final loadedNotes = <int, String>{};
    final loadedNoteTitles = <int, String>{};
    for (final note in notes) {
      final verseId = note['verse_id'] as int;
      loadedNotes.putIfAbsent(verseId, () => note['note'] as String);
      loadedNoteTitles.putIfAbsent(
        verseId,
        () => note['title'] as String? ?? '',
      );
    }
    final favorites = verseIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await db.query(
            'favorites',
            where:
                'verse_id IN (${List.filled(verseIds.length, '?').join(', ')})',
            whereArgs: verseIds,
          );

    if (!mounted) return;
    setState(() {
      _verses = result;
      _highlightColors = {
        for (final highlight in highlights)
          highlight['verse_id'] as int: highlight['color'] as String,
      };
      _textMarkings = loadedMarkings;
      _notes = loadedNotes;
      _noteTitles = loadedNoteTitles;
      _favoriteVerseIds =
          favorites.map((favorite) => favorite['verse_id'] as int).toSet();
      _isLoading = false;
    });
    _scheduleInitialVersePosition();
  }

  void _scheduleInitialVersePosition() {
    final verse = _focusedVerseNumber;
    if (verse == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final approximate = (verse - 1) * 72.0;
      _scrollController.jumpTo(
        approximate.clamp(0, _scrollController.position.maxScrollExtent),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = _verseKeys[verse]?.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            alignment: .22,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _palette.background;
    final textColor = _palette.text;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _verses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aucun verset trouvé pour ${widget.book.name} chapitre $_currentChapter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                )
              : GestureDetector(
                  onHorizontalDragEnd: _handleChapterSwipe,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _verses.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildAudioControl();
                      index--;
                      final verse = _verses[index];
                      final verseId = verse['id'] as int;
                      final verseNumber = verse['verse_number'] as int;
                      final highlightColor = _highlightColors[verseId];
                      final note = _notes[verseId];
                      final noteTitle = _noteTitles[verseId];
                      final isFavorite = _favoriteVerseIds.contains(verseId);
                      final usesDefaultText =
                          (verse['uses_default_text'] as int? ?? 0) == 1 &&
                              _selectedVersionId != 1;

                      return GestureDetector(
                        key: Key('verse-$verseNumber'),
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () => _selectVerse(verseNumber),
                        onTap: () => _selectedVerseNumbers.isEmpty
                            ? _showVerseActions(verse)
                            : _toggleVerseSelection(verseNumber),
                        child: AnimatedContainer(
                          key: _verseKeys.putIfAbsent(
                            verseNumber,
                            GlobalKey.new,
                          ),
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _verseBackground(
                              highlightColor,
                              _selectedVerseNumbers.contains(verseNumber),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: _selectedVerseNumbers.contains(verseNumber)
                                ? Border.all(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  )
                                : _focusedVerseNumber == verseNumber
                                    ? Border.all(
                                        color: AppColors.secondary,
                                        width: 1.5,
                                      )
                                    : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          key: Key('verse-number-$verseNumber'),
                                          onTap: () => _toggleVerseSelection(
                                              verseNumber),
                                          onLongPress: () =>
                                              _selectVerse(verseNumber),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                right: 5, top: 3),
                                            child: Text(
                                              '$verseNumber',
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: AnnotatedSelectableText(
                                            text:
                                                verse['text'] as String? ?? '',
                                            style: _readerTextStyle(textColor),
                                            markings:
                                                _textMarkings[verseNumber] ??
                                                    const [],
                                            resolveColor: _markingColor,
                                            onSelectionChanged: (selection) =>
                                                _rememberPartialSelection(
                                                    verse, selection),
                                            contextMenuBuilder:
                                                (menuContext, editableState) =>
                                                    _buildTextSelectionMenu(
                                              menuContext,
                                              editableState,
                                              verse,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (note != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Material(
                                          color: AppColors.orange.withValues(
                                            alpha: _isDarkMode ? 0.18 : 0.10,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            onTap: () => _openNoteEditor(verse),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 8,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .sticky_note_2_outlined,
                                                    size: 17,
                                                    color: AppColors.orange,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      noteTitle?.isNotEmpty ??
                                                              false
                                                          ? '$noteTitle\n$note'
                                                          : note,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: textColor,
                                                        fontSize: 13,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.edit_outlined,
                                                    size: 16,
                                                    color: AppColors.orange,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isFavorite)
                                const Padding(
                                  padding: EdgeInsets.only(left: 2),
                                  child: Icon(
                                    Icons.favorite,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              if (usesDefaultText)
                                Tooltip(
                                  message:
                                      'Ce verset utilise le texte LSG en remplacement.',
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Text(
                                      'LSG',
                                      style: TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: _selectedVerseNumbers.isEmpty
          ? null
          : VerseSelectionActionBar(
              selectionCount: _selectedVerseNumbers.length,
              onHighlight: _showHighlightColorSheet,
              onUnderline: _showUnderlineColorSheet,
              onNote: _selectedVerseNumbers.length == 1
                  ? () => _openNoteEditor(_selectedVerses.first)
                  : null,
              isFavorite: _selectionIsFavorite,
              onFavorite: _toggleFavorites,
              onCopy: _copySelectedVerses,
              onShare: _shareSelectedVerses,
              onCompare: _openComparison,
              onStudy: () => _openVerseStudy(_selectedVerses.first),
              onAddToStudy: _addSelectedVersesToStudy,
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_selectedVerseNumbers.isNotEmpty) {
      final count = _selectedVerseNumbers.length;
      return AppBar(
        key: const Key('verse-selection-app-bar'),
        leading: IconButton(
          tooltip: 'Fermer la sélection',
          onPressed: _clearSelection,
          icon: const Icon(Icons.close),
        ),
        title: Text(
          count == 1 ? '1 verset sélectionné' : '$count versets sélectionnés',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    }
    return AppBar(
      title: InkWell(
        onTap: _showBookSelector,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${widget.book.name} $_currentChapter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        if (_versions.isNotEmpty)
          PopupMenuButton<int>(
            tooltip: 'Changer de version',
            initialValue: _selectedVersionId,
            onSelected: _selectVersion,
            itemBuilder: (context) => [
              const PopupMenuItem<int>(
                enabled: false,
                child: Text('Installées',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final version in _versions)
                PopupMenuItem<int>(
                  value: version.id,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          version.abbreviation,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(child: Text(version.name)),
                      if (version.id == _selectedVersionId)
                        const Icon(Icons.check_rounded, size: 19),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<int>(
                value: -1,
                child: Row(
                  children: [
                    Icon(Icons.add_rounded),
                    SizedBox(width: 8),
                    Text('Télécharger une version'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    _selectedVersion.abbreviation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
        PopupMenuButton<String>(
          key: const Key('reader-more-menu'),
          tooltip: 'Plus d’options',
          onSelected: (value) {
            switch (value) {
              case 'parallel':
                _openChapterComparison();
              case 'settings':
                _showReaderSettings();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'parallel',
              enabled: _versions.length >= 2,
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.view_column_outlined),
                title: Text('Affichage parallèle'),
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.text_fields_rounded),
                title: Text('Taille et affichage du texte'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _selectedVerses {
    final selected = _verses
        .where(
          (verse) =>
              _selectedVerseNumbers.contains(verse['verse_number'] as int),
        )
        .toList();
    selected.sort(
      (a, b) => (a['verse_number'] as int).compareTo(
        b['verse_number'] as int,
      ),
    );
    return selected;
  }

  void _selectVerse(int verseNumber) {
    setState(() => _selectedVerseNumbers.add(verseNumber));
  }

  void _toggleVerseSelection(int verseNumber) {
    setState(() {
      if (!_selectedVerseNumbers.remove(verseNumber)) {
        _selectedVerseNumbers.add(verseNumber);
      }
    });
  }

  void _clearSelection() => setState(_selectedVerseNumbers.clear);

  String _selectedText() => _selectedVerses
      .map(
        (verse) => '${verse['verse_number']} ${verse['text'] as String? ?? ''}',
      )
      .join('\n');

  Future<void> _copySelectedVerses() async {
    final verses = _selectedVerses;
    if (verses.isEmpty) return;
    final label = verses.length == 1
        ? '${widget.book.name} $_currentChapter:${verses.first['verse_number']}'
        : '${widget.book.name} $_currentChapter:'
            '${verses.first['verse_number']}-${verses.last['verse_number']}';
    await VerseActionService.copyText('« ${_selectedText()} »\n$label');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sélection copiée.')),
    );
  }

  Future<void> _shareSelectedVerses() async {
    final verses = _selectedVerses;
    if (verses.isEmpty) return;
    final label = verses.length == 1
        ? '${widget.book.name} $_currentChapter:${verses.first['verse_number']}'
        : '${widget.book.name} $_currentChapter:'
            '${verses.first['verse_number']}-${verses.last['verse_number']}';
    await VerseActionService.shareText(
      '« ${_selectedText()} »\n$label\n\nPartagé via Echo Bible',
    );
  }

  BibleVersion get _selectedVersion => _versions.firstWhere(
        (version) => version.id == _selectedVersionId,
        orElse: () => _versions.first,
      );

  Future<void> _selectVersion(int versionId) async {
    if (versionId == -1) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DownloadManagerScreen(
            initialCategory: ResourceCategory.bible,
            initialLanguage: ResourceLanguage.fr,
          ),
        ),
      );
      if (!mounted) return;
      final versions = await BibleVersionRepository.getInstalledVersions();
      if (!mounted) return;
      setState(() => _versions = versions);
      return;
    }
    if (versionId == _selectedVersionId) return;
    final previousOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    setState(() => _selectedVersionId = versionId);
    ReaderHostBindings.maybeRead(context)?.onVersionChanged(versionId);
    await BibleVersionRepository.setActiveVersion(versionId);
    if (!mounted) return;
    await _loadVersesForChapter(_currentChapter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final maximum = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(previousOffset.clamp(0.0, maximum));
    });
  }

  void _openComparison() {
    final selected = _selectedVerseNumbers.toList()..sort();
    final verse = selected.isNotEmpty ? selected.first : 1;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParallelComparisonScreen(
          book: widget.book,
          chapter: _currentChapter,
          verse: verse,
          verseEnd: selected.isEmpty ? null : selected.last,
          initialVersionId: _selectedVersionId,
        ),
      ),
    );
  }

  void _openChapterComparison() {
    if (_verses.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParallelComparisonScreen(
          book: widget.book,
          chapter: _currentChapter,
          verse: _verses.first['verse_number'] as int,
          verseEnd: _verses.last['verse_number'] as int,
          initialVersionId: _selectedVersionId,
        ),
      ),
    );
  }

  void _openVerseStudy(Map<String, dynamic> verse) {
    final selected = _selectedVerseNumbers.toList()..sort();
    VerseStudySheet.show(
      context,
      book: widget.book,
      chapter: _currentChapter,
      versionId: _selectedVersionId,
      initialVerseNumber: verse['verse_number'] as int,
      selectedVerseStart: selected.isEmpty ? null : selected.first,
      selectedVerseEnd: selected.isEmpty ? null : selected.last,
      selectedText: _partialSelection?.verseNumber == verse['verse_number']
          ? _partialSelection?.text
          : null,
      selectedTextStart: _partialSelection?.verseNumber == verse['verse_number']
          ? _partialSelection?.start
          : null,
      selectedTextEnd: _partialSelection?.verseNumber == verse['verse_number']
          ? _partialSelection?.end
          : null,
      verses: _verses
          .map(
            (item) => VerseStudyTarget(
              verseId: item['id'] as int,
              verseNumber: item['verse_number'] as int,
              verseText: item['text'] as String? ?? '',
            ),
          )
          .toList(),
    );
  }

  void _rememberPartialSelection(
    Map<String, dynamic> verse,
    TextSelection selection,
  ) {
    if (!selection.isValid || selection.isCollapsed) return;
    final text = verse['text'] as String? ?? '';
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    if (start >= end) return;
    _partialSelection = _PartialTextSelection(
      verseId: verse['id'] as int,
      verseNumber: verse['verse_number'] as int,
      start: start,
      end: end,
      text: text.substring(start, end),
    );
  }

  Widget _buildTextSelectionMenu(
    BuildContext menuContext,
    EditableTextState editableState,
    Map<String, dynamic> verse,
  ) {
    _rememberPartialSelection(verse, editableState.textEditingValue.selection);
    void closeThen(Future<void> Function() action) {
      ContextMenuController.removeAny();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) action();
      });
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableState.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: 'Étudier',
          onPressed: () => closeThen(() async => _openVerseStudy(verse)),
        ),
        ContextMenuButtonItem(
          label: 'Surligner',
          onPressed: () => closeThen(
            () => _showPartialMarkingPalette(TextMarkingType.highlight),
          ),
        ),
        ContextMenuButtonItem(
          label: 'Souligner',
          onPressed: () => closeThen(
            () => _showPartialMarkingPalette(TextMarkingType.underline),
          ),
        ),
        ContextMenuButtonItem(
          label: 'Note',
          onPressed: () => closeThen(() => _openNoteEditor(verse)),
        ),
        ContextMenuButtonItem(
          label: 'Copier',
          onPressed: () => closeThen(() async {
            final selection = _partialSelection;
            if (selection != null) {
              await VerseActionService.copyText(selection.text);
            }
          }),
        ),
        ContextMenuButtonItem(
          label: 'Partager',
          onPressed: () => closeThen(() async {
            final selection = _partialSelection;
            if (selection != null) {
              await VerseActionService.shareText(
                '« ${selection.text} »\n${widget.book.name} '
                '$_currentChapter:${selection.verseNumber}\n\nPartagé via Echo Bible',
              );
            }
          }),
        ),
      ],
    );
  }

  Future<void> _showVerseActions(Map<String, dynamic> verse) async {
    final verseNumber = verse['verse_number'] as int;
    final verseText = verse['text'] as String? ?? '';
    final action = await VerseQuickActionsSheet.show(
      context,
      reference: '${widget.book.name} $_currentChapter:$verseNumber',
      verseText: verseText,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case VerseQuickAction.copy:
        await VerseActionService.copyVerse(
          widget.book.name,
          _currentChapter,
          verseNumber,
          verseText,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verset copié.')),
        );
      case VerseQuickAction.share:
        await VerseActionService.shareVerse(
          widget.book.name,
          _currentChapter,
          verseNumber,
          verseText,
        );
      case VerseQuickAction.highlight:
        setState(() => _selectedVerseNumbers
          ..clear()
          ..add(verseNumber));
        _showHighlightColorSheet();
      case VerseQuickAction.note:
        await _openNoteEditor(verse);
      case VerseQuickAction.favorite:
        setState(() => _selectedVerseNumbers
          ..clear()
          ..add(verseNumber));
        await _toggleFavorites();
      case VerseQuickAction.compare:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ParallelComparisonScreen(
              book: widget.book,
              chapter: _currentChapter,
              verse: verseNumber,
            ),
          ),
        );
      case VerseQuickAction.crossReferences:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CrossReferencesScreen(
              sourceBook: widget.book.id,
              sourceBookName: widget.book.name,
              sourceChapter: _currentChapter,
              sourceVerse: verseNumber,
              sourceVersionId: _selectedVersionId,
            ),
          ),
        );
      case VerseQuickAction.study:
        _openVerseStudy(verse);
      case VerseQuickAction.addToStudy:
        await _addVersesToStudy([verse]);
    }
  }

  Future<void> _addSelectedVersesToStudy() =>
      _addVersesToStudy(_selectedVerses);

  Future<void> _addVersesToStudy(
    List<Map<String, dynamic>> verses,
  ) async {
    if (verses.isEmpty) return;
    final start = verses.first['verse_number'] as int;
    final end = verses.last['verse_number'] as int;
    final reference = '${widget.book.name} $_currentChapter:$start'
        '${end == start ? '' : '-$end'}';
    final now = DateTime.now();
    final block = StudyBlock(
      id: '${now.microsecondsSinceEpoch}-reader',
      type: start == end ? StudyBlockType.verse : StudyBlockType.verseRange,
      position: 0,
      payload: {
        'translationId': _selectedVersionId,
        'translationLabel': _selectedVersion.abbreviation,
        'bookId': widget.book.id,
        'bookName': widget.book.name,
        'chaptersCount': widget.book.chaptersCount,
        'chapter': _currentChapter,
        'verseStart': start,
        'verseEnd': end,
        'reference': reference,
        'text': verses
            .map((item) => '${item['verse_number']} ${item['text']}')
            .join('\n'),
      },
      createdAt: now,
      updatedAt: now,
    );
    final study = await StudyDestinationSheet.show(
      context,
      block,
      reference: reference,
    );
    if (!mounted || study == null) return;
    _clearSelection();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalStudyEditorScreen(
          study: study,
          openingBlockId: block.id,
          openingMessage: '$reference ajouté.',
        ),
      ),
    );
  }

  TextStyle _readerTextStyle(Color color) {
    final style = TextStyle(
      color: color,
      fontSize: _fontSize,
      height: _lineHeight,
    );
    switch (_fontFamily) {
      case 'Lora':
        return GoogleFonts.lora(textStyle: style);
      case 'Merriweather':
        return GoogleFonts.merriweather(textStyle: style);
      case 'Open Sans':
        return GoogleFonts.openSans(textStyle: style);
      default:
        return GoogleFonts.roboto(textStyle: style);
    }
  }

  Color _markingColor(String colorKey, {required bool background}) {
    final color = HighlightPaletteService.resolveColor(
          colorKey,
          customColors: _customHighlightColors,
        ) ??
        AppColors.secondary;
    return background
        ? color.withValues(alpha: _isDarkMode ? .30 : .36)
        : color;
  }

  void _showReaderSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderSettingsSheet(
        initialFontSize: _fontSize,
        initialFontFamily: _fontFamily,
        initialDarkMode: _isDarkMode,
        initialTheme: _readerTheme,
        initialLineHeight: _lineHeight,
        onSettingsChanged: _loadReaderSettings,
      ),
    );
  }

  Widget _buildAudioControl() => Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: OutlinedButton.icon(
            key: const Key('reader-audio-control'),
            onPressed: _showAudioBibleInfo,
            icon: const Icon(Icons.headphones_rounded, size: 19),
            label: const Text('Audio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: _palette.surface,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      );

  void _showAudioBibleInfo() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: ListTile(
          contentPadding: EdgeInsets.fromLTRB(24, 8, 24, 24),
          leading: CircleAvatar(
            child: Icon(Icons.headphones_rounded),
          ),
          title: Text(
            'Audio Bible',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'La lecture audio sera disponible ici dès que les fichiers et leurs licences auront été intégrés.',
          ),
        ),
      ),
    );
  }

  void _handleChapterSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 300) return;
    final nextChapter =
        velocity < 0 ? _currentChapter + 1 : _currentChapter - 1;
    if (nextChapter < 1 || nextChapter > widget.book.chaptersCount) return;
    _loadVersesForChapter(nextChapter);
  }

  Future<void> _toggleFavorites() async {
    final selectedVerses = _verses
        .where(
          (verse) =>
              _selectedVerseNumbers.contains(verse['verse_number'] as int),
        )
        .toList();
    final selectedIds =
        selectedVerses.map((verse) => verse['id'] as int).toSet();
    final shouldRemove = selectedIds.every(_favoriteVerseIds.contains);
    final previousFavorites = Set<int>.from(_favoriteVerseIds);
    setState(() {
      if (shouldRemove) {
        _favoriteVerseIds.removeAll(selectedIds);
      } else {
        _favoriteVerseIds.addAll(selectedIds);
      }
    });
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((transaction) async {
        for (final verseId in selectedIds) {
          if (shouldRemove) {
            await transaction.delete(
              'favorites',
              where: 'verse_id = ?',
              whereArgs: [verseId],
            );
          } else if (!previousFavorites.contains(verseId)) {
            await transaction.insert('favorites', {
              'verse_id': verseId,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      });
    } on Object {
      if (!mounted) return;
      setState(() => _favoriteVerseIds = previousFavorites);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de modifier les favoris.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shouldRemove ? 'Favori(s) retiré(s).' : 'Ajouté aux favoris.',
        ),
      ),
    );
  }

  Future<void> _openNoteEditor(Map<String, dynamic> verse) async {
    final verseId = verse['id'] as int;
    final verseNumber = verse['verse_number'] as int;
    final partial = _partialSelection?.verseNumber == verseNumber
        ? _partialSelection
        : null;
    final result = await Navigator.push<NoteScreenResult>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          reference: '${widget.book.name} $_currentChapter:$verseNumber',
          verseText: partial?.text ?? verse['text'] as String? ?? '',
          initialTitle: _noteTitles[verseId] ?? '',
          initialDescription: _notes[verseId] ?? '',
        ),
      ),
    );
    if (!mounted || result == null) return;

    final db = await DatabaseHelper.instance.database;
    if (result.action == NoteScreenAction.delete) {
      await db.delete('notes', where: 'verse_id = ?', whereArgs: [verseId]);
      if (!mounted) return;
      setState(() {
        _notes.remove(verseId);
        _noteTitles.remove(verseId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note supprimée.')),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();
    final updated = await db.update(
      'notes',
      {
        'title': result.title,
        'note': result.description,
        'updated_at': now,
      },
      where: 'verse_id = ?',
      whereArgs: [verseId],
    );
    if (updated == 0) {
      await db.insert('notes', {
        'verse_id': verseId,
        'title': result.title,
        'note': result.description,
        'version_id': _selectedVersionId,
        'start_offset': partial?.start,
        'end_offset': partial?.end,
        'selected_text': partial?.text,
        'created_at': now,
        'updated_at': now,
      });
    }
    if (!mounted) return;
    setState(() {
      _notes[verseId] = result.description;
      _noteTitles[verseId] = result.title;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(updated == 0 ? 'Note enregistrée.' : 'Note modifiée.')),
    );
  }

  Color _colorForHighlight(String? color) {
    final resolved = HighlightPaletteService.resolveColor(
      color,
      customColors: _customHighlightColors,
    );
    if (resolved == null) return Colors.transparent;
    return resolved.withValues(alpha: _isDarkMode ? .20 : .24);
  }

  Color _verseBackground(String? highlight, bool selected) {
    final base = _colorForHighlight(highlight);
    if (!selected) return base;
    return Color.alphaBlend(
      AppColors.primary.withValues(alpha: _isDarkMode ? .28 : .14),
      base == Colors.transparent ? _palette.background : base,
    );
  }

  Future<void> _showHighlightColorSheet() =>
      _showWholeVerseMarkingPalette(TextMarkingType.highlight);

  Future<void> _showUnderlineColorSheet() =>
      _showWholeVerseMarkingPalette(TextMarkingType.underline);

  Future<void> _showWholeVerseMarkingPalette(TextMarkingType type) async {
    final result = await HighlightPaletteSheet.show(
      context,
      selectionCount: _selectedVerseNumbers.length,
      actionLabel: type == TextMarkingType.highlight ? 'surligné' : 'souligné',
      canRemoveHighlight: type == TextMarkingType.highlight
          ? _selectionContainsHighlight
          : _selectedVerseNumbers.any(
              (number) => (_textMarkings[number] ?? const []).any(
                (marking) => marking.type == TextMarkingType.underline,
              ),
            ),
    );
    // The sheet route is fully disposed before any database or navigation work.
    if (!mounted || result == null) return;
    if (result.shouldRemove) {
      await _removeSelectedMarkings(type);
    } else if (result.colorKey != null) {
      await _applyWholeVerseMarking(type, result.colorKey!);
      await _loadHighlightPalette();
    }
  }

  Future<void> _showPartialMarkingPalette(TextMarkingType type) async {
    final selection = _partialSelection;
    if (selection == null || selection.text.isEmpty) return;
    final result = await HighlightPaletteSheet.show(
      context,
      selectionCount: 1,
      actionLabel: type == TextMarkingType.highlight ? 'surligné' : 'souligné',
      canRemoveHighlight: false,
    );
    if (!mounted || result?.colorKey == null) return;
    final marking = TextMarking(
      bookId: widget.book.id,
      chapter: _currentChapter,
      verseNumber: selection.verseNumber,
      versionId: _selectedVersionId,
      startOffset: selection.start,
      endOffset: selection.end,
      selectedText: selection.text,
      type: type,
      color: result!.colorKey!,
      createdAt: DateTime.now(),
    );
    await const TextMarkingService().save(marking);
    if (!mounted) return;
    setState(() => _textMarkings
        .putIfAbsent(selection.verseNumber, () => [])
        .add(marking));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(type == TextMarkingType.highlight
            ? 'Surlignage enregistré.'
            : 'Soulignage enregistré.'),
      ),
    );
  }

  Future<void> _applyWholeVerseMarking(
    TextMarkingType type,
    String color,
  ) async {
    final selectedVerses = _verses
        .where(
          (verse) =>
              _selectedVerseNumbers.contains(verse['verse_number'] as int),
        )
        .toList();
    final now = DateTime.now();
    final markings = selectedVerses.map(
      (verse) => TextMarking(
        bookId: widget.book.id,
        chapter: _currentChapter,
        verseNumber: verse['verse_number'] as int,
        versionId: _selectedVersionId,
        selectedText: verse['text'] as String? ?? '',
        type: type,
        color: color,
        createdAt: now,
      ),
    );
    await const TextMarkingService().saveAll(markings);

    if (!mounted) return;
    setState(() {
      for (final marking in markings) {
        _textMarkings.putIfAbsent(marking.verseNumber, () => []).add(marking);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(type == TextMarkingType.highlight
            ? 'Surlignage enregistré.'
            : 'Soulignage enregistré.'),
      ),
    );
  }

  Future<void> _removeSelectedMarkings(TextMarkingType type) async {
    final verseNumbers = _selectedVerseNumbers.toList();
    await const TextMarkingService().remove(
      bookId: widget.book.id,
      chapter: _currentChapter,
      versionId: _selectedVersionId,
      verses: verseNumbers,
      type: type,
    );
    if (type == TextMarkingType.underline) {
      if (!mounted) return;
      setState(() {
        for (final verse in verseNumbers) {
          _textMarkings[verse]?.removeWhere((marking) => marking.type == type);
        }
      });
      return;
    }
    final verseIds = _verses
        .where(
          (verse) =>
              _selectedVerseNumbers.contains(verse['verse_number'] as int),
        )
        .map((verse) => verse['id'] as int)
        .where(_highlightColors.containsKey)
        .toList();
    final db = await DatabaseHelper.instance.database;
    if (verseIds.isNotEmpty) {
      await db.delete(
        'highlights',
        where: 'verse_id IN (${List.filled(verseIds.length, '?').join(', ')})',
        whereArgs: verseIds,
      );
    }

    if (!mounted) return;
    setState(() {
      for (final verseId in verseIds) {
        _highlightColors.remove(verseId);
      }
      for (final verse in verseNumbers) {
        _textMarkings[verse]?.removeWhere((marking) => marking.type == type);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          verseIds.length == 1
              ? 'Surlignage supprimé.'
              : '${verseIds.length} surlignages supprimés.',
        ),
      ),
    );
  }

  Future<void> _showBookSelector() async {
    final selection = await BookChapterSelectorSheet.show(
      context,
      currentBookId: widget.book.id,
      currentChapter: _currentChapter,
      darkMode: _isDarkMode,
    );
    if (!mounted || selection == null) return;

    final tabBindings = ReaderHostBindings.maybeRead(context);
    if (tabBindings != null) {
      tabBindings.onPassageChanged(selection);
      return;
    }

    if (selection.book.id == widget.book.id) {
      await _loadVersesForChapter(selection.chapter);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          book: selection.book,
          initialChapter: selection.chapter,
        ),
      ),
    );
  }
}
