import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Icon(
            Icons.menu_book_rounded,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'ECHO BIBLE',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
          ),
          const Text('Version 1.0.0', textAlign: TextAlign.center),
          const SizedBox(height: 28),
          _SourceCard(
            title: 'Lexiques hébreu et grec',
            icon: Icons.translate_rounded,
            children: const [
              Text(
                'TBESH — Tyndale Brief lexicon of Extended Strong’s for Hebrew',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'TBESG — Tyndale Brief lexicon of Extended Strong’s for Greek',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                'Données créées pour STEPBible.org par Tyndale House, Cambridge, et d’autres contributeurs.',
              ),
              SizedBox(height: 8),
              Text('Licence : Creative Commons Attribution 4.0 (CC BY 4.0).'),
              SizedBox(height: 8),
              SelectableText(
                'Source : https://github.com/STEPBible/STEPBible-Data',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SourceCard(
            title: 'Précision concernant TBESH',
            icon: Icons.info_outline_rounded,
            children: const [
              Text(
                'ECHO BIBLE utilise les numéros Strong étendus, les formes hébraïques, les translittérations, les morphologies et les glosses attribués à Tyndale.',
              ),
              SizedBox(height: 8),
              Text(
                'Les définitions détaillées issues de l’Abridged BDB d’Online Bible ne sont pas incluses, le fichier source demandant une autorisation supplémentaire avant leur utilisation dans un projet.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SourceCard(
            title: 'Respect des sources',
            icon: Icons.verified_outlined,
            children: const [
              Text(
                'Les données lexicales restent attribuées à leurs auteurs. Elles sont reformattées uniquement pour la recherche locale dans ECHO BIBLE.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SourceCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
