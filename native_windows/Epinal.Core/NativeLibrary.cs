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
    private readonly SemaphoreSlim saveLock = new(1, 1);
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    public NativeLibrary(string root) => Root = Path.GetFullPath(root);
    public string BookPath(NativeBook book)
    {
        ValidateId(book.Id);
        return Path.Combine(BooksPath, book.Id + ".epub");
    }
    private static void ValidateId(string id)
    {
        if (id.Length is < 1 or > 128 || id.Any(c => !char.IsAsciiLetterOrDigit(c) && c != '-'))
            throw new FormatException("Identifiant de livre invalide.");
    }
    public async Task LoadAsync()
    {
        Directory.CreateDirectory(BooksPath);
        if (!File.Exists(IndexPath)) { Books = []; return; }
        var books = JsonSerializer.Deserialize<List<NativeBook>>(await File.ReadAllTextAsync(IndexPath), JsonOptions) ?? throw new FormatException("Bibliothèque illisible.");
        var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var b in books)
        {
            ValidateId(b.Id);
            if (!ids.Add(b.Id)) throw new FormatException("Identifiants de livres en double.");
            if (!double.IsFinite(b.Progress) || b.Progress is < 0 or > 1) throw new FormatException("Progression invalide.");
        }
        Books = books;
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
                await File.WriteAllTextAsync(stage, JsonSerializer.Serialize(Books, JsonOptions));
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
            if (File.Exists(path)) throw new IOException("Un fichier portant cet identifiant existe déjà.");
            File.Move(stage, path);
            Books.Insert(0, book);
            try { await SaveAsync(); }
            catch { Books.Remove(book); File.Delete(path); throw; }
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
    private static XDocument ReadXml(ZipArchiveEntry entry)
    {
        if (entry.Length > 4 * 1024 * 1024) throw new FormatException("Métadonnées EPUB trop volumineuses.");
        using var stream = entry.Open();
        using var reader = XmlReader.Create(stream, new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 4 * 1024 * 1024 });
        return XDocument.Load(reader);
    }
}
