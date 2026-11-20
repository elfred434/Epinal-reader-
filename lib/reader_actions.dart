import 'package:flutter/material.dart';

enum ReaderAction {
  search,
  marks,
  addMark,
  selection,
  highlights,
  mode,
  settings,
  speak,
}

/// All secondary reader tools have a name and are grouped by purpose.
class ReaderActionsSheet extends StatelessWidget {
  final bool speaking;
  final String modeLabel;
  const ReaderActionsSheet({
    super.key,
    required this.speaking,
    required this.modeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget heading(String value) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Text(
        value,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
    Widget item(
      ReaderAction action,
      IconData icon,
      String title, [
      String? subtitle,
    ]) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pop(context, action),
    );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Outils de lecture',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  heading('DANS CE LIVRE'),
                  item(
                    ReaderAction.search,
                    Icons.search,
                    'Rechercher dans le livre',
                  ),
                  item(
                    ReaderAction.marks,
                    Icons.bookmarks_outlined,
                    'Mes signets',
                  ),
                  item(
                    ReaderAction.addMark,
                    Icons.bookmark_add_outlined,
                    'Ajouter un signet',
                  ),
                  item(
                    ReaderAction.highlights,
                    Icons.edit_note_outlined,
                    'Passages et notes',
                  ),
                  item(
                    ReaderAction.selection,
                    Icons.highlight_outlined,
                    'Surligner la sélection',
                    'Sélectionnez d’abord un passage',
                  ),
                  heading('LECTURE'),
                  item(
                    ReaderAction.mode,
                    Icons.view_carousel_outlined,
                    'Mode de lecture',
                    modeLabel,
                  ),
                  item(
                    ReaderAction.settings,
                    Icons.text_fields,
                    'Confort de lecture',
                    'Taille du texte et couleurs',
                  ),
                  item(
                    ReaderAction.speak,
                    speaking
                        ? Icons.stop_circle_outlined
                        : Icons.volume_up_outlined,
                    speaking
                        ? 'Arrêter la lecture vocale'
                        : 'Lire cette page à voix haute',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
