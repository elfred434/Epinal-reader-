import 'package:flutter/material.dart';
import 'storage.dart';

Future<String?> _categoryName(
  BuildContext context,
  Library library, {
  String? previous,
}) async {
  final input = TextEditingController(text: previous ?? '');
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, refresh) => AlertDialog(
        title: Text(
          previous == null ? 'Nouvelle catégorie' : 'Renommer la catégorie',
        ),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ex. Romans, Études…',
            errorText: error,
          ),
          onSubmitted: (_) {
            try {
              Navigator.pop(
                dialogContext,
                library.validateCategory(input.text, except: previous),
              );
            } on FormatException catch (e) {
              refresh(() => error = e.message);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              try {
                Navigator.pop(
                  dialogContext,
                  library.validateCategory(input.text, except: previous),
                );
              } on FormatException catch (e) {
                refresh(() => error = e.message);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
  input.dispose();
  return result;
}

Future<void> manageCategories(BuildContext context, Library library) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, refresh) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Mes catégories',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Créer une catégorie',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () async {
                        final name = await _categoryName(sheetContext, library);
                        if (name != null) {
                          await library.createCategory(name);
                          if (sheetContext.mounted) refresh(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Organisez vos livres en une ou plusieurs catégories.',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: library.categories.isEmpty
                    ? const Center(
                        child: Text('Créez votre première catégorie avec +.'),
                      )
                    : ListView.builder(
                        itemCount: library.categories.length,
                        itemBuilder: (context, index) {
                          final category = library.categories[index];
                          final count = library.books
                              .where((b) => b.categories.contains(category))
                              .length;
                          return ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(category),
                            subtitle: Text(
                              '$count livre${count > 1 ? 's' : ''}',
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: 'Renommer $category',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    final name = await _categoryName(
                                      sheetContext,
                                      library,
                                      previous: category,
                                    );
                                    if (name != null) {
                                      await library.renameCategory(
                                        category,
                                        name,
                                      );
                                      if (sheetContext.mounted) refresh(() {});
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Supprimer $category',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: sheetContext,
                                      builder: (d) => AlertDialog(
                                        title: const Text(
                                          'Supprimer la catégorie ?',
                                        ),
                                        content: Text(
                                          '« $category » sera retirée des livres. Les livres eux-mêmes seront conservés.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(d, false),
                                            child: const Text('Annuler'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(d, true),
                                            child: const Text('Supprimer'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await library.deleteCategory(category);
                                      if (sheetContext.mounted) refresh(() {});
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> classifyBook(
  BuildContext context,
  Library library,
  Book book,
) async {
  final selected = book.categories.toSet();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, refresh) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Classer le livre',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Créer une catégorie',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () async {
                        final name = await _categoryName(sheetContext, library);
                        if (name != null) {
                          await library.createCategory(name);
                          selected.add(name);
                          if (sheetContext.mounted) refresh(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: library.categories.isEmpty
                    ? const Center(child: Text('Créez une catégorie avec +.'))
                    : ListView(
                        children: [
                          for (final category in library.categories)
                            CheckboxListTile(
                              title: Text(category),
                              value: selected.contains(category),
                              onChanged: (checked) => refresh(() {
                                if (checked == true) {
                                  selected.add(category);
                                } else {
                                  selected.remove(category);
                                }
                              }),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await library.classify(book, selected);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Enregistrer'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
