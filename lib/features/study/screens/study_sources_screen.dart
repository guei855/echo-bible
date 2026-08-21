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
              title: 'Alignement français Segond 1910 → Strong',
              source:
                  'Numéros Strong affectés en 2026 par “Concordances et Traductions de la Bible” (concordance.bible).',
              license:
                  'Texte Segond 1910 : domaine public ; numéros Strong : utilisation libre avec attribution',
              url: 'https://concordance.bible/Sg1910/download/',
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
              license:
                  'Original : domaine public ; couche française ECHO BIBLE : CC BY-SA 4.0',
              url:
                  'https://crosswire.org/sword/modules/ModInfo.jsp?modName=Nave',
            ),
            _SourceCard(
              title: 'Dictionnaire biblique français',
              source:
                  'Dictionnaire de la Bible — F. Vigouroux / Wikisource / Gallica',
              license:
                  'Œuvre historique : domaine public ; transcription Wikisource : CC BY-SA 4.0',
              url: 'https://fr.wikisource.org/wiki/Dictionnaire_de_la_Bible',
            ),
            _SourceCard(
              title: 'Bibles françaises hors ligne',
              source:
                  'LSG, Ostervald, Darby et néo-Crampon : eBible.org ; Martin 1744 : GetBible / CrossWire',
              license: 'Domaine public, sauf néo-Crampon Libre : CC BY-SA 4.0',
              url: 'https://ebible.org/bible/',
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
