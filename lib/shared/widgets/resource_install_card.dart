import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:flutter/material.dart';

class ResourceInstallCard extends StatelessWidget {
  final ResourceDescriptor resource;
  final OfflineResourceState state;
  final VoidCallback? onDownload;
  final VoidCallback? onLater;
  final VoidCallback? onOpen;

  const ResourceInstallCard({
    super.key,
    required this.resource,
    required this.state,
    this.onDownload,
    this.onLater,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final installed = state == OfflineResourceState.installed;
    final preparing = state == OfflineResourceState.preparing;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 42,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    resource.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(resource.description),
                  const SizedBox(height: 18),
                  _Metadata(
                    key: const Key('resource-status'),
                    label: 'Statut',
                    value: switch (state) {
                      OfflineResourceState.installed => 'Installé',
                      OfflineResourceState.notInstalled => 'Télécharger',
                      OfflineResourceState.updateAvailable =>
                        'Mise à jour disponible',
                      OfflineResourceState.downloading => 'Téléchargement…',
                      OfflineResourceState.error => 'Erreur',
                      OfflineResourceState.licenseRequired =>
                        'Autorisation requise',
                      OfflineResourceState.unavailable => 'Indisponible',
                      OfflineResourceState.readyForHosting => 'Prêt à héberger',
                      OfflineResourceState.preparing =>
                        'Ressource en préparation',
                    },
                  ),
                  if (resource.sizeBytes != null)
                    _Metadata(
                      label: 'Taille',
                      value: _formatBytes(resource.sizeBytes!),
                    ),
                  _Metadata(label: 'Source', value: resource.source),
                  _Metadata(label: 'Licence', value: resource.license),
                  const SizedBox(height: 18),
                  if (installed && onOpen != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onOpen,
                        child: const Text('Ouvrir'),
                      ),
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: preparing ? null : onDownload,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          preparing
                              ? 'Ressource en préparation'
                              : 'Télécharger',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: onLater,
                        child: const Text('Plus tard'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    final mib = bytes / (1024 * 1024);
    return '${mib.toStringAsFixed(1)} Mio';
  }
}

class _Metadata extends StatelessWidget {
  final String label;
  final String value;
  const _Metadata({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label : ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}
