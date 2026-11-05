import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'reader.dart';
import 'categories.dart';
import 'storage.dart';
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
    final dark = mode == 'dark';
    final comfort = mode == 'comfort';
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff526d55),
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: dark
          ? const Color(0xff151c18)
          : comfort
          ? const Color(0xffeee9d8)
          : const Color(0xfff7f7f2),
    );
    return MaterialApp(
      title: 'Épinal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        useMaterial3: true,
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
  AppUpdate? available;
  Library get library => widget.library;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
                trailing: widget.appearance == choice.$1
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(c, choice.$1),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null) widget.onAppearance(selected);
  }

  Future<void> manage() async {
    await manageCategories(context, library);
    if (mounted)
      setState(() {
        if (selectedCategory != null &&
            selectedCategory!.isNotEmpty &&
            !library.categories.contains(selectedCategory))
          selectedCategory = null;
      });
  }

  Future<void> classify(Book book) async {
    await classifyBook(context, library, book);
    if (mounted) setState(() {});
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
              color: const Color(0xff1d2b22),
              padding: const EdgeInsets.fromLTRB(24, 25, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ÉPINAL   /   LECTEUR EPUB',
                          style: TextStyle(
                            color: Color(0xffb2c8ad),
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Apparence',
                        color: Colors.white,
                        onPressed: chooseAppearance,
                        icon: const Icon(Icons.palette_outlined),
                      ),
                      IconButton(
                        tooltip: 'Vérifier les mises à jour',
                        color: Colors.white,
                        onPressed: () => checkUpdate(),
                        icon: const Icon(Icons.system_update_alt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Votre bibliothèque',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Un peu de temps pour soi, une page à la fois.',
                    style: TextStyle(color: Color(0xffc4d0c3)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${library.books.length} LIVRE${library.books.length > 1 ? 'S' : ''}',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
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
                onChanged: (s) => setState(() => query = s),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
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
                              onSelected: (_) =>
                                  setState(() => selectedCategory = ''),
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
                  ),
                  IconButton(
                    tooltip: 'Gérer les catégories',
                    onPressed: manage,
                    icon: const Icon(Icons.create_new_folder_outlined),
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final b = items[i];
                        return Card(
                          color: scheme.surfaceContainerLow,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      Reader(library: library, book: b),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: b.hasCover
                                        ? Image.file(
                                            library.cover(b),
                                            width: 62,
                                            height: 86,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                fallback(),
                                          )
                                        : fallback(),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        const SizedBox(height: 5),
                                        Text(
                                          b.author.isEmpty
                                              ? 'Auteur inconnu'
                                              : b.author,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                        if (b.categories.isNotEmpty) ...[
                                          const SizedBox(height: 5),
                                          Text(
                                            b.categories.join(' · '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: scheme.primary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Text(
                                          b.cfi == null
                                              ? 'COMMENCER LA LECTURE →'
                                              : 'REPRENDRE · ${(b.progress * 100).round()} % →',
                                          style: TextStyle(
                                            color: scheme.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Options du livre',
                                    onSelected: (value) {
                                      if (value == 'classify') {
                                        classify(b);
                                      } else if (value == 'remove') {
                                        remove(b);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'classify',
                                        child: Text(
                                          'Classer dans des catégories',
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Retirer le livre'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (_, snap) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'ÉPINAL  ${snap.data?.version ?? ''}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget fallback() => Container(
    width: 62,
    height: 86,
    color: const Color(0xff526d55),
    child: const Icon(Icons.menu_book_rounded, color: Colors.white70, size: 30),
  );
}
