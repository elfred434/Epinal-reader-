using System.Text.Json;

namespace Epinal.Core;

public sealed record LegacyBook(string Id, string Title, string Author, bool HasCover, string? Cfi, double Progress, IReadOnlyList<string> Categories, bool EpubExists);
public sealed record LegacyLibrary(IReadOnlyList<LegacyBook> Books, IReadOnlyList<string> Categories)
{
    /// Reads a verified snapshot, never the live Flutter preferences. Fail closed
    /// on malformed data instead of interpreting it as an empty library.
    public static LegacyLibrary Load(string snapshotPath)
    {
        using var prefs = JsonDocument.Parse(File.ReadAllText(Path.Combine(snapshotPath, "shared_preferences.json")));
        var root = prefs.RootElement;
        if (root.ValueKind != JsonValueKind.Object) throw new FormatException("Préférences illisibles.");
        var categories = new List<string>();
        if (root.TryGetProperty("flutter.categories.v1", out var cat))
            foreach (var item in cat.EnumerateArray()) categories.Add(item.GetString() ?? throw new FormatException("Catégorie invalide."));
        var books = new List<LegacyBook>();
        if (!root.TryGetProperty("flutter.library.v2", out var library)) return new LegacyLibrary(books, categories);
        using var data = JsonDocument.Parse(library.GetString() ?? throw new FormatException("Bibliothèque invalide."));
        var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var item in data.RootElement.EnumerateArray())
        {
            var id = item.GetProperty("id").GetString() ?? throw new FormatException("Identifiant invalide.");
            if (id.Length is < 1 or > 128 || id.Any(c => !char.IsAsciiLetterOrDigit(c) && c != '-') || !ids.Add(id))
                throw new FormatException("Identifiant de livre invalide ou en double.");
            var title = item.GetProperty("title").GetString() ?? throw new FormatException("Titre invalide.");
            var author = item.TryGetProperty("author", out var a) && a.ValueKind == JsonValueKind.String ? a.GetString()! : "";
            var cover = item.TryGetProperty("cover", out var cv) && cv.ValueKind == JsonValueKind.True;
            var cfi = item.TryGetProperty("cfi", out var c) && c.ValueKind == JsonValueKind.String ? c.GetString() : null;
            var progress = item.TryGetProperty("progress", out var p) && p.ValueKind == JsonValueKind.Number ? p.GetDouble() : 0;
            if (!double.IsFinite(progress) || progress < 0 || progress > 1) throw new FormatException("Progression invalide.");
            var bookCategories = new List<string>();
            if (item.TryGetProperty("categories", out var bc) && bc.ValueKind == JsonValueKind.Array)
                foreach (var v in bc.EnumerateArray()) if (v.ValueKind == JsonValueKind.String) bookCategories.Add(v.GetString()!);
            books.Add(new LegacyBook(id, title, author, cover, cfi, progress, bookCategories, File.Exists(Path.Combine(snapshotPath, "books", id + ".epub"))));
        }
        return new LegacyLibrary(books, categories);
    }
}
