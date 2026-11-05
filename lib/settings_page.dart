import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'categories.dart';
import 'storage.dart';

class SettingsPage extends StatefulWidget {
  final Library library;
  final String appearance;
  final ValueChanged<String> onAppearance;
  final Future<void> Function() onCheckUpdate;
  const SettingsPage({
    super.key,
    required this.library,
    required this.appearance,
    required this.onAppearance,
    required this.onCheckUpdate,
  });
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String appearance = widget.appearance;
  bool checking = false;
  String get appearanceLabel => switch (appearance) {
    'dark' => 'Sombre',
    'comfort' => 'Confort visuel',
    _ => 'Clair',
  };
  Future<void> chooseAppearance() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Apparence',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final choice in <(String, String, IconData)>[
              ('light', 'Clair', Icons.light_mode_outlined),
              ('dark', 'Sombre', Icons.dark_mode_outlined),
              ('comfort', 'Confort visuel', Icons.remove_red_eye_outlined),
            ])
              ListTile(
                leading: Icon(choice.$3),
                title: Text(choice.$2),
                subtitle: choice.$1 == 'comfort'
                    ? const Text('Couleurs chaudes et fond adouci')
                    : null,
                trailing: appearance == choice.$1
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(c, choice.$1),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => appearance = selected);
      widget.onAppearance(selected);
    }
  }

  Future<void> check() async {
    if (checking) return;
    setState(() => checking = true);
    try {
      await widget.onCheckUpdate();
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'PERSONNALISATION',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Apparence'),
                  subtitle: Text(appearanceLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: chooseAppearance,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('Gérer les catégories'),
                  subtitle: const Text('Créer, renommer ou supprimer'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => manageCategories(context, widget.library),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'APPLICATION',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: const Text('Vérifier les mises à jour'),
                  subtitle: const Text(
                    'Rechercher une nouvelle version sur GitHub',
                  ),
                  trailing: checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: checking ? null : check,
                ),
                const Divider(height: 1),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (_, snap) => ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Version'),
                    subtitle: Text(snap.data?.version ?? '—'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Vos livres, images de couverture et réglages sont conservés sur cet appareil.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
