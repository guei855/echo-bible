import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:echo_bible/features/study/widgets/study_creation_sheet.dart';
import 'package:echo_bible/features/study/widgets/study_document_type_ui.dart';
import 'package:flutter/material.dart';

typedef StudyListLoader = Future<List<PersonalStudy>> Function();
typedef StudyDocumentSaver = Future<void> Function(PersonalStudy study);
typedef StudyDocumentLoader = Future<PersonalStudy?> Function(int id);

class StudyDestinationSheet extends StatefulWidget {
  const StudyDestinationSheet({
    super.key,
    required this.block,
    required this.reference,
    required this.loadStudies,
    required this.saveStudy,
    required this.loadStudy,
  });

  final StudyBlock block;
  final String reference;
  final StudyListLoader loadStudies;
  final StudyDocumentSaver saveStudy;
  final StudyDocumentLoader loadStudy;

  static Future<PersonalStudy?> show(
    BuildContext context,
    StudyBlock block, {
    String? reference,
    StudyListLoader? loadStudies,
    StudyDocumentSaver? saveStudy,
    StudyDocumentLoader? loadStudy,
    StudyCreator? createStudy,
  }) async {
    final resolvedReference =
        reference ?? block.payload['reference'] as String? ?? 'ce passage';
    final choice = await showModalBottomSheet<_DestinationChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => StudyDestinationSheet(
        block: block,
        reference: resolvedReference,
        loadStudies: loadStudies ?? PersonalStudyService.loadAll,
        saveStudy: saveStudy ?? PersonalStudyService.saveDocument,
        loadStudy: loadStudy ?? PersonalStudyService.load,
      ),
    );
    if (!context.mounted || choice == null) return null;
    if (choice.createNew) {
      return StudyCreationSheet.show(
        context,
        initialBlock: block,
        primaryReference: resolvedReference,
        createStudy: createStudy,
      );
    }
    return choice.study;
  }

  @override
  State<StudyDestinationSheet> createState() => _StudyDestinationSheetState();
}

class _StudyDestinationSheetState extends State<StudyDestinationSheet> {
  late final Future<List<PersonalStudy>> _studies = widget.loadStudies();
  final _search = TextEditingController();
  int? _busyStudyId;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _busyStudyId == null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: FutureBuilder<List<PersonalStudy>>(
            future: _studies,
            builder: (context, snapshot) {
              final studies = [...?snapshot.data]..sort(_compareStudies);
              final filtered = studies.where(_matchesSearch).toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajouter à une étude',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Choisissez où intégrer ${widget.reference}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 15),
                  Card(
                    margin: EdgeInsets.zero,
                    color: colors.primaryContainer.withValues(alpha: .45),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: const Key('create-study-destination'),
                      enabled: _busyStudyId == null,
                      leading: CircleAvatar(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        child: const Icon(Icons.add),
                      ),
                      title: const Text(
                        'Créer une nouvelle étude',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Créer un nouveau document et y ajouter ce passage.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(
                        context,
                        const _DestinationChoice.createNew(),
                      ),
                    ),
                  ),
                  if (studies.length > 6) ...[
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('study-destination-search'),
                      controller: _search,
                      enabled: _busyStudyId == null,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher une étude…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  if (_error case final error?)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        error,
                        key: const Key('study-destination-error'),
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (studies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune étude existante.'),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune étude ne correspond à la recherche.'),
                    )
                  else
                    Flexible(
                      child: AbsorbPointer(
                        absorbing: _busyStudyId != null,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final study = filtered[index];
                            return _DestinationCard(
                              study: study,
                              busy: _busyStudyId == study.id,
                              onTap: () => _append(study),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _matchesSearch(PersonalStudy study) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return '${study.title} ${study.type.label} ${study.reference ?? ''} '
            '${study.tags.join(' ')}'
        .toLowerCase()
        .contains(query);
  }

  static int _compareStudies(PersonalStudy left, PersonalStudy right) {
    if (left.isPinned != right.isPinned) return left.isPinned ? -1 : 1;
    final recent = right.updatedAt.compareTo(left.updatedAt);
    return recent != 0 ? recent : right.id.compareTo(left.id);
  }

  Future<void> _append(PersonalStudy study) async {
    if (_busyStudyId != null) return;
    setState(() {
      _busyStudyId = study.id;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final updated = study.copyWith(
        blocks: [
          ...study.blocks,
          widget.block.copyWith(
            position: study.blocks.length,
            updatedAt: now,
          ),
        ],
        updatedAt: now,
      );
      await widget.saveStudy(updated);
      final saved = await widget.loadStudy(study.id) ?? updated;
      if (mounted) Navigator.pop(context, _DestinationChoice.study(saved));
    } on Object {
      if (!mounted) return;
      setState(() {
        _busyStudyId = null;
        _error = 'Impossible d’ajouter ce passage à l’étude.';
      });
    }
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.study,
    required this.busy,
    required this.onTap,
  });

  final PersonalStudy study;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = study.type.accent(colors);
    return Card(
      key: Key('study-destination-${study.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(study.type.icon, color: accent),
        ),
        title: Text(
          study.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(study.type.label),
            if (study.reference case final reference?)
              Text(
                reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.primary),
              ),
            Text(
              'Modifié ${_relativeDate(study.updatedAt)}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        trailing: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }

  static String _relativeDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'à l’instant';
    if (difference.inHours < 1) return 'il y a ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'il y a ${difference.inHours} h';
    return 'le ${date.day}/${date.month}/${date.year}';
  }
}

class _DestinationChoice {
  const _DestinationChoice.study(this.study) : createNew = false;
  const _DestinationChoice.createNew()
      : createNew = true,
        study = null;

  final bool createNew;
  final PersonalStudy? study;
}
