import 'package:flutter/material.dart';

class StudySourcesScreen extends StatelessWidget {
  const StudySourcesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sources et licences')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _SourceCard(
              title: 'Strong hébreu et grec',
              source: 'STEPBible — TBESH, TBESG, TAHOT, TAGNT, TEHMC et TEGMC',
              license: 'Creative Commons Attribution 4.0 (CC BY 4.0)',
              url: 'https://github.com/STEPBible/STEPBible-Data',
            ),
            _SourceCard(
              title: 'Références croisées',
              source: 'OpenBible.info Cross References',
              license: 'Creative Commons Attribution 4.0 (CC BY 4.0)',
              url: 'https://www.openbible.info/labs/cross-references/',
            ),
            _SourceCard(
              title: 'Bible thématique',
              source: "Orville J. Nave, Nave's Topical Bible — CCEL/CrossWire",
              license: 'Domaine public',
              url: 'https://ccel.org/ccel/n/nave/bible.html',
            ),
            _SourceCard(
              title: 'Dictionnaire biblique français',
              source: 'Aucune ressource complète juridiquement validée',
              license: 'Aucun contenu téléchargé ou fabriqué',
              url: 'Voir docs/resources/dictionary_candidates.md',
            ),
          ],
        ),
      );
}

class _SourceCard extends StatelessWidget {
  final String title;
  final String source;
  final String license;
  final String url;
  const _SourceCard(
      {required this.title,
      required this.source,
      required this.license,
      required this.url});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(source),
            const SizedBox(height: 4),
            Text(license),
            const SizedBox(height: 8),
            SelectableText(url,
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ]),
        ),
      );
}
