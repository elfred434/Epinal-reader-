import 'package:flutter/material.dart';
import 'storage.dart';

/// A searchable picker avoids forcing readers to scroll through a long library.
class BookPickerDialog extends StatefulWidget {
  final List<Book> books;
  const BookPickerDialog({super.key, required this.books});
  @override
  State<BookPickerDialog> createState() => _BookPickerDialogState();
}

class _BookPickerDialogState extends State<BookPickerDialog> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final matches = widget.books
        .where(
          (book) => '${book.title} ${book.author}'.toLowerCase().contains(
            query.trim().toLowerCase(),
          ),
        )
        .toList();
    return Dialog(
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Quel livre compléter ?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                labelText: 'Rechercher un livre',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  widget.books.isEmpty
                      ? 'Ajoutez d’abord un livre à votre bibliothèque.'
                      : 'Aucun livre trouvé.',
                ),
              )
            else
              for (final book in matches)
                ListTile(
                  title: Text(book.title),
                  subtitle: book.author.isEmpty ? null : Text(book.author),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, book),
                ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
