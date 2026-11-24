using System.IO.Compression;
using System.Text.Json;
using System.Xml;
using System.Xml.Linq;

namespace Epinal.Core;

public sealed class NativeHighlight
{
    public string Cfi { get; set; } = "";
    public string Text { get; set; } = "";
    public string Note { get; set; } = "";
}

public sealed class NativeBook
{
    public string Id { get; set; } = "";
    public string Title { get; set; } = "";
    public string Author { get; set; } = "";
    public string? Cfi { get; set; }
    public double Progress { get; set; }
    public List<string> Categories { get; set; } = [];
    public List<string> Bookmarks { get; set; } = [];
    public List<NativeHighlight> Highlights { get; set; } = [];
}

/// Independent native library: never writes the legacy Flutter profile.
public sealed class NativeLibrary
{
    public string Root { get; }
    public string BooksPath => Path.Combine(Root, "books");
    private string IndexPath => Path.Combine(Root, "library.json");
    public List<NativeBook> Books { get; private set; } = [];
    public List<string> Categories { get; private set; } = [];
    private sealed class LibraryIndex { public List<NativeBook> Books { get; set; } = []; public List<string> Categories { get; set; } = []; }
    private readonly SemaphoreSlim saveLock = new(1, 1);
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    public NativeLibrary(string root) => Root = Path.GetFullPath(root);
    public string BookPath(NativeBook book)
    {
        ValidateId(book.Id);
        return Path.Combine(BooksPath, book.Id + ".epub");
    }
    public string CoverPath(NativeBook book) { ValidateId(book.Id); return Path.Combine(BooksPath, book.Id + ".jpg"); }
    private static void ValidateId(string id)
    {
        if (id.Length is < 1 or > 128 || id.Any(c => !char.IsAsciiLetterOrDigit(c) && c != '-'))
            throw new FormatException("Identifiant de livre invalide.");
    }
    public async Task LoadAsync()
    {
        Directory.CreateDirectory(BooksPath);
        if (!File.Exists(IndexPath)) { Books = []; return; }
        var json = await File.ReadAllTextAsync(IndexPath);
        using var document = JsonDocument.Parse(json);
        LibraryIndex index;
        if (document.RootElement.ValueKind == JsonValueKind.Array)
            index = new LibraryIndex { Books = JsonSerializer.Deserialize<List<NativeBook>>(json, JsonOptions) ?? throw new FormatException("Bibliothèque illisible.") };
        else
            index = JsonSerializer.Deserialize<LibraryIndex>(json, JsonOptions) ?? throw new FormatException("Bibliothèque illisible.");
        var books = index.Books ?? throw new FormatException("Bibliothèque illisible.");
        var categories = index.Categories ?? throw new FormatException("Catégories illisibles.");
        foreach (var category in books.SelectMany(b => b.Categories))
            if (!categories.Contains(category, StringComparer.OrdinalIgnoreCase)) categories.Add(category);
        if (categories.Any(c => string.IsNullOrWhiteSpace(c) || c.Length > 40) || categories.Distinct(StringComparer.OrdinalIgnoreCase).Count() != categories.Count)
            throw new FormatException("Catégories invalides.");
        var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var b in books)
        {
            ValidateId(b.Id);
            if (!ids.Add(b.Id)) throw new FormatException("Identifiants de livres en double.");
            if (!double.IsFinite(b.Progress) || b.Progress is < 0 or > 1) throw new FormatException("Progression invalide.");
        }
        Books = books; Categories = categories;
    }
    public async Task SaveAsync()
    {
        await saveLock.WaitAsync();
        try
        {
            Directory.CreateDirectory(Root);
            var stage = IndexPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                await File.WriteAllTextAsync(stage, JsonSerializer.Serialize(new LibraryIndex { Books = Books, Categories = Categories }, JsonOptions));
                File.Move(stage, IndexPath, true);
            }
            finally { if (File.Exists(stage)) File.Delete(stage); }
        }
        finally { saveLock.Release(); }
    }
    public async Task<NativeBook> ImportAsync(string source)
    {
        var file = new FileInfo(source);
        if (!file.Exists || file.Length <= 0 || file.Length > 100L * 1024 * 1024) throw new FormatException("Le fichier doit faire moins de 100 Mo.");
        Directory.CreateDirectory(BooksPath);
        var stage = Path.Combine(BooksPath, ".import-" + Guid.NewGuid().ToString("N") + ".tmp");
        try
        {
            // Validate and hash the staged copy, not the mutable original.
            await using (var input = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, true))
            await using (var output = new FileStream(stage, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true))
                await input.CopyToAsync(output);
            var (title, author) = InspectEpub(stage);
            var id = await PositionCode.FileHashAsync(stage);
            var existing = Books.FirstOrDefault(x => x.Id == id);
            if (existing is not null) return existing;
            var book = new NativeBook { Id = id, Title = title, Author = author };
            var path = BookPath(book);
            if (File.Exists(path) || File.Exists(path + ".previous") || File.Exists(path + ".previous.json") || File.Exists(CoverPath(book)))
                throw new IOException("Des fichiers internes existent déjà pour ce livre. Ils ont été conservés ; vérifiez la bibliothèque avant de réessayer.");
            File.Move(stage, path);
            Books.Insert(0, book);
            try
            {
                var cover = ExtractCover(path);
                if (cover is not null) await File.WriteAllBytesAsync(CoverPath(book), cover);
                await SaveAsync();
            }
            catch { Books.Remove(book); File.Delete(path); if (File.Exists(CoverPath(book))) File.Delete(CoverPath(book)); throw; }
            return book;
        }
        finally { if (File.Exists(stage)) File.Delete(stage); }
    }
    public static (string Title, string Author) InspectEpub(string path)
    {
        using var archive = ZipFile.OpenRead(path);
        if (archive.Entries.Count > 20000) throw new FormatException("EPUB trop complexe.");
        long expanded = 0;
        var names = new HashSet<string>(StringComparer.Ordinal);
        foreach (var entry in archive.Entries)
        {
            expanded = checked(expanded + entry.Length);
            if (expanded > 300L * 1024 * 1024 || entry.FullName.StartsWith('/') || entry.FullName.Contains('\\') || entry.FullName.Split('/').Contains("..") || !names.Add(entry.FullName))
                throw new FormatException("Structure EPUB non prise en charge.");
        }
        if (archive.GetEntry("META-INF/encryption.xml") is not null) throw new FormatException("EPUB chiffré non pris en charge.");
        var container = ReadXml(archive.GetEntry("META-INF/container.xml") ?? throw new FormatException("Conteneur EPUB manquant."));
        var opfPath = container.Descendants().FirstOrDefault(x => x.Name.LocalName == "rootfile")?.Attribute("full-path")?.Value;
        if (string.IsNullOrEmpty(opfPath)) throw new FormatException("Conteneur EPUB invalide.");
        var opf = ReadXml(archive.GetEntry(opfPath) ?? throw new FormatException("Métadonnées EPUB manquantes."));
        var metadata = opf.Descendants().FirstOrDefault(x => x.Name.LocalName == "metadata") ?? throw new FormatException("Métadonnées EPUB invalides.");
        var title = metadata.Elements().FirstOrDefault(x => x.Name.LocalName == "title")?.Value.Trim();
        var author = metadata.Elements().FirstOrDefault(x => x.Name.LocalName == "creator")?.Value.Trim();
        return (string.IsNullOrEmpty(title) ? "Livre sans titre" : title, author ?? "");
    }
    public static byte[]? ExtractCover(string path)
    {
        using var archive = ZipFile.OpenRead(path);
        var container = ReadXml(archive.GetEntry("META-INF/container.xml") ?? throw new FormatException("Conteneur EPUB manquant."));
        var opfPath = container.Descendants().FirstOrDefault(x => x.Name.LocalName == "rootfile")?.Attribute("full-path")?.Value ?? throw new FormatException("Conteneur invalide.");
        var opf = ReadXml(archive.GetEntry(opfPath) ?? throw new FormatException("Métadonnées EPUB manquantes."));
        var coverId = opf.Descendants().FirstOrDefault(x => x.Name.LocalName == "meta" && x.Attribute("name")?.Value == "cover")?.Attribute("content")?.Value;
        var item = opf.Descendants().Where(x => x.Name.LocalName == "item").FirstOrDefault(x => (x.Attribute("properties")?.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries).Contains("cover-image") ?? false) || (coverId is not null && x.Attribute("id")?.Value == coverId));
        if (item is null || item.Attribute("media-type")?.Value is not ("image/jpeg" or "image/png" or "image/gif")) return null;
        var href = item.Attribute("href")?.Value;
        if (string.IsNullOrEmpty(href) || href.Contains('\\') || href.StartsWith('/') || href.Contains('?') || href.Contains('#') || Uri.TryCreate(href, UriKind.Absolute, out _)) return null;
        try { href = Uri.UnescapeDataString(href); } catch (UriFormatException) { return null; }
        if (href.Contains('\\') || href.Split('/').Any(x => x is ".." or ".")) return null;
        var folder = opfPath.Contains('/') ? opfPath[..(opfPath.LastIndexOf('/') + 1)] : "";
        var entry = archive.GetEntry(folder + href);
        if (entry is null || entry.Length is <= 0 or > 10 * 1024 * 1024) return null;
        using var input = entry.Open(); using var output = new MemoryStream(); input.CopyTo(output);
        if (output.Length != entry.Length) throw new FormatException("Couverture invalide.");
        return output.ToArray();
    }
    public async Task SetCoverAsync(NativeBook book, byte[] bytes)
    {
        if (bytes.Length is <= 0 or > 10 * 1024 * 1024) throw new FormatException("Couverture trop volumineuse.");
        var path = CoverPath(book); var stage = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try { await File.WriteAllBytesAsync(stage, bytes); File.Move(stage, path, true); }
        finally { if (File.Exists(stage)) File.Delete(stage); }
    }
    public async Task<bool> RestoreCoverAsync(NativeBook book)
    {
        var cover = ExtractCover(BookPath(book));
        if (cover is null) { if (File.Exists(CoverPath(book))) File.Delete(CoverPath(book)); return false; }
        await SetCoverAsync(book, cover); return true;
    }
    private static XDocument ReadXml(ZipArchiveEntry entry)
    {
        if (entry.Length > 4 * 1024 * 1024) throw new FormatException("Métadonnées EPUB trop volumineuses.");
        using var stream = entry.Open();
        using var reader = XmlReader.Create(stream, new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 4 * 1024 * 1024 });
        return XDocument.Load(reader);
    }
}
