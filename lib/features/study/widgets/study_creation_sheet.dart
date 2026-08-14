import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:echo_bible/features/study/widgets/study_document_type_ui.dart';
import 'package:flutter/material.dart';

class StudyCreationRequest {
  const StudyCreationRequest({
    required this.title,
    required this.type,
    required this.useTemplate,
    this.initialBlock,
    this.primaryReference,
  });

  final String title;
  final StudyDocumentType type;
  final bool useTemplate;
  final StudyBlock? initialBlock;
  final String? primaryReference;
}

typedef StudyCreator = Future<PersonalStudy> Function(
  StudyCreationRequest request,
);

class StudyCreationSheet extends StatefulWidget {
  const StudyCreationSheet({
    super.key,
    required this.onCreate,
    this.initialBlock,
    this.primaryReference,
  });

  final StudyCreator onCreate;
  final StudyBlock? initialBlock;
  final String? primaryReference;

  static Future<PersonalStudy?> show(
    BuildContext context, {
    StudyBlock? initialBlock,
    String? primaryReference,
    StudyCreator? createStudy,
  }) {
    return showModalBottomSheet<PersonalStudy>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => StudyCreationSheet(
        initialBlock: initialBlock,
        primaryReference: primaryReference,
        onCreate: createStudy ?? _create,
      ),
    );
  }

  static Future<PersonalStudy> _create(StudyCreationRequest request) async {
    var study = await PersonalStudyService.create(
      title: request.title,
      type: request.type,
      useTemplate: request.initialBlock == null && request.useTemplate,
      initialBlocks:
          request.initialBlock == null ? null : [request.initialBlock!],
      primaryReference: request.primaryReference,
    );
    study = (await PersonalStudyService.load(study.id)) ?? study;
    return study;
  }

  @override
  State<StudyCreationSheet> createState() => _StudyCreationSheetState();
}

class _StudyCreationSheetState extends State<StudyCreationSheet> {
  final _title = TextEditingController();
  StudyDocumentType? _selectedType;
  bool _useTemplate = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Créer une nouvelle étude',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choisissez le type de document que vous souhaitez préparer.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                for (final type in StudyDocumentType.values) ...[
                  _TypeCard(
                    type: type,
                    selected: _selectedType == type,
                    enabled: !_busy,
                    onTap: () => _select(type),
                  ),
                  const SizedBox(height: 10),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _selectedType == null
                      ? const SizedBox.shrink()
                      : Column(
                          key: ValueKey(_selectedType),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            TextField(
                              key: const Key('new-study-title'),
                              controller: _title,
                              enabled: !_busy,
                              autofocus: true,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => setState(() => _error = null),
                              decoration: InputDecoration(
                                labelText: 'Titre de l’étude',
                                hintText: _selectedType!.titleHint,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            if (widget.primaryReference case final reference?)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                      Icons.bookmark_outline,
                                      color: colors.primary,
                                    ),
                                    title: const Text('Référence de départ'),
                                    subtitle: Text(reference),
                                  ),
                                ),
                              ),
                            if (_selectedType != StudyDocumentType.free &&
                                widget.initialBlock == null)
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Utiliser la structure proposée',
                                ),
                                value: _useTemplate,
                                onChanged: _busy
                                    ? null
                                    : (value) =>
                                        setState(() => _useTemplate = value),
                              ),
                          ],
                        ),
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: 10),
                  Text(
                    error,
                    key: const Key('study-creation-error'),
                    style: TextStyle(color: colors.error),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('create-study'),
                    onPressed: _canSubmit ? _submit : null,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: const Text('Créer et ouvrir'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSubmit =>
      !_busy && _selectedType != null && _title.text.trim().isNotEmpty;

  void _select(StudyDocumentType type) {
    setState(() {
      _selectedType = type;
      _error = null;
      final reference = widget.primaryReference?.trim();
      if (_title.text.trim().isEmpty && reference?.isNotEmpty == true) {
        _title.text = type.contextualTitle(reference!);
        _title.selection = TextSelection.collapsed(offset: _title.text.length);
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final study = await widget.onCreate(StudyCreationRequest(
        title: _title.text.trim(),
        type: _selectedType!,
        useTemplate: _useTemplate,
        initialBlock: widget.initialBlock,
        primaryReference: widget.primaryReference,
      ));
      if (mounted) Navigator.pop(context, study);
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = widget.initialBlock == null
            ? 'Impossible de créer cette étude. Veuillez réessayer.'
            : 'Impossible d’ajouter ce passage à l’étude.';
      });
    }
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final StudyDocumentType type;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = type.accent(colors);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: .1) : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? accent : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        key: Key('study-type-${type.name}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(type.icon, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      type.description,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: selected
                    ? Icon(
                        Icons.check_circle,
                        key: const Key('selected-study-type'),
                        color: accent,
                      )
                    : const SizedBox(width: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
