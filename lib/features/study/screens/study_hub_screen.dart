import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/features/dictionary/screens/dictionary_screen.dart';
import 'package:echo_bible/features/lexicon/screens/lexicon_screen.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:echo_bible/features/search/screens/concordance_screen.dart';
import 'package:echo_bible/features/study/screens/study_resource_screen.dart';
import 'package:echo_bible/features/study/screens/cross_references_screen.dart';
import 'package:echo_bible/features/study/screens/personal_studies_screen.dart';
import 'package:echo_bible/features/study/screens/comparison_picker_screen.dart';
import 'package:echo_bible/features/study/screens/nave_topics_screen.dart';
import 'package:echo_bible/features/study/screens/study_sources_screen.dart';
import 'package:echo_bible/features/study/screens/study_tabs_screen.dart';
import 'package:echo_bible/features/study/repositories/cross_reference_repository.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:echo_bible/features/study/repositories/strong_repository.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:flutter/material.dart';

class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({super.key, this.loadStrongState});

  final Future<OfflineResourceState> Function()? loadStrongState;

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  late Future<OfflineResourceState> _strongState;
  late Future<_StudyDataSummary> _summary;

  @override
  void initState() {
    super.initState();
    _strongState = _loadStrongState();
    _summary = _loadSummary();
  }

  Future<OfflineResourceState> _loadStrongState() async {
    try {
      return await (widget.loadStrongState?.call() ??
              const ResourceManager().state(OfflineResourceId.strong))
          .timeout(const Duration(seconds: 8));
    } on Object {
      return OfflineResourceState.notInstalled;
    }
  }

  Future<_StudyDataSummary> _loadSummary() async {
    Future<int> safe(Future<int> Function() loader) async {
      try {
        return await loader();
      } on Object {
        return 0;
      }
    }

    final strongState = await _strongState;
    final strongInstalled = strongState == OfflineResourceState.installed ||
        strongState == OfflineResourceState.updateAvailable;
    final counts = await Future.wait<int>([
      strongInstalled
          ? safe(() => const StrongRepository().count())
          : Future.value(0),
      safe(() => const NaveRepository().count()),
      safe(() => const CrossReferenceRepository().count()),
      safe(PersonalStudyService.countStudies),
    ]);
    return _StudyDataSummary(
      strongState: strongState,
      strongCount: counts[0],
      topicsCount: counts[1],
      crossReferenceCount: counts[2],
      personalStudyCount: counts[3],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Étude biblique')),
      body: FutureBuilder<_StudyDataSummary>(
        future: _summary,
        builder: (context, snapshot) {
          final summary = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const _StudyHeader(),
              const SizedBox(height: 24),
              Text(
                'Explorer les Écritures',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  _StudyCard(
                    title: 'Concordance',
                    description: 'Rechercher un mot ou une expression exacte.',
                    icon: Icons.manage_search_rounded,
                    color: const Color(0xFF2563EB),
                    badge: 'Disponible',
                    onTap: () => _open(const ConcordanceScreen()),
                  ),
                  _StudyCard(
                    title: 'Strong',
                    description: 'Codes, lemmes et occurrences déjà indexés.',
                    icon: Icons.translate_rounded,
                    color: const Color(0xFF7C3AED),
                    badge: summary == null
                        ? 'Vérification…'
                        : summary.strongAvailable
                            ? '${summary.strongCount} entrées'
                            : 'Télécharger',
                    onTap: () => _open(const ConcordanceScreen(initialTab: 1)),
                  ),
                  FutureBuilder<OfflineResourceState>(
                    future: _strongState,
                    builder: (context, resourceSnapshot) {
                      final state = resourceSnapshot.data;
                      final available =
                          state == OfflineResourceState.installed ||
                              state == OfflineResourceState.updateAvailable;
                      return _StudyCard(
                        title: 'Lexique',
                        description:
                            'Hébreu, grec, translittération et grammaire.',
                        icon: Icons.abc_rounded,
                        color: const Color(0xFF0891B2),
                        badge: state == null
                            ? 'Vérification…'
                            : available
                                ? 'Disponible'
                                : 'Télécharger',
                        onTap: _openLexicon,
                      );
                    },
                  ),
                  _StudyCard(
                    title: 'Références',
                    description: 'Passages bibliques liés au texte étudié.',
                    icon: Icons.account_tree_outlined,
                    color: const Color(0xFF059669),
                    badge: summary == null
                        ? 'Vérification…'
                        : '${summary.crossReferenceCount} liens',
                    onTap: () => _open(const CrossReferencesScreen()),
                  ),
                  _StudyCard(
                    title: 'Dictionnaire',
                    description: 'Personnes, lieux et notions bibliques.',
                    icon: Icons.auto_stories_outlined,
                    color: const Color(0xFFD97706),
                    onTap: () => _open(const DictionaryScreen()),
                  ),
                  _StudyCard(
                    title: 'Thèmes',
                    description: 'Parcours thématiques et index de Nave.',
                    icon: Icons.hub_outlined,
                    color: const Color(0xFFDB2777),
                    badge: summary == null
                        ? 'Vérification…'
                        : '${summary.topicsCount} thèmes',
                    onTap: () => _open(const NaveTopicsScreen()),
                  ),
                  _StudyCard(
                    title: 'Comparer',
                    description:
                        'Une référence affichée dans plusieurs versions.',
                    icon: Icons.compare_arrows_rounded,
                    color: const Color(0xFF4F46E5),
                    onTap: () => _open(const ComparisonPickerScreen()),
                  ),
                  _StudyCard(
                    title: 'Assistant IA',
                    description:
                        'Aide guidée pour structurer vos recherches bibliques.',
                    icon: Icons.smart_toy_outlined,
                    color: const Color(0xFF6D28D9),
                    badge: 'À venir',
                    onTap: () => _unavailable(
                      'Assistant IA',
                      'L’assistant sera activé lorsqu’un service fiable, transparent et respectueux de vos données aura été configuré.',
                      Icons.smart_toy_outlined,
                    ),
                  ),
                  _StudyCard(
                    title: 'Chronologie',
                    description:
                        'Événements, périodes et personnages bibliques.',
                    icon: Icons.timeline_rounded,
                    color: const Color(0xFFB45309),
                    onTap: () => _unavailable(
                      'Chronologie biblique',
                      'La chronologie sera intégrée après le dictionnaire et les thèmes, avec des liens vers les passages concernés.',
                      Icons.timeline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Mon espace de travail',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _WorkspaceTile(
                icon: Icons.edit_document,
                title: 'Mes études personnelles',
                subtitle: summary == null
                    ? 'Chargement…'
                    : '${summary.personalStudyCount} étude(s) enregistrée(s)',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PersonalStudiesScreen(),
                    ),
                  );
                  final data = await _loadSummary();
                  if (!mounted) return;
                  final summary = Future.value(data);
                  setState(() {
                    _summary = summary;
                  });
                },
              ),
              const SizedBox(height: 10),
              _WorkspaceTile(
                icon: Icons.info_outline_rounded,
                title: 'Sources et licences',
                subtitle: 'STEPBible, OpenBible.info et Nave',
                onTap: () => _open(const StudySourcesScreen()),
              ),
              const SizedBox(height: 10),
              _WorkspaceTile(
                icon: Icons.tab_rounded,
                title: 'Onglets d’étude',
                subtitle: 'Lectures, comparaisons et recherches conservées',
                onTap: () => _open(const StudyTabsScreen()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openLexicon() async {
    const manager = ResourceManager();
    OfflineResourceState state;
    try {
      state = await manager.state(OfflineResourceId.strong);
    } on Object {
      state = OfflineResourceState.notInstalled;
    }
    if (!mounted) return;
    final installed = state == OfflineResourceState.installed ||
        state == OfflineResourceState.updateAvailable;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => installed
            ? const LexiconScreen()
            : const DownloadManagerScreen(
                initialCategory: ResourceCategory.strong,
              ),
      ),
    );
    if (mounted) {
      setState(() {
        _strongState = _loadStrongState();
        _summary = _loadSummary();
      });
    }
  }

  void _unavailable(String title, String description, IconData icon) {
    _open(
      StudyResourceScreen(
        title: title,
        description: description,
        icon: icon,
      ),
    );
  }
}

class _StudyHeader extends StatelessWidget {
  const _StudyHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B68), Color(0xFF2563A5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school_rounded, color: Colors.white, size: 32),
          SizedBox(height: 14),
          Text(
            'Approfondir la Parole',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Un espace unique pour rechercher, relier et organiser vos études.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _StudyCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 23),
                  ),
                  if (badge != null)
                    Flexible(
                      child: Text(
                        badge!,
                        key: Key('study-$title-badge'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            theme.textTheme.labelSmall?.copyWith(color: color),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WorkspaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _StudyDataSummary {
  final OfflineResourceState strongState;
  final int strongCount;
  final int topicsCount;
  final int crossReferenceCount;
  final int personalStudyCount;

  const _StudyDataSummary({
    required this.strongState,
    required this.strongCount,
    required this.topicsCount,
    required this.crossReferenceCount,
    required this.personalStudyCount,
  });

  bool get strongAvailable =>
      strongState == OfflineResourceState.installed ||
      strongState == OfflineResourceState.updateAvailable;
}
