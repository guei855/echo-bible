import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:flutter/material.dart';

class StudyDestinationSheet extends StatelessWidget {
  const StudyDestinationSheet({super.key, required this.block});
  final StudyBlock block;

  static Future<bool> show(BuildContext context, StudyBlock block) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => StudyDestinationSheet(block: block),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PersonalStudy>>(
        future: PersonalStudyService.loadAll(),
        builder: (context, snapshot) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajouter à une étude',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Créer une nouvelle étude'),
                onTap: () => _create(context),
              ),
              const Divider(),
              if (snapshot.connectionState != ConnectionState.done)
                const Center(child: CircularProgressIndicator())
              else if ((snapshot.data ?? const []).isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucune étude existante.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final study = snapshot.data![index];
                      return ListTile(
                        leading: const Icon(Icons.edit_document),
                        title: Text(study.title),
                        subtitle: Text(study.type.label),
                        onTap: () => _append(context, study),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );

  Future<void> _create(BuildContext context) async {
    final study = await PersonalStudyService.create(initialBlocks: [block]);
    if (context.mounted) Navigator.pop(context, study.id > 0);
  }

  Future<void> _append(BuildContext context, PersonalStudy study) async {
    final blocks = [
      ...study.blocks,
      block.copyWith(position: study.blocks.length)
    ];
    await PersonalStudyService.saveDocument(study.copyWith(blocks: blocks));
    if (context.mounted) Navigator.pop(context, true);
  }
}
