import 'package:flutter/material.dart';
import 'book_update.dart';

/// A choice is required for every change; no conflict is silently overwritten.
class BookUpdateReview extends StatefulWidget {
  final String bookTitle;
  final EditionComparison comparison;
  const BookUpdateReview({
    super.key,
    required this.bookTitle,
    required this.comparison,
  });
  @override
  State<BookUpdateReview> createState() => _BookUpdateReviewState();
}

class _BookUpdateReviewState extends State<BookUpdateReview> {
  final Map<String, bool> decisions = {};
  @override
  Widget build(BuildContext context) {
    final comparison = widget.comparison;
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer la suite')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.bookTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (comparison.incomingTitle.isNotEmpty)
                  Text('Fichier choisi : ${comparison.incomingTitle}'),
                const SizedBox(height: 12),
                Text(
                  '${comparison.added.length} nouvelle(s) section(s) · ${comparison.conflicts.length} modification(s)',
                ),
                if (comparison.added.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Sections ajoutées',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...comparison.added.map(
                    (name) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.add_circle_outline),
                      title: Text(name),
                    ),
                  ),
                ],
                if (comparison.conflicts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Choisissez une version pour chaque modification. Les images et styles modifiés peuvent affecter plusieurs sections.',
                  ),
                  for (final change in comparison.conflicts)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              change.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              change.chapter
                                  ? 'Section modifiée'
                                  : 'Ressource modifiée : ${change.path}',
                            ),
                            if (change.chapter)
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('Comparer les extraits'),
                                children: [
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Version actuelle',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SelectableText(
                                    change.oldExcerpt.isEmpty
                                        ? '(Vide)'
                                        : change.oldExcerpt,
                                  ),
                                  const SizedBox(height: 8),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Nouvelle version',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SelectableText(
                                    change.newExcerpt.isEmpty
                                        ? '(Vide)'
                                        : change.newExcerpt,
                                  ),
                                  const Text(
                                    'Extraits autour de la première différence de texte ; les autres changements ou la mise en forme peuvent ne pas apparaître.',
                                  ),
                                ],
                              ),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Garder'),
                                  selected: decisions[change.path] == true,
                                  onSelected: (_) => setState(
                                    () => decisions[change.path] = true,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Remplacer'),
                                  selected: decisions[change.path] == false,
                                  onSelected: (_) => setState(
                                    () => decisions[change.path] = false,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Les signets et annotations restent enregistrés, mais leur position peut se décaler si une section est modifiée. La dernière version précédente sera conservée pour restauration.',
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const FittedBox(child: Text('Annuler')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          decisions.length == comparison.conflicts.length &&
                              (comparison.added.isNotEmpty ||
                                  comparison.conflicts.isNotEmpty)
                          ? () => Navigator.pop(
                              context,
                              Map<String, bool>.of(decisions),
                            )
                          : null,
                      child: const FittedBox(child: Text('Appliquer')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
