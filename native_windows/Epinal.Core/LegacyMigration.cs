using System.Text.Json;

namespace Epinal.Core;

public static class LegacyMigration
{
    /// Copies a closed Flutter profile, retains a complete backup, then imports
    /// into an empty, independent native library. The source is never modified.
    public static async Task<string> ImportAsync(NativeLibrary library, string source, CancellationToken cancellation = default)
    {
        if (library.Books.Count != 0 || Directory.EnumerateFileSystemEntries(library.BooksPath).Any())
            throw new InvalidOperationException("La bibliothèque native doit être vide avant la reprise.");
        var snapshot = Path.Combine(library.Root, "sauvegarde-flutter-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N")[..8]);
        await LegacySnapshot.CreateAsync(source, snapshot, cancellation);
        var stage = Path.Combine(library.Root, ".migration-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(stage);
        var converted = new List<NativeBook>();
        try
        {
            var old = LegacyLibrary.Load(snapshot);
            using var prefs = JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(snapshot, "shared_preferences.json"), cancellation));
            foreach (var entry in old.Books)
            {
                cancellation.ThrowIfCancellationRequested();
                if (!entry.EpubExists) throw new IOException("Fichier EPUB manquant : " + entry.Title);
                var book = new NativeBook { Id = entry.Id, Title = entry.Title, Author = entry.Author, Cfi = entry.Cfi, Progress = entry.Progress, Categories = entry.Categories.ToList() };
                foreach (var mark in Entries(prefs.RootElement, "flutter.marks." + entry.Id))
                    if (mark.TryGetProperty("cfi", out var c) && c.ValueKind == JsonValueKind.String) book.Bookmarks.Add(c.GetString()!);
                foreach (var item in Entries(prefs.RootElement, "flutter.highlights." + entry.Id))
                    if (item.TryGetProperty("cfi", out var c) && c.ValueKind == JsonValueKind.String)
                        book.Highlights.Add(new NativeHighlight { Cfi = c.GetString()!, Text = item.TryGetProperty("text", out var t) && t.ValueKind == JsonValueKind.String ? t.GetString()! : "", Note = item.TryGetProperty("note", out var n) && n.ValueKind == JsonValueKind.String ? n.GetString()! : "" });
                var src = Path.Combine(snapshot, "books", entry.Id + ".epub");
                var dst = Path.Combine(stage, entry.Id + ".epub");
                File.Copy(src, dst);
                if (await PositionCode.FileHashAsync(src, cancellation) != await PositionCode.FileHashAsync(dst, cancellation)) throw new IOException("Copie EPUB incomplète.");
                var cover = Path.Combine(snapshot, "books", entry.Id + ".jpg");
                if (File.Exists(cover)) File.Copy(cover, Path.Combine(stage, entry.Id + ".jpg"));
                var oldBackup = Path.Combine(snapshot, "books", entry.Id + ".previous.epub");
                if (File.Exists(oldBackup))
                {
                    // Keep the last Flutter edition restorable, never trusting a
                    // saved position unless its hash matches the backup bytes.
                    NativeLibrary.InspectEpub(oldBackup);
                    var backupHash = await PositionCode.FileHashAsync(oldBackup, cancellation);
                    string? oldCfi = null; double oldProgress = 0;
                    var key = "flutter.edition.backup." + entry.Id;
                    if (prefs.RootElement.TryGetProperty(key, out var encoded) && encoded.ValueKind == JsonValueKind.String)
                    {
                        try
                        {
                            using var previous = JsonDocument.Parse(encoded.GetString() ?? "{}");
                            var state = previous.RootElement;
                            if (state.TryGetProperty("sha256", out var hash) && hash.ValueKind == JsonValueKind.String && hash.GetString() == backupHash)
                            {
                                if (state.TryGetProperty("cfi", out var cfi) && cfi.ValueKind == JsonValueKind.String) oldCfi = cfi.GetString();
                                if (state.TryGetProperty("progress", out var progress) && progress.ValueKind == JsonValueKind.Number && progress.TryGetDouble(out var p) && double.IsFinite(p) && p is >= 0 and <= 1) oldProgress = p;
                            }
                        }
                        catch (JsonException) { /* Backup is retained with a safe reset position. */ }
                    }
                    var dstBackup = dst + ".previous";
                    File.Copy(oldBackup, dstBackup);
                    if (backupHash != await PositionCode.FileHashAsync(dstBackup, cancellation)) throw new IOException("Copie de l’édition précédente incomplète.");
                    await File.WriteAllTextAsync(dstBackup + ".json", JsonSerializer.Serialize(new { Hash = backupHash, Cfi = oldCfi, Progress = oldProgress }), cancellation);
                }
                converted.Add(book);
            }
            // Every book and metadata was validated before touching the native index.
            Directory.Delete(library.BooksPath); Directory.Move(stage, library.BooksPath);
            library.Books.AddRange(converted);
            var previousCategories = library.Categories.ToList();
            foreach (var category in old.Categories.Concat(converted.SelectMany(x => x.Categories)))
                if (!library.Categories.Contains(category, StringComparer.OrdinalIgnoreCase)) library.Categories.Add(category);
            try
            {
                var preferences = ReaderPreferences.FromFlutter(prefs.RootElement);
                await preferences.SaveAsync(library.Root);
                await library.SaveAsync();
            }
            catch
            {
                library.Books.Clear();
                library.Categories.Clear(); library.Categories.AddRange(previousCategories);
                Directory.Delete(library.BooksPath, true); Directory.CreateDirectory(library.BooksPath);
                throw;
            }
            return snapshot;
        }
        finally { if (Directory.Exists(stage)) Directory.Delete(stage, true); }
    }
    private static IEnumerable<JsonElement> Entries(JsonElement root, string key)
    {
        if (!root.TryGetProperty(key, out var encoded)) return [];
        if (encoded.ValueKind != JsonValueKind.String) throw new FormatException("Annotations illisibles : " + key);
        using var doc = JsonDocument.Parse(encoded.GetString() ?? "[]");
        if (doc.RootElement.ValueKind != JsonValueKind.Array) throw new FormatException("Annotations illisibles : " + key);
        return doc.RootElement.EnumerateArray().Select(x => x.Clone()).ToArray();
    }
}
