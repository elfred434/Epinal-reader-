import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'reader.dart';
import 'palette.dart';
import 'categories.dart';
import 'storage.dart';
import 'settings_page.dart';
import 'update.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final library = Library();
  await library.init();
  runApp(Epinal(library: library));
}

class Epinal extends StatefulWidget {
  final Library library;
  const Epinal({super.key, required this.library});
  @override
  State<Epinal> createState() => _EpinalState();
}

class _EpinalState extends State<Epinal> {
  late String mode;
  @override
  void initState() {
    super.initState();
    mode = widget.library.prefs.getString('app.appearance') ?? 'light';
    if (!['light', 'dark', 'comfort'].contains(mode)) mode = 'light';
  }

  void setMode(String value) {
    setState(() => mode = value);
    widget.library.prefs.setString('app.appearance', value);
    // A global appearance choice also gives books the matching reading palette.
    widget.library.prefs.setInt(
      'reader.theme',
      value == 'dark'
          ? 2
          : value == 'comfort'
          ? 3
          : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = EpinalPalette.scheme(mode);
    return MaterialApp(
      title: 'Épinal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        useMaterial3: true,
        sliderTheme: const SliderThemeData(
          activeTrackColor: EpinalPalette.gold,
          thumbColor: EpinalPalette.gold,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: EpinalPalette.gold,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: .12)
                  : mode == 'dark'
                  ? scheme.primary
                  : EpinalPalette.garance,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: .38)
                  : mode == 'dark'
                  ? scheme.onPrimary
                  : Colors.white,
            ),
          ),
        ),
      ),
      home: Shelf(
        library: widget.library,
        appearance: mode,
        onAppearance: setMode,
      ),
    );
  }
}

class Shelf extends StatefulWidget {
  final Library library;
  final String appearance;
  final ValueChanged<String> onAppearance;
  const Shelf({
    super.key,
    required this.library,
    required this.appearance,
    required this.onAppearance,
  });
  @override
  State<Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<Shelf> with WidgetsBindingObserver {
  String query = '';
  String? selectedCategory; // null = all, empty string = unclassified.
  bool busy = false, checking = false, waitingPermission = false;
  late bool gridView;
  AppUpdate? available;
  Library get library => widget.library;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gridView = library.prefs.getBool('library.grid') ?? false;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => checkUpdate(quiet: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && waitingPermission) {
      waitingPermission = false;
      installUpdate();
    }
  }

  void snack(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> importBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );
      if (result == null || result.files.single.path == null) return;
      setState(() => busy = true);
      final before = library.books.length;
      await library.importFile(File(result.files.single.path!));
      if (mounted) {
        setState(() {});
        snack(
          before == library.books.length
              ? 'Ce livre est déjà dans votre bibliothèque.'
              : 'Livre ajouté à votre bibliothèque.',
        );
      }
    } catch (e) {
      snack(
        'Import impossible. Vérifiez que le fichier est un EPUB valide et sans DRM.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> checkUpdate({bool quiet = false}) async {
    if (checking) return;
    checking = true;
    try {
      final update = await Updater.check();
      if (!mounted) return;
      if (update == null) {
        if (!quiet) snack('Vous disposez de la dernière version publiée.');
        return;
      }
      available = update;
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mise à jour disponible'),
          content: Text(
            'La version ${update.version.substring(1)} est disponible. Elle conserve votre bibliothèque et remplace la version installée après votre confirmation Android.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Plus tard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mettre à jour'),
            ),
          ],
        ),
      );
      if (yes == true && mounted) await downloadUpdate(update);
    } catch (e) {
      if (!quiet) snack('Vérification impossible : $e');
    } finally {
      checking = false;
    }
  }

  Future<void> downloadUpdate(AppUpdate update) async {
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await Updater.download(update);
      if (mounted) await installUpdate();
    } catch (e) {
      snack('Mise à jour impossible : $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> installUpdate() async {
    try {
      final result = await Updater.install();
      if (result == 'permission') {
        waitingPermission = true;
        snack(
          'Autorisez Épinal à installer les mises à jour, puis revenez dans l’application.',
        );
      }
    } catch (e) {
      snack('Installation impossible : $e');
    }
  }

  Future<void> remove(Book b) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Retirer ce livre ?'),
        content: const Text(
          'Le livre et ses annotations seront retirés de l’application. Le fichier d’origine ne sera pas supprimé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await library.remove(b);
      if (mounted) setState(() {});
    }
  }

  Future<void> openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          library: library,
          appearance: widget.appearance,
          onAppearance: widget.onAppearance,
          onCheckUpdate: () => checkUpdate(),
        ),
      ),
    );
    if (mounted)
      setState(() {
        if (selectedCategory != null &&
            selectedCategory!.isNotEmpty &&
            !library.categories.contains(selectedCategory))
          selectedCategory = null;
      });
  }

  Future<void> setView(bool grid) async {
    setState(() => gridView = grid);
    await library.prefs.setBool('library.grid', grid);
  }

  Future<void> chooseCover(Book book) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      setState(() => busy = true);
      await library.setCustomCover(book, File(path));
      await FileImage(library.cover(book)).evict();
      if (mounted) setState(() {});
      snack('Couverture mise à jour.');
    } catch (e) {
      snack(
        e is FormatException
            ? e.message
            : 'Impossible de lire cette image. Choisissez un JPG, PNG ou WebP valide.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restoreCover(Book book) async {
    if (mounted) setState(() => busy = true);
    try {
      await library.restoreOriginalCover(book);
      await FileImage(library.cover(book)).evict();
      if (mounted) setState(() {});
      snack(
        book.hasCover
            ? 'Couverture originale restaurée.'
            : 'Aucune couverture dans ce livre.',
      );
    } catch (_) {
      snack('Impossible de restaurer la couverture de ce livre.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> classify(Book book) async {
    await classifyBook(context, library, book);
    if (mounted) setState(() {});
  }

  Future<void> openBook(Book book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Reader(library: library, book: book),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget coverFor(Book book, {required double width, required double height}) {
    Widget fallback() => Container(
      width: width,
      height: height,
      color: EpinalPalette.outremer,
      child: const Icon(
        Icons.menu_book_rounded,
        color: Colors.white70,
        size: 30,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: book.hasCover
          ? Image.file(
              library.cover(book),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            )
          : fallback(),
    );
  }

  Widget bookMenu(Book book) => PopupMenuButton<String>(
    tooltip: 'Options du livre',
    onSelected: (value) {
      switch (value) {
        case 'cover':
          chooseCover(book);
        case 'restore':
          restoreCover(book);
        case 'classify':
          classify(book);
        case 'remove':
          remove(book);
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'cover',
        child: Text('Choisir une image de couverture'),
      ),
      PopupMenuItem(
        value: 'restore',
        child: Text('Restaurer la couverture EPUB'),
      ),
      PopupMenuItem(
        value: 'classify',
        child: Text('Classer dans des catégories'),
      ),
      PopupMenuItem(value: 'remove', child: Text('Retirer le livre')),
    ],
  );

  Widget listItem(Book b) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openBook(b),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              coverFor(b, width: 62, height: 86),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.author.isEmpty ? 'Auteur inconnu' : b.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    if (b.categories.isNotEmpty)
                      Text(
                        b.categories.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.primary, fontSize: 11),
                      ),
                    const SizedBox(height: 7),
                    Text(
                      b.cfi == null
                          ? 'À LIRE'
                          : '${(b.progress * 100).round()} % LU',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              bookMenu(b),
            ],
          ),
        ),
      ),
    );
  }

  Widget gridItem(Book b) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => openBook(b),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: coverFor(
                      b,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: .9),
                        shape: BoxShape.circle,
                      ),
                      child: bookMenu(b),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    b.author.isEmpty ? 'Auteur inconnu' : b.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    b.cfi == null
                        ? 'À LIRE'
                        : '${(b.progress * 100).round()} % LU',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = library.books
        .where(
          (b) =>
              selectedCategory == null ||
              (selectedCategory == ''
                  ? b.categories.isEmpty
                  : b.categories.contains(selectedCategory)),
        )
        .where(
          (b) => '${b.title} ${b.author}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: scheme.brightness == Brightness.dark
                  ? EpinalPalette.nightCard
                  : EpinalPalette.outremer,
              padding: const EdgeInsets.fromLTRB(20, 12, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ÉPINAL  /  LECTEUR EPUB',
                          style: TextStyle(
                            color: Color(0xffd5e3ff),
                            fontSize: 11,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Paramètres',
                        color: Colors.white,
                        onPressed: openSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const Text(
                    'Votre bibliothèque',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${library.books.length} LIVRE${library.books.length > 1 ? 'S' : ''}',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Vue liste',
                    isSelected: !gridView,
                    onPressed: () => setView(false),
                    icon: const Icon(Icons.view_list_outlined),
                    selectedIcon: const Icon(Icons.view_list),
                  ),
                  IconButton(
                    tooltip: 'Vue cartes',
                    isSelected: gridView,
                    onPressed: () => setView(true),
                    icon: const Icon(Icons.grid_view_outlined),
                    selectedIcon: const Icon(Icons.grid_view),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: busy ? null : importBook,
                    icon: const Icon(Icons.add),
                    label: const Text('Importer'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Rechercher un titre ou un auteur',
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Tous'),
                      selected: selectedCategory == null,
                      onSelected: (_) =>
                          setState(() => selectedCategory = null),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Sans catégorie'),
                      selected: selectedCategory == '',
                      onSelected: (_) => setState(() => selectedCategory = ''),
                    ),
                  ),
                  for (final category in library.categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: selectedCategory == category,
                        onSelected: (_) =>
                            setState(() => selectedCategory = category),
                      ),
                    ),
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          library.books.isEmpty
                              ? 'Votre prochaine histoire commence ici.\n\nImportez un fichier EPUB depuis votre appareil.'
                              : 'Aucun livre ne correspond à votre recherche.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                      ),
                    )
                  : gridView
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final count = constraints.maxWidth >= 700
                            ? 4
                            : constraints.maxWidth >= 500
                            ? 3
                            : 2;
                        final width =
                            (constraints.maxWidth - 40 - (count - 1) * 12) /
                            count;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          itemCount: items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: count,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: width * 1.15 + 90,
                              ),
                          itemBuilder: (_, index) => gridItem(items[index]),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: items.length,
                      itemBuilder: (_, index) => listItem(items[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
