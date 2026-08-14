import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/screens/personal_study_editor_screen.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:echo_bible/features/study/services/study_export_service.dart';
import 'package:flutter/material.dart';

enum _StudyFilter { all, studies, sermons, meditations, drafts, favorites }

class PersonalStudiesScreen extends StatefulWidget {
  const PersonalStudiesScreen({super.key});

  @override
  State<PersonalStudiesScreen> createState() => _PersonalStudiesScreenState();
}

class _PersonalStudiesScreenState extends State<PersonalStudiesScreen> {
  final _search = TextEditingController();
  late Future<List<PersonalStudy>> _studies = PersonalStudyService.loadAll();
  _StudyFilter _filter = _StudyFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {
        _studies = PersonalStudyService.loadAll(query: _search.text);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mes études')),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('new-study'),
          onPressed: _create,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle étude'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => _refresh(),
                decoration: InputDecoration(
                  hintText: 'Titre, contenu, référence ou tag',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            _refresh();
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              height: 45,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  _chip(_StudyFilter.all, 'Toutes'),
                  _chip(_StudyFilter.studies, 'Études'),
                  _chip(_StudyFilter.sermons, 'Prédications'),
                  _chip(_StudyFilter.meditations, 'Méditations'),
                  _chip(_StudyFilter.drafts, 'Brouillons'),
                  _chip(_StudyFilter.favorites, 'Favoris'),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<PersonalStudy>>(
                future: _studies,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final studies = (snapshot.data ?? const [])
                      .where(_matchesFilter)
                      .toList();
                  if (studies.isEmpty) return const _EmptyStudies();
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: studies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _StudyCard(
                        study: studies[index],
                        onOpen: () => _open(studies[index]),
                        onAction: (action) =>
                            _handleAction(action, studies[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _chip(_StudyFilter value, String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  bool _matchesFilter(PersonalStudy study) => switch (_filter) {
        _StudyFilter.all => true,
        _StudyFilter.studies => study.type == StudyDocumentType.free ||
            study.type == StudyDocumentType.bibleStudy,
        _StudyFilter.sermons => study.type == StudyDocumentType.sermon,
        _StudyFilter.meditations => study.type == StudyDocumentType.meditation,
        _StudyFilter.drafts => study.status == StudyStatus.draft,
        _StudyFilter.favorites => study.isFavorite,
      };

  Future<void> _create() async {
    var selected = StudyDocumentType.free;
    var useTemplate = false;
    final title = TextEditingController(text: 'Document sans titre');
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nouvelle étude',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                key: const Key('new-study-title'),
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<StudyDocumentType>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Type de document',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in StudyDocumentType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) =>
                    setSheetState(() => selected = value ?? selected),
              ),
              if (selected != StudyDocumentType.free)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Utiliser le modèle proposé'),
                  value: useTemplate,
                  onChanged: (value) =>
                      setSheetState(() => useTemplate = value),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('create-study'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Créer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != true) {
      title.dispose();
      return;
    }
    final study = await PersonalStudyService.create(
      title: title.text,
      type: selected,
      useTemplate: useTemplate,
    );
    title.dispose();
    if (!mounted) return;
    await _open(study);
  }

  Future<void> _open(PersonalStudy study) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PersonalStudyEditorScreen(study: study)),
    );
    if (mounted) _refresh();
  }

  Future<void> _handleAction(String action, PersonalStudy study) async {
    if (action == 'open') return _open(study);
    if (action == 'rename') {
      final controller = TextEditingController(text: study.title);
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Renommer l’étude'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Sauvegarder')),
          ],
        ),
      );
      controller.dispose();
      if (value != null) {
        await PersonalStudyService.saveDocument(study.copyWith(title: value));
      }
    } else if (action == 'duplicate') {
      await PersonalStudyService.duplicate(study);
    } else if (action == 'favorite') {
      await PersonalStudyService.saveDocument(
        study.copyWith(isFavorite: !study.isFavorite),
      );
    } else if (action == 'pin') {
      await PersonalStudyService.saveDocument(
        study.copyWith(isPinned: !study.isPinned),
      );
    } else if (action == 'export') {
      await _export(study);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Supprimer cette étude ?'),
          content: Text('« ${study.title} » sera supprimée définitivement.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer')),
          ],
        ),
      );
      if (confirmed == true) await PersonalStudyService.delete(study.id);
    }
    if (mounted) _refresh();
  }

  Future<void> _export(PersonalStudy study) async {
    final choice = await showModalBottomSheet<StudyExportFormat>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Exporter')),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Fichier texte'),
              onTap: () => Navigator.pop(context, StudyExportFormat.text),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partager / WhatsApp'),
              onTap: () => Navigator.pop(context, StudyExportFormat.share),
            ),
            const ListTile(
              enabled: false,
              leading: Icon(Icons.picture_as_pdf_outlined),
              title: Text('PDF — prévu dans l’architecture'),
            ),
            const ListTile(
              enabled: false,
              leading: Icon(Icons.description_outlined),
              title: Text('DOCX — prévu dans l’architecture'),
            ),
          ],
        ),
      ),
    );
    if (choice == StudyExportFormat.share) {
      await StudyExportService.share(study);
    } else if (choice == StudyExportFormat.text) {
      final file = await StudyExportService.exportText(study);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exporté : ${file.path}')),
        );
      }
    }
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.study,
    required this.onOpen,
    required this.onAction,
  });
  final PersonalStudy study;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                study.isPinned ? Icons.push_pin : Icons.description_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(study.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (study.isFavorite)
                        const Icon(Icons.favorite,
                            size: 17, color: Colors.redAccent),
                    ]),
                    const SizedBox(height: 5),
                    Text(
                      [
                        study.type.label,
                        if (study.reference != null) study.reference!
                      ].join(' · '),
                      style: TextStyle(color: colors.primary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Modifié ${_relativeDate(study.updatedAt)} · ${study.status.label}',
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: onAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'open', child: Text('Ouvrir')),
                  const PopupMenuItem(value: 'rename', child: Text('Renommer')),
                  const PopupMenuItem(
                      value: 'duplicate', child: Text('Dupliquer')),
                  PopupMenuItem(
                      value: 'favorite',
                      child: Text(study.isFavorite
                          ? 'Retirer des favoris'
                          : 'Ajouter aux favoris')),
                  PopupMenuItem(
                      value: 'pin',
                      child: Text(study.isPinned ? 'Désépingler' : 'Épingler')),
                  const PopupMenuItem(value: 'export', child: Text('Exporter')),
                  const PopupMenuItem(
                      value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'à l’instant';
    if (difference.inHours < 1) return 'il y a ${difference.inMinutes} min';
    if (difference.inDays < 1) {
      return 'aujourd’hui à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'le ${date.day}/${date.month}/${date.year}';
  }
}

class _EmptyStudies extends StatelessWidget {
  const _EmptyStudies();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_document, size: 52, color: AppColors.primary),
              SizedBox(height: 14),
              Text('Commencez votre première étude',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}
