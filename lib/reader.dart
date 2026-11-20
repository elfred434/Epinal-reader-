import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'storage.dart';
import 'reading_mode.dart';
import 'reading_mode_picker.dart';
import 'reader_actions.dart';
import 'page_flip_layer.dart';
import 'table_of_contents.dart';

class Reader extends StatefulWidget {
  final Library library;
  final Book book;
  const Reader({super.key, required this.library, required this.book});
  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> {
  final EpubController controller = EpubController();
  final FlutterTts tts = FlutterTts();
  final GlobalKey<PageFlipLayerState> flipLayer =
      GlobalKey<PageFlipLayerState>();
  List<EpubChapter> chapters = [];
  EpubTextSelection? selected;
  bool highlightsLoaded = false, speaking = false;
  late int font;
  late int theme;
  late ReadingMode readingMode;
  bool directionApplied = false, selectingText = false, viewerReady = false;
  double? touchX, touchY;
  late String? initialCfi;
  Library get store => widget.library;
  Book get book => widget.book;
  @override
  void initState() {
    super.initState();
    font = store.prefs.getInt('reader.font') ?? 18;
    theme = store.prefs.getInt('reader.theme') ?? 0;
    readingMode = ReadingMode.fromStorage(store.prefs.getString('reader.mode'));
    initialCfi = book.cfi;
    tts.setCompletionHandler(() {
      if (mounted) setState(() => speaking = false);
    });
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  EpubTheme readingTheme() => theme == 2
      ? EpubTheme.dark()
      : theme == 3
      ? EpubTheme.custom(
          backgroundDecoration: const BoxDecoration(color: Color(0xffe9e4ce)),
          foregroundColor: const Color(0xff343a2e),
          customCss: {
            'body': {'line-height': '1.7'},
            'p': {'line-height': '1.7'},
          },
        )
      : theme == 1
      ? EpubTheme.custom(
          backgroundDecoration: const BoxDecoration(color: Color(0xfff4ecd9)),
          foregroundColor: const Color(0xff43372a),
        )
      : EpubTheme.light();
  void message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void restoreHighlights() {
    if (highlightsLoaded) return;
    highlightsLoaded = true;
    for (final item in store.entries('highlights', book)) {
      final cfi = item['cfi'] as String?;
      if (cfi != null) controller.addHighlight(cfi: cfi, color: Colors.amber);
    }
  }

  Future<void> selectReadingMode() async {
    final chosen = await showModalBottomSheet<ReadingMode>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => ReadingModePicker(selected: readingMode),
    );
    if (chosen == null || chosen == readingMode || !mounted) return;
    await store.prefs.setString('reader.mode', chosen.name);
    if (!mounted) return;
    // Recreate the renderer with the saved CFI: changing direction and flow on
    // an existing WebView is not reliably supported by the EPUB library.
    setState(() {
      initialCfi = book.cfi;
      readingMode = chosen;
      directionApplied = false;
      viewerReady = false;
      highlightsLoaded = false;
      selectingText = false;
      touchX = touchY = null;
    });
  }

  void onViewerLoaded() {
    if (mounted && !viewerReady) setState(() => viewerReady = true);
    if (!directionApplied) {
      directionApplied = true;
      if (readingMode == ReadingMode.leftToRight ||
          readingMode == ReadingMode.rightToLeft ||
          readingMode == ReadingMode.flipBook) {
        // EPUB.js otherwise prioritizes a book's page-progression metadata
        // over the chosen default direction. The method name is constant;
        // the value is always one of our two trusted enum values.
        controller.webViewController?.callMethod('rendition.direction', [
          readingMode.direction.name,
        ]);
      }
    }
    restoreHighlights();
  }

  void onTouchStart(double x, double y) {
    touchX = x;
    touchY = y;
  }

  void onTouchEnd(double x, double y) {
    final startX = touchX, startY = touchY;
    touchX = touchY = null; // also prevents duplicate callbacks turning twice
    if (startX == null || startY == null || selectingText) return;
    final turn = pageTurnForSwipe(readingMode, x - startX, y - startY);
    if (turn != null) turnPage(turn, fromTop: startY < .5);
  }

  void turnPage(PageTurn turn, {bool fromTop = false}) {
    void navigate() {
      if (turn == PageTurn.next) {
        controller.next();
      } else {
        controller.prev();
      }
    }

    if (readingMode != ReadingMode.flipBook) {
      navigate();
      return;
    }
    final layer = flipLayer.currentState;
    if (layer == null) {
      navigate();
      return;
    }
    layer.turn(
      isForward: turn == PageTurn.next,
      fromTopCorner: fromTop,
      capture: controller.captureViewport,
      navigate: navigate,
    );
  }

  Color get pageBackground => switch (theme) {
    1 => const Color(0xfff4ecd9),
    2 => const Color(0xff121212),
    3 => const Color(0xffe9e4ce),
    _ => Colors.white,
  };

  Future<void> bookmark() async {
    final cfi = book.cfi;
    if (cfi == null || cfi.isEmpty) {
      message('La position du livre est en cours de chargement.');
      return;
    }
    final list = store.entries('marks', book);
    if (list.any((v) => v['cfi'] == cfi)) {
      message('Cette position est déjà enregistrée.');
      return;
    }
    list.insert(0, {
      'cfi': cfi,
      'label': 'Position ${(book.progress * 100).round()} %',
      'date': DateTime.now().toIso8601String(),
    });
    await store.putEntries('marks', book, list);
    message('Signet ajouté.');
  }

  Future<void> selectedActions() async {
    final selection = selected;
    if (selection == null ||
        selection.selectionCfi.isEmpty ||
        selection.selectedText.trim().isEmpty) {
      message('Sélectionnez d’abord un passage dans le livre.');
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                selection.selectedText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.highlight),
              title: const Text('Surligner et ajouter une note'),
              onTap: () => Navigator.pop(c, 'highlight'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copier'),
              onTap: () => Navigator.pop(c, 'copy'),
            ),
          ],
        ),
      ),
    );
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: selection.selectedText));
      message('Passage copié.');
    }
    if (action == 'highlight' && mounted) {
      final input = TextEditingController();
      final note = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ajouter une note'),
          content: TextField(
            controller: input,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Note facultative'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, input.text),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      );
      if (note == null) return;
      final list = store.entries('highlights', book);
      list.removeWhere((v) => v['cfi'] == selection.selectionCfi);
      list.insert(0, {
        'cfi': selection.selectionCfi,
        'text': selection.selectedText,
        'note': note,
      });
      await store.putEntries('highlights', book, list);
      controller.addHighlight(cfi: selection.selectionCfi, color: Colors.amber);
      controller.clearSelection();
      selected = null;
      message('Passage enregistré.');
    }
  }

  void chapterSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TableOfContentsSheet(
        chapters: chapters,
        onOpen: (href) => controller.display(cfi: href),
      ),
    );
  }

  void savedSheet(String kind) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) {
          final entries = store.entries(kind, book);
          return SizedBox(
            height: MediaQuery.sizeOf(c).height * .7,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    kind == 'marks' ? 'Mes signets' : 'Passages et notes',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('Aucun élément enregistré.'))
                      : ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (_, i) {
                            final item = entries[i];
                            return ListTile(
                              title: Text(
                                (item['label'] ?? item['text'] ?? '') as String,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: (item['note'] as String? ?? '').isEmpty
                                  ? null
                                  : Text(item['note'] as String),
                              trailing: IconButton(
                                tooltip: 'Supprimer',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  entries.removeAt(i);
                                  await store.putEntries(kind, book, entries);
                                  if (kind == 'highlights')
                                    controller.removeHighlight(
                                      cfi: item['cfi'] as String,
                                    );
                                  refresh(() {});
                                },
                              ),
                              onTap: () {
                                Navigator.pop(c);
                                controller.display(cfi: item['cfi'] as String);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> search() async {
    final input = TextEditingController();
    List<EpubSearchResult> results = [];
    bool loading = false, searched = false, failed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) {
          Future<void> runSearch() async {
            final query = input.text.trim();
            if (loading || query.isEmpty) return;
            refresh(() {
              loading = true;
              searched = true;
              failed = false;
            });
            try {
              results = await controller.search(query: query);
            } catch (_) {
              results = [];
              failed = true;
            }
            if (c.mounted) refresh(() => loading = false);
          }

          final screen = MediaQuery.sizeOf(c).height;
          final keyboard = MediaQuery.viewInsetsOf(c).bottom;
          final height = math.max(
            100.0,
            math.min(screen * .7, screen - keyboard - 60),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: height,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: input,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => runSearch(),
                              decoration: const InputDecoration(
                                labelText: 'Rechercher dans le livre',
                                hintText: 'Mot ou phrase',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Lancer la recherche',
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: loading ? null : runSearch,
                          ),
                        ],
                      ),
                    ),
                    if (loading) const LinearProgressIndicator(),
                    Expanded(
                      child: results.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  failed
                                      ? 'Recherche indisponible. Réessayez.'
                                      : searched && !loading
                                      ? 'Aucun résultat.'
                                      : 'Saisissez un mot ou une phrase.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (_, i) => ListTile(
                                title: Text(results[i].excerpt),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pop(c);
                                  controller.display(cfi: results[i].cfi);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    input.dispose();
  }

  Future<void> showReaderActions() async {
    final action = await showModalBottomSheet<ReaderAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          ReaderActionsSheet(speaking: speaking, modeLabel: readingMode.label),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ReaderAction.search:
        search();
      case ReaderAction.marks:
        savedSheet('marks');
      case ReaderAction.addMark:
        bookmark();
      case ReaderAction.selection:
        selectedActions();
      case ReaderAction.highlights:
        savedSheet('highlights');
      case ReaderAction.mode:
        selectReadingMode();
      case ReaderAction.settings:
        options();
      case ReaderAction.speak:
        speakPage();
    }
  }

  void options() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(c).height * .8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confort de lecture',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Taille du texte'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Diminuer la taille du texte',
                          onPressed: () {
                            font = (font - 2).clamp(12, 36);
                            controller.setFontSize(fontSize: font.toDouble());
                            store.prefs.setInt('reader.font', font);
                            refresh(() {});
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$font'),
                        IconButton(
                          tooltip: 'Augmenter la taille du texte',
                          onPressed: () {
                            font = (font + 2).clamp(12, 36);
                            controller.setFontSize(fontSize: font.toDouble());
                            store.prefs.setInt('reader.font', font);
                            refresh(() {});
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: List.generate(
                        4,
                        (i) => ChoiceChip(
                          label: Text(
                            ['Clair', 'Sépia', 'Sombre', 'Confort visuel'][i],
                          ),
                          selected: theme == i,
                          onSelected: (_) {
                            setState(() => theme = i);
                            store.prefs.setInt('reader.theme', i);
                            controller.updateTheme(theme: readingTheme());
                            refresh(() {});
                          },
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.view_carousel_outlined),
                      title: const Text('Mode de lecture'),
                      subtitle: Text(readingMode.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(c);
                        selectReadingMode();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> speakPage() async {
    if (speaking) {
      await tts.stop();
      if (mounted) setState(() => speaking = false);
      return;
    }
    try {
      final text =
          (await controller.extractCurrentPageText()).text?.trim() ?? '';
      if (text.isEmpty) {
        message('Aucun texte à lire sur cette page.');
        return;
      }
      await tts.setLanguage('fr-FR');
      await tts.setSpeechRate(.5);
      if (mounted) setState(() => speaking = true);
      await tts.speak(text);
    } catch (_) {
      message('La lecture vocale est indisponible sur cet appareil.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Sommaire',
          onPressed: chapterSheet,
          icon: const Icon(Icons.list_alt_outlined),
        ),
        IconButton(
          tooltip: 'Confort de lecture',
          onPressed: viewerReady ? options : null,
          icon: const Icon(Icons.text_fields),
        ),
        IconButton(
          tooltip: 'Outils de lecture',
          onPressed: viewerReady ? showReaderActions : null,
          icon: const Icon(Icons.more_horiz),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageFlipLayer(
              key: flipLayer,
              enabled: readingMode == ReadingMode.flipBook,
              pageColor: pageBackground,
              child: EpubViewer(
                key: ValueKey(readingMode.name),
                epubController: controller,
                epubSource: EpubSource.fromFile(store.file(book)),
                initialCfi: initialCfi,
                initialLocations: store.prefs.getString('locations.${book.id}'),
                displaySettings: EpubDisplaySettings(
                  fontSize: font,
                  flow: readingMode.flow,
                  manager: EpubManager.continuous,
                  spread: EpubSpread.none,
                  defaultDirection: readingMode.direction,
                  // Disable the plugin's Android-only horizontal gesture handler:
                  // it otherwise prevents vertical dragging, even in scrolled mode.
                  snap: false,
                  useSnapAnimationAndroid: true,
                  theme: readingTheme(),
                  allowScriptedContent: false,
                ),
                onChaptersLoaded: (v) {
                  if (mounted) setState(() => chapters = v);
                },
                onEpubLoaded: onViewerLoaded,
                onTouchDown: onTouchStart,
                onTouchUp: onTouchEnd,
                onTextSelected: (v) {
                  selectingText = true;
                  selected = v;
                },
                onSelectionChanging: () => selectingText = true,
                onDeselection: () => selectingText = false,
                onLocationsGenerated: (v) =>
                    store.prefs.setString('locations.${book.id}', v),
                onRelocated: (v) {
                  book.cfi = v.startCfi;
                  book.progress = v.progress.clamp(0, 1);
                  store.save();
                  if (mounted) setState(() {});
                },
                onLoadError: (e) =>
                    message('Impossible de lire cet EPUB : ${e.message}'),
              ),
            ),
          ),
          if (!viewerReady) const LinearProgressIndicator(minHeight: 2),
          if (viewerReady)
            LinearProgressIndicator(
              value: book.progress.clamp(0, 1),
              minHeight: 2,
              semanticsLabel: 'Progression dans le livre',
            ),
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: readingMode == ReadingMode.rightToLeft
                      ? 'Page suivante'
                      : 'Page précédente',
                  onPressed: viewerReady
                      ? () => turnPage(
                          readingMode == ReadingMode.rightToLeft
                              ? PageTurn.next
                              : PageTurn.previous,
                        )
                      : null,
                  icon: Icon(
                    readingMode == ReadingMode.vertical ||
                            readingMode.isContinuous
                        ? Icons.arrow_upward
                        : Icons.arrow_back,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Progression · ${(book.progress * 100).round()} %',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Ajouter un signet',
                  onPressed: viewerReady ? bookmark : null,
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
                IconButton(
                  tooltip: readingMode == ReadingMode.rightToLeft
                      ? 'Page précédente'
                      : 'Page suivante',
                  onPressed: viewerReady
                      ? () => turnPage(
                          readingMode == ReadingMode.rightToLeft
                              ? PageTurn.previous
                              : PageTurn.next,
                        )
                      : null,
                  icon: Icon(
                    readingMode == ReadingMode.vertical ||
                            readingMode.isContinuous
                        ? Icons.arrow_downward
                        : Icons.arrow_forward,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
