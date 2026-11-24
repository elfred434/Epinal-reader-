using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;
using System.Xml;
using System.Xml.Linq;

namespace Epinal.Core;

/// Conservative comparison: an edition must retain the old spine and resources.
/// Every changed chapter or resource requires an explicit choice.
public static class AppendEdition
{
    public sealed record Conflict(string Path, string Title, bool IsChapter, string OldExcerpt, string NewExcerpt);
    public sealed record Preview(string OldHash, string IncomingHash, int AddedSections, IReadOnlyList<Conflict> Conflicts);
    private sealed record Package(string PackagePath, Dictionary<string, (string Href, string Media)> Items, List<string> Spine, HashSet<string> Navigation);
    private sealed record RestoreState(string Hash, string? Cfi, double Progress);
    private const long Limit = 50L * 1024 * 1024;
    private static string Hash(string path) { using var stream = File.OpenRead(path); return Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant(); }
    private static XDocument Xml(ZipArchiveEntry entry)
    {
        if (entry.Length > 4 * 1024 * 1024) throw new FormatException("Métadonnées trop volumineuses.");
        using var input = entry.Open();
        using var reader = XmlReader.Create(input, new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 4 * 1024 * 1024 });
        return XDocument.Load(reader);
    }
    private static Package ReadPackage(ZipArchive zip)
    {
        var container = Xml(zip.GetEntry("META-INF/container.xml") ?? throw new FormatException("Conteneur EPUB manquant."));
        var rootfiles = container.Descendants().Where(x => x.Name.LocalName == "rootfile").ToList();
        if (rootfiles.Count != 1) throw new FormatException("EPUB à plusieurs rendus non pris en charge.");
        var path = rootfiles[0].Attribute("full-path")?.Value ?? throw new FormatException("Conteneur invalide.");
        var doc = Xml(zip.GetEntry(path) ?? throw new FormatException("Paquet EPUB manquant."));
        var manifest = doc.Descendants().FirstOrDefault(x => x.Name.LocalName == "manifest") ?? throw new FormatException("Manifeste manquant.");
        var spine = doc.Descendants().FirstOrDefault(x => x.Name.LocalName == "spine") ?? throw new FormatException("Sommaire de lecture manquant.");
        var items = new Dictionary<string, (string Href, string Media)>(StringComparer.Ordinal);
        var navigation = new HashSet<string>(StringComparer.Ordinal);
        string folder = path.Contains('/') ? path[..(path.LastIndexOf('/') + 1)] : "";
        var itemPaths = new HashSet<string>(StringComparer.Ordinal);
        foreach (var item in manifest.Elements().Where(x => x.Name.LocalName == "item"))
        {
            var id = item.Attribute("id")?.Value ?? throw new FormatException("Ressource sans identifiant.");
            var href = item.Attribute("href")?.Value ?? throw new FormatException("Ressource sans chemin.");
            var media = item.Attribute("media-type")?.Value ?? "";
            // Refuse ambiguous paths and URLs instead of guessing their meaning.
            if (href.Contains('%') || href.Contains('?') || href.Contains('#') || href.StartsWith('/') || href.Contains('\\') || href.Split('/').Any(p => p is ".." or ".") || Uri.TryCreate(href, UriKind.Absolute, out _))
                throw new FormatException("Chemin de ressource complexe : comparaison refusée.");
            if (!items.TryAdd(id, (folder + href, media)) || !itemPaths.Add(folder + href) || zip.GetEntry(folder + href) is null)
                throw new FormatException("Ressource en double ou manquante.");
            if ((item.Attribute("properties")?.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries).Contains("nav") ?? false) || id == spine.Attribute("toc")?.Value)
                navigation.Add(folder + href);
        }
        var order = new List<string>();
        foreach (var item in spine.Elements().Where(x => x.Name.LocalName == "itemref"))
        {
            var id = item.Attribute("idref")?.Value ?? throw new FormatException("Section sans identifiant.");
            if (!items.ContainsKey(id) || order.Contains(id) || item.Attribute("linear")?.Value == "no") throw new FormatException("Ordre de lecture non pris en charge.");
            order.Add(id);
        }
        if (order.Count == 0) throw new FormatException("Aucune section de lecture.");
        return new Package(path, items, order, navigation);
    }
    private static byte[] Bytes(ZipArchiveEntry entry)
    {
        if (entry.Length > 20L * 1024 * 1024) throw new FormatException("Ressource trop volumineuse.");
        using var input = entry.Open(); using var output = new MemoryStream();
        input.CopyTo(output);
        if (output.Length != entry.Length) throw new FormatException("Ressource EPUB invalide.");
        return output.ToArray();
    }
    private static string? Text(ZipArchiveEntry entry)
    {
        try
        {
            using var input = entry.Open();
            using var reader = XmlReader.Create(input, new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 4 * 1024 * 1024 });
            var doc = XDocument.Load(reader);
            var body = doc.Descendants().FirstOrDefault(x => x.Name.LocalName == "body") ?? doc.Root;
            return System.Text.RegularExpressions.Regex.Replace(body?.Value ?? "", @"\s+", " ").Trim();
        }
        catch (Exception ex) when (ex is XmlException or InvalidOperationException) { return null; }
    }
    private static (string, string) Excerpts(ZipArchiveEntry before, ZipArchiveEntry after)
    {
        var a = Text(before); var b = Text(after);
        if (a is null || b is null) return ("Aperçu du texte indisponible.", "Aperçu du texte indisponible.");
        var diff = 0; while (diff < Math.Min(a.Length, b.Length) && a[diff] == b[diff]) diff++;
        if (a == b) diff = 0;
        string Excerpt(string text) { var start = Math.Clamp(diff - 180, 0, text.Length); var len = Math.Min(900, text.Length - start); return (start > 0 ? "…" : "") + text.Substring(start, len) + (start + len < text.Length ? "…" : ""); }
        return (Excerpt(a), Excerpt(b));
    }
    public static Preview Compare(string oldPath, string incomingPath)
    {
        foreach (var path in new[] { oldPath, incomingPath })
        {
            var len = new FileInfo(path).Length;
            if (len <= 0 || len > Limit) throw new FormatException("La comparaison accepte des fichiers de 50 Mo maximum.");
            NativeLibrary.InspectEpub(path);
        }
        var oldHash = Hash(oldPath); var newHash = Hash(incomingPath);
        using var oldZip = ZipFile.OpenRead(oldPath); using var newZip = ZipFile.OpenRead(incomingPath);
        foreach (var zip in new[] { oldZip, newZip })
        {
            if (zip.Entries.Count > 5000 || zip.Entries.Sum(e => e.Length) > 80L * 1024 * 1024 || zip.Entries.Any(e => e.Length > 20L * 1024 * 1024))
                throw new FormatException("EPUB décompressé trop volumineux ou complexe.");
            var mime = zip.GetEntry("mimetype") ?? throw new FormatException("Type EPUB manquant.");
            if (System.Text.Encoding.UTF8.GetString(Bytes(mime)).Trim() != "application/epub+zip") throw new FormatException("Type EPUB invalide.");
        }
        var old = ReadPackage(oldZip); var incoming = ReadPackage(newZip);
        if (old.PackagePath != incoming.PackagePath || old.Spine.Count > incoming.Spine.Count || !old.Spine.SequenceEqual(incoming.Spine.Take(old.Spine.Count)))
            throw new FormatException("La suite doit conserver l’ordre des anciennes sections.");
        foreach (var (id, item) in old.Items)
            if (!incoming.Items.TryGetValue(id, out var next) || item != next) throw new FormatException("Une ressource a été déplacée ou supprimée.");
        var chapterPaths = old.Spine.Select(id => old.Items[id].Href).ToHashSet(StringComparer.Ordinal);
        var conflicts = new List<Conflict>();
        foreach (var entry in oldZip.Entries)
        {
            var name = entry.FullName;
            if (name.EndsWith('/') || name == "mimetype" || name.StartsWith("META-INF/") || name == old.PackagePath || old.Navigation.Contains(name)) continue;
            var replacement = newZip.GetEntry(name) ?? throw new FormatException("Une ancienne ressource est absente de la nouvelle édition.");
            if (SHA256.HashData(Bytes(entry)).AsSpan().SequenceEqual(SHA256.HashData(Bytes(replacement)))) continue;
            var chapter = chapterPaths.Contains(name);
            var (before, after) = chapter ? Excerpts(entry, replacement) : ("", "");
            conflicts.Add(new Conflict(name, Path.GetFileName(name), chapter, before, after));
        }
        var hashes = new HashSet<string>(StringComparer.Ordinal);
        var texts = new HashSet<string>(StringComparer.Ordinal);
        void Remember(ZipArchive zip, string name, bool newSection)
        {
            var entry = zip.GetEntry(name) ?? throw new FormatException("Section de lecture manquante.");
            var hash = Convert.ToHexString(SHA256.HashData(Bytes(entry)));
            var text = Text(entry);
            var textHash = text is { Length: >= 80 } ? Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(text))) : null;
            if (newSection && (hashes.Contains(hash) || (textHash is not null && texts.Contains(textHash)))) throw new FormatException("Une nouvelle section semble être un doublon.");
            hashes.Add(hash); if (textHash is not null) texts.Add(textHash);
        }
        foreach (var id in old.Spine) { Remember(oldZip, old.Items[id].Href, false); Remember(newZip, incoming.Items[id].Href, false); }
        foreach (var id in incoming.Spine.Skip(old.Spine.Count)) Remember(newZip, incoming.Items[id].Href, true);
        if (Hash(oldPath) != oldHash || Hash(incomingPath) != newHash) throw new IOException("Un fichier a changé pendant la comparaison.");
        return new Preview(oldHash, newHash, incoming.Spine.Count - old.Spine.Count, conflicts.AsReadOnly());
    }
    public static async Task ApplyAsync(NativeLibrary library, NativeBook book, string source, Preview preview, IReadOnlyDictionary<string, bool>? keepOld = null)
    {
        var current = library.BookPath(book);
        var stage = current + "." + Guid.NewGuid().ToString("N") + ".new";
        var previous = current + ".previous";
        var backupStage = previous + "." + Guid.NewGuid().ToString("N") + ".tmp";
        var sourceStage = current + "." + Guid.NewGuid().ToString("N") + ".incoming";
        var statePath = previous + ".json";
        var stateStage = statePath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            // Work only with verified copies; re-compute conflicts instead of trusting the UI.
            File.Copy(source, sourceStage); File.Copy(current, backupStage);
            if (Hash(sourceStage) != preview.IncomingHash || Hash(backupStage) != preview.OldHash || Hash(current) != preview.OldHash)
                throw new IOException("Un fichier a changé depuis la comparaison. Recommencez.");
            var verified = Compare(backupStage, sourceStage);
            keepOld ??= new Dictionary<string, bool>();
            var paths = verified.Conflicts.Select(x => x.Path).ToHashSet(StringComparer.Ordinal);
            if (keepOld.Count != paths.Count || keepOld.Keys.Any(x => !paths.Contains(x))) throw new FormatException("Choisissez une version pour chaque modification.");
            if (verified.AddedSections == 0 && paths.Count == 0) throw new FormatException("Aucune nouveauté détectée.");
            if (!keepOld.Values.Any(x => x)) File.Copy(sourceStage, stage);
            else
            {
                using var oldZip = ZipFile.OpenRead(backupStage); using var newZip = ZipFile.OpenRead(sourceStage);
                using var output = ZipFile.Open(stage, ZipArchiveMode.Create);
                void WriteEntry(ZipArchiveEntry entry, bool uncompressed)
                {
                    var sourceEntry = keepOld.TryGetValue(entry.FullName, out var old) && old ? oldZip.GetEntry(entry.FullName) ?? throw new FormatException("Ressource ancienne manquante.") : entry;
                    var created = output.CreateEntry(entry.FullName, uncompressed ? CompressionLevel.NoCompression : CompressionLevel.Optimal);
                    using var read = sourceEntry.Open(); using var write = created.Open(); read.CopyTo(write);
                }
                WriteEntry(newZip.GetEntry("mimetype")!, true);
                foreach (var entry in newZip.Entries) if (entry.FullName != "mimetype" && !entry.FullName.EndsWith('/')) WriteEntry(entry, false);
            }
            if (new FileInfo(stage).Length > Limit) throw new FormatException("Le livre obtenu est trop volumineux.");
            NativeLibrary.InspectEpub(stage);
            if (Hash(current) != preview.OldHash) throw new IOException("Le livre interne a changé pendant la préparation.");
            await File.WriteAllTextAsync(stateStage, JsonSerializer.Serialize(new RestoreState(preview.OldHash, book.Cfi, book.Progress)));
            File.Move(backupStage, previous, true);
            File.Move(stateStage, statePath, true);
            File.Move(stage, current, true);
        }
        finally { foreach (var path in new[] { stage, backupStage, stateStage, sourceStage }) if (File.Exists(path)) File.Delete(path); }
    }
    public static async Task RestoreAsync(NativeLibrary library, NativeBook book)
    {
        var current = library.BookPath(book); var previous = current + ".previous"; var statePath = previous + ".json";
        if (!File.Exists(previous) || !File.Exists(statePath)) throw new FormatException("Aucune version précédente disponible.");
        var state = JsonSerializer.Deserialize<RestoreState>(await File.ReadAllTextAsync(statePath)) ?? throw new FormatException("Sauvegarde illisible.");
        if (Hash(previous) != state.Hash) throw new FormatException("Sauvegarde endommagée : restauration annulée.");
        var stage = current + "." + Guid.NewGuid().ToString("N") + ".restore";
        try
        {
            File.Copy(previous, stage); File.Move(stage, current, true);
            book.Cfi = state.Cfi; book.Progress = state.Progress; await library.SaveAsync();
            File.Delete(previous); File.Delete(statePath);
        }
        finally { if (File.Exists(stage)) File.Delete(stage); }
    }
}
