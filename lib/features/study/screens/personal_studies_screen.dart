import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/screens/personal_study_editor_screen.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:flutter/material.dart';

class PersonalStudiesScreen extends StatefulWidget {
  const PersonalStudiesScreen({super.key});

  @override
  State<PersonalStudiesScreen> createState() => _PersonalStudiesScreenState();
}

class _PersonalStudiesScreenState extends State<PersonalStudiesScreen> {
  late Future<List<PersonalStudy>> _studies = PersonalStudyService.loadAll();
  bool _oldestFirst = false;
  String _query = '';

  Future<void> _refresh() async {
    final data = await PersonalStudyService.loadAll();
    if (!mounted) return;
    final studies = Future.value(data);
    setState(() {
      _studies = studies;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Mes études'),
        actions: [
          IconButton(
            tooltip: 'Rechercher',
            onPressed: _showSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          PopupMenuButton<bool>(
            tooltip: 'Trier',
            initialValue: _oldestFirst,
            onSelected: (value) => setState(() => _oldestFirst = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: false, child: Text('Plus récentes')),
              PopupMenuItem(value: true, child: Text('Plus anciennes')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Trier'),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouvelle étude',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: FutureBuilder<List<PersonalStudy>>(
        future: _studies,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final studies = [...?snapshot.data];
          if (_query.isNotEmpty) {
            studies.removeWhere((study) {
              final searchable =
                  '${study.title} ${study.content} ${study.reference ?? ''}'
                      .toLowerCase();
              return !searchable.contains(_query.toLowerCase());
            });
          }
          if (_oldestFirst) {
            studies.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
          }
          if (studies.isEmpty) return const _EmptyStudies();
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 3 : 2;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 2 ? .76 : .9,
                ),
                itemCount: studies.length,
                itemBuilder: (context, index) => _StudyCard(
                  study: studies[index],
                  onOpen: () => _openEditor(studies[index]),
                  onDelete: () => _delete(studies[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor([PersonalStudy? study]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => PersonalStudyEditorScreen(study: study)),
    );
    if (changed == true && mounted) _refresh();
  }

  Future<void> _showSearch() async {
    final controller = TextEditingController(text: _query);
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechercher une étude'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Titre, contenu ou référence',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Effacer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query != null && mounted) setState(() => _query = query);
  }

  Future<void> _delete(PersonalStudy study) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette étude ?'),
        content: Text('« ${study.title} » sera supprimée définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await PersonalStudyService.delete(study.id);
    if (mounted) _refresh();
  }
}

class _StudyCard extends StatelessWidget {
  final PersonalStudy study;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _StudyCard({
    required this.study,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _relativeDate(study.updatedAt),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'edit') onOpen();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                ],
              ),
              Text(
                study.title.toUpperCase(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              if (study.reference?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                Text(
                  study.reference!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  _plainText(study.content),
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.42,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _plainText(String value) => value
      .replaceAll(RegExp(r'\*\*|_|<\/?u>'), '')
      .replaceAll('• ', '')
      .trim();

  static String _relativeDate(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Aujourd’hui';
    if (days == 1) return 'Hier';
    if (days < 30) return 'Il y a $days jours';
    final months = days ~/ 30;
    if (months < 12) return 'Il y a $months mois';
    final years = days ~/ 365;
    return years == 1 ? 'Il y a un an' : 'Il y a $years ans';
  }
}

class _EmptyStudies extends StatelessWidget {
  const _EmptyStudies();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE8EEFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_document,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Commencez votre première étude',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Rassemblez vos réflexions et les passages qui les accompagnent.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
