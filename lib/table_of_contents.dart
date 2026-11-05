import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

/// Search ignores case, common diacritics, repeated spaces and French ligatures.
String normalizeChapterSearch(String input) {
  var value = input.toLowerCase().trim();
  const groups = {
    'a': 'àáâäãåā',
    'e': 'èéêëē',
    'i': 'ìíîïī',
    'o': 'òóôöõøō',
    'u': 'ùúûüū',
    'y': 'ýÿ',
    'c': 'ç',
    'n': 'ñ',
  };
  for (final entry in groups.entries) {
    value = value.replaceAll(RegExp('[${entry.value}]'), entry.key);
  }
  return value
      .replaceAll('œ', 'oe')
      .replaceAll('æ', 'ae')
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class ChapterEntry {
  final EpubChapter chapter;
  final int depth;
  const ChapterEntry(this.chapter, this.depth);
}

List<ChapterEntry> flattenChapters(
  List<EpubChapter> chapters, [
  int depth = 0,
]) => [
  for (final chapter in chapters) ...[
    ChapterEntry(chapter, depth),
    ...flattenChapters(chapter.subitems, depth + 1),
  ],
];

class TableOfContentsSheet extends StatefulWidget {
  final List<EpubChapter> chapters;
  final ValueChanged<String> onOpen;
  const TableOfContentsSheet({
    super.key,
    required this.chapters,
    required this.onOpen,
  });
  @override
  State<TableOfContentsSheet> createState() => _TableOfContentsSheetState();
}

class _TableOfContentsSheetState extends State<TableOfContentsSheet> {
  final input = TextEditingController();
  late final List<ChapterEntry> all = flattenChapters(widget.chapters);
  String query = '';
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeChapterSearch(query);
    final matches = normalized.isEmpty
        ? all
        : all
              .where(
                (entry) => normalizeChapterSearch(
                  entry.chapter.title,
                ).contains(normalized),
              )
              .toList();
    final size = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = math.max(100.0, math.min(size * .78, size - keyboard - 40));
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sommaire',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${matches.length} / ${all.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: input,
                  onChanged: (value) => setState(() => query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Rechercher un chapitre',
                    hintText: 'Titre ou numéro de chapitre',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer la recherche',
                            onPressed: () {
                              input.clear();
                              setState(() => query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: all.isEmpty
                    ? const Center(
                        child: Text('Sommaire non disponible pour ce livre.'),
                      )
                    : matches.isEmpty
                    ? const Center(child: Text('Aucun chapitre trouvé.'))
                    : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final item = matches[index];
                          return ListTile(
                            contentPadding: EdgeInsets.only(
                              left: 16 + math.min(item.depth, 6) * 16.0,
                              right: 16,
                            ),
                            title: Text(
                              item.chapter.title.trim().isEmpty
                                  ? 'Sans titre'
                                  : item.chapter.title.trim(),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onOpen(item.chapter.href);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
