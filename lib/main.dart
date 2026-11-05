import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'reader.dart';
import 'storage.dart';
import 'update.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final library = Library();
  await library.init();
  runApp(Epinal(library: library));
}

class Epinal extends StatelessWidget {
  final Library library;
  const Epinal({super.key, required this.library});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Épinal',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff526d55),
        surface: const Color(0xfff7f7f2),
      ),
      useMaterial3: true,
    ),
    home: Shelf(library: library),
  );
}

class Shelf extends StatefulWidget {
  final Library library;
  const Shelf({super.key, required this.library});
  @override
  State<Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<Shelf> with WidgetsBindingObserver {
  String query = '';
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

  @override
  Widget build(BuildContext context) {
    final items = library.books
        .where(
          (b) => '${b.title} ${b.author}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f2),
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
                      style: const TextStyle(
                        color: Color(0xff526d55),
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
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
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
                            color: Colors.grey.shade600,
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
                          color: Colors.white,
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
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          b.cfi == null
                                              ? 'COMMENCER LA LECTURE →'
                                              : 'REPRENDRE · ${(b.progress * 100).round()} % →',
                                          style: const TextStyle(
                                            color: Color(0xff526d55),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Retirer',
                                    onPressed: () => remove(b),
                                    icon: const Icon(Icons.more_vert),
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
