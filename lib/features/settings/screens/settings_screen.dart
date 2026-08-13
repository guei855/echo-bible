import 'package:echo_bible/features/settings/screens/about_screen.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:echo_bible/core/resources/language_settings_service.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil et paramètres')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person_outline_rounded)),
            title: Text('Espace personnel'),
            subtitle: Text('Vos données restent enregistrées localement.'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Langue de l’application'),
            subtitle: const Text('Français (prioritaire)'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => SimpleDialog(
                title: const Text('Langue de l’application'),
                children: [
                  SimpleDialogOption(
                    onPressed: () async {
                      await LanguageSettingsService.save(AppLanguage.fr);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    child: const Text('Français'),
                  ),
                  SimpleDialogOption(
                    onPressed: () async {
                      await LanguageSettingsService.save(AppLanguage.en);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    child: const Text('English (resources)'),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: const Text('Gestion des téléchargements'),
            subtitle: const Text('Bibles et bases d’étude FR, EN et communes'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadManagerScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('À propos'),
            subtitle: const Text('Version, sources et licences'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
