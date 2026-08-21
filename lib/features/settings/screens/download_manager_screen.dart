import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:flutter/material.dart';

enum _ResourceFilter { all, installed, notInstalled, fr, en }

class DownloadManagerScreen extends StatefulWidget {
  final ResourceCategory? initialCategory;
  final ResourceLanguage? initialLanguage;

  const DownloadManagerScreen({
    super.key,
    this.initialCategory,
    this.initialLanguage,
  });

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  final _manager = const ResourceManager();
  final Map<OfflineResourceId, OfflineResourceState> _states = {};
  final Map<OfflineResourceId, double> _progress = {};
  List<ResourceDescriptor> _resources = const [];
  late _ResourceFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = switch (widget.initialLanguage) {
      ResourceLanguage.fr => _ResourceFilter.fr,
      ResourceLanguage.en => _ResourceFilter.en,
      _ => _ResourceFilter.all,
    };
    _refresh();
  }

  Future<void> _refresh() async {
    final resources = await _manager.resolvedCatalog();
    final values = await Future.wait(
      resources.map((resource) async => MapEntry(
            resource.id,
            await _manager.state(resource.id),
          )),
    );
    if (!mounted) return;
    setState(() {
      _resources = resources;
      _states.addEntries(values);
    });
  }

  Iterable<ResourceDescriptor> get _visible => _resources.where((resource) {
        if (widget.initialCategory != null &&
            resource.category != widget.initialCategory) {
          return false;
        }
        final state = _states[resource.id];
        return switch (_filter) {
          _ResourceFilter.all => true,
          _ResourceFilter.installed =>
            state == OfflineResourceState.installed ||
                state == OfflineResourceState.updateAvailable,
          _ResourceFilter.notInstalled =>
            state == OfflineResourceState.notInstalled ||
                state == OfflineResourceState.readyForHosting ||
                state == OfflineResourceState.preparing,
          _ResourceFilter.fr => resource.language == ResourceLanguage.fr,
          _ResourceFilter.en => resource.language == ResourceLanguage.en,
        };
      });

  @override
  Widget build(BuildContext context) {
    final resources = _visible.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des téléchargements')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_ResourceFilter>(
                segments: const [
                  ButtonSegment(
                      value: _ResourceFilter.all, label: Text('Tous')),
                  ButtonSegment(
                    value: _ResourceFilter.installed,
                    label: Text('Téléchargés'),
                  ),
                  ButtonSegment(
                    value: _ResourceFilter.notInstalled,
                    label: Text('Non téléchargés'),
                  ),
                  ButtonSegment(value: _ResourceFilter.fr, label: Text('FR')),
                  ButtonSegment(value: _ResourceFilter.en, label: Text('EN')),
                ],
                selected: {_filter},
                onSelectionChanged: (selection) =>
                    setState(() => _filter = selection.first),
              ),
            ),
            const SizedBox(height: 18),
            for (final language in ResourceLanguage.values) ...[
              if (resources.any((resource) => resource.language == language))
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                  child: Text(
                    switch (language) {
                      ResourceLanguage.fr => 'FRANÇAIS',
                      ResourceLanguage.en => 'ANGLAIS',
                      ResourceLanguage.common => 'COMMUN',
                    },
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              for (final resource
                  in resources.where((item) => item.language == language))
                _ResourceTile(
                  resource: resource,
                  state: _states[resource.id] ?? OfflineResourceState.preparing,
                  progress: _progress[resource.id],
                  onAction: () => _perform(resource),
                  onReinstall: () => _perform(resource, reinstall: true),
                  onCancel: () {
                    _manager.cancel(resource.id);
                    _refresh();
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _perform(
    ResourceDescriptor resource, {
    bool reinstall = false,
  }) async {
    final state = _states[resource.id];
    var failed = false;
    try {
      if (state == OfflineResourceState.installed && !reinstall) {
        await _manager.remove(resource.id);
      } else {
        await _download(resource);
      }
    } catch (error) {
      if (!mounted) return;
      failed = true;
      setState(() => _states[resource.id] = OfflineResourceState.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Téléchargement impossible : $error. Réessayer.')),
      );
    } finally {
      if (mounted && !failed) await _refresh();
    }
  }

  Future<void> _download(ResourceDescriptor resource) async {
    setState(() => _states[resource.id] = OfflineResourceState.downloading);
    await _manager.download(
      resource.id,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() => _progress[resource.id] = received / total);
      },
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final ResourceDescriptor resource;
  final OfflineResourceState state;
  final double? progress;
  final VoidCallback onAction;
  final VoidCallback onReinstall;
  final VoidCallback onCancel;

  const _ResourceTile({
    required this.resource,
    required this.state,
    this.progress,
    required this.onAction,
    required this.onReinstall,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(resource.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                _StatusChip(state: state),
              ]),
              const SizedBox(height: 6),
              Text(resource.description),
              const SizedBox(height: 8),
              Text(
                '${resource.source} · ${resource.license}'
                '${resource.sizeBytes == null ? '' : ' · ${_size(resource.sizeBytes!)}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (state == OfflineResourceState.downloading) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: state == OfflineResourceState.downloading
                    ? TextButton(
                        onPressed: onCancel,
                        child: Text(
                          'Annuler (${((progress ?? 0) * 100).round()} %)',
                        ),
                      )
                    : Wrap(
                        children: [
                          if (state == OfflineResourceState.installed)
                            TextButton(
                              onPressed:
                                  resource.canDownload ? onReinstall : null,
                              child: const Text('Réinstaller'),
                            ),
                          TextButton(
                            onPressed: switch (state) {
                              OfflineResourceState.notInstalled ||
                              OfflineResourceState.installed ||
                              OfflineResourceState.updateAvailable =>
                                onAction,
                              OfflineResourceState.error => onAction,
                              _ => null,
                            },
                            child: Text(switch (state) {
                              OfflineResourceState.installed => 'Supprimer',
                              OfflineResourceState.updateAvailable =>
                                'Mettre à jour',
                              OfflineResourceState.notInstalled =>
                                'Télécharger',
                              OfflineResourceState.licenseRequired =>
                                'Autorisation requise',
                              OfflineResourceState.readyForHosting =>
                                'Prêt à héberger',
                              OfflineResourceState.error => 'Réessayer',
                              OfflineResourceState.unavailable =>
                                'Indisponible',
                              _ => 'En préparation',
                            }),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );

  static String _size(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} Mo';
}

class _StatusChip extends StatelessWidget {
  final OfflineResourceState state;
  const _StatusChip({required this.state});

  @override
  Widget build(BuildContext context) => Chip(
        visualDensity: VisualDensity.compact,
        label: Text(switch (state) {
          OfflineResourceState.installed => 'Installé',
          OfflineResourceState.notInstalled => 'Télécharger',
          OfflineResourceState.updateAvailable => 'Mise à jour',
          OfflineResourceState.downloading => 'Téléchargement…',
          OfflineResourceState.error => 'Erreur',
          OfflineResourceState.licenseRequired => 'Autorisation requise',
          OfflineResourceState.unavailable => 'Indisponible',
          OfflineResourceState.readyForHosting => 'Prêt à héberger',
          OfflineResourceState.preparing => 'En préparation',
        }),
      );
}
