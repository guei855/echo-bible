import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/study/models/study_tool_item.dart';
import 'package:echo_bible/features/study/screens/study_tool_list_screen.dart';
import 'package:echo_bible/features/study/screens/study_hub_screen.dart';
import 'package:echo_bible/features/study/screens/personal_studies_screen.dart';
import 'package:echo_bible/features/plans/screens/reading_plans_screen.dart';
import 'package:echo_bible/features/study/services/study_tools_service.dart';
import 'package:flutter/material.dart';

class StudyToolsScreen extends StatefulWidget {
  const StudyToolsScreen({super.key});

  @override
  State<StudyToolsScreen> createState() => _StudyToolsScreenState();
}

class _StudyToolsScreenState extends State<StudyToolsScreen> {
  late Future<StudyToolsSummary> _summary = StudyToolsService.loadSummary();

  Future<void> _refresh() async {
    final data = await StudyToolsService.loadSummary();
    if (!mounted) return;
    final summary = Future.value(data);
    setState(() {
      _summary = summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Outils d’étude'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<StudyToolsSummary>(
        future: _summary,
        builder: (context, snapshot) {
          final summary = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Votre espace personnel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Retrouvez, classez et reliez vos découvertes bibliques.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8EEFF),
                    foregroundColor: AppColors.primary,
                    child: Icon(Icons.school_rounded),
                  ),
                  title: const Text(
                    'Étude biblique',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Concordance, Strong, lexique et ressources',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudyHubScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE5F3FF),
                    foregroundColor: AppColors.primary,
                    child: Icon(Icons.calendar_month_rounded),
                  ),
                  title: const Text(
                    'Plans de lecture',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Bible en 1 an ou plan personnalisé',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReadingPlansScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.18,
                children: [
                  _ToolCard(
                    title: 'Surlignages',
                    subtitle: 'Versets marqués par couleur',
                    count: summary?.highlights,
                    icon: Icons.brush_rounded,
                    color: Colors.pink,
                    onTap: () => _openList(
                      StudyToolType.highlights,
                      'Surlignages',
                    ),
                  ),
                  _ToolCard(
                    title: 'Notes',
                    subtitle: 'Vos réflexions personnelles',
                    count: summary?.notes,
                    icon: Icons.edit_note_rounded,
                    color: Colors.deepPurple,
                    onTap: () => _openList(StudyToolType.notes, 'Notes'),
                  ),
                  _ToolCard(
                    title: 'Signets',
                    subtitle: 'Passages à retrouver rapidement',
                    count: summary?.bookmarks,
                    icon: Icons.bookmark_rounded,
                    color: Colors.redAccent,
                    onTap: () => _openList(StudyToolType.bookmarks, 'Signets'),
                  ),
                  _ToolCard(
                    title: 'Tags',
                    subtitle: 'Classement par thèmes personnalisés',
                    count: summary?.tags,
                    icon: Icons.sell_outlined,
                    color: Colors.teal,
                    onTap: () => _notReady(
                      'Tags',
                      'Le stockage des tags est prêt. Leur attribution depuis un verset arrive dans la prochaine étape.',
                    ),
                  ),
                  _ToolCard(
                    title: 'Liens',
                    subtitle: 'Connexions entre passages',
                    count: summary?.links,
                    icon: Icons.link_rounded,
                    color: Colors.blue,
                    onTap: () => _notReady(
                      'Liens entre versets',
                      'Le stockage des connexions est prêt. Le sélecteur de passage lié reste à construire.',
                    ),
                  ),
                  _ToolCard(
                    title: 'Études',
                    subtitle: 'Documents et sections riches',
                    count: summary?.studies,
                    icon: Icons.edit_document,
                    color: Colors.orange,
                    onTap: _openStudies,
                  ),
                  _ToolCard(
                    title: 'Historique',
                    subtitle: 'Derniers passages consultés',
                    count: summary?.history,
                    icon: Icons.history_rounded,
                    color: Colors.blueGrey,
                    onTap: () => _openList(StudyToolType.history, 'Historique'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openList(StudyToolType type, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudyToolListScreen(type: type, title: title),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _openStudies() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalStudiesScreen()),
    );
    if (mounted) _refresh();
  }

  void _notReady(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int? count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    foregroundColor: color,
                    child: Icon(icon, size: 21),
                  ),
                  Text(
                    count?.toString() ?? '…',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
