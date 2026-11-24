using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;
using System.Xml;
using System.Xml.Linq;

namespace Epinal.Core;

/// Conservative first implementation: accepts only exact existing resources
/// and a strictly extended spine. Does not merge changed chapters.
public static class AppendEdition
{
    public sealed record Preview(string OldHash, string IncomingHash, int AddedSections);
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
        var path = container.Descendants().FirstOrDefault(x => x.Name.LocalName == "rootfile")?.Attribute("full-path")?.Value ?? throw new FormatException("Conteneur invalide.");
        var doc = Xml(zip.GetEntry(path) ?? throw new FormatException("Paquet EPUB manquant."));
        var manifest = doc.Descendants().FirstOrDefault(x => x.Name.LocalName == "manifest") ?? throw new FormatException("Manifeste manquant.");
        var spine = doc.Descendants().FirstOrDefault(x => x.Name.LocalName == "spine") ?? throw new FormatException("Sommaire de lecture manquant.");
        var items = new Dictionary<string, (string Href, string Media)>(StringComparer.Ordinal);
        var navigation = new HashSet<string>(StringComparer.Ordinal);
        string folder = path.Contains('/') ? path[..(path.LastIndexOf('/') + 1)] : "";
        foreach (var item in manifest.Elements().Where(x => x.Name.LocalName == "item"))
        {
            var id = item.Attribute("id")?.Value ?? throw new FormatException("Ressource sans identifiant.");
            var href = item.Attribute("href")?.Value ?? throw new FormatException("Ressource sans chemin.");
            var media = item.Attribute("media-type")?.Value ?? "";
            // Refuse ambiguous paths and URLs instead of guessing their meaning.
            if (href.Contains('%') || href.Contains('?') || href.Contains('#') || href.StartsWith('/') || href.Contains('\\') || href.Split('/').Any(p => p is ".." or ".") || Uri.TryCreate(href, UriKind.Absolute, out _))
                throw new FormatException("Chemin de ressource complexe : comparaison refusée.");
            if (!items.TryAdd(id, (folder + href, media))) throw new FormatException("Ressource en double.");
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
        var old = ReadPackage(oldZip); var incoming = ReadPackage(newZip);
        if (old.PackagePath != incoming.PackagePath || old.Spine.Count >= incoming.Spine.Count || !old.Spine.SequenceEqual(incoming.Spine.Take(old.Spine.Count)))
            throw new FormatException("La suite doit prolonger les anciennes sections sans les réorganiser.");
        foreach (var (id, item) in old.Items)
            if (!incoming.Items.TryGetValue(id, out var next) || item != next) throw new FormatException("Une ressource a été déplacée ou supprimée.");
        var sectionHashes = new HashSet<string>(StringComparer.Ordinal);
        foreach (var id in incoming.Spine)
        {
            var section = newZip.GetEntry(incoming.Items[id].Href) ?? throw new FormatException("Une section de lecture est manquante.");
            using var sectionStream = section.Open();
            var sectionHash = Convert.ToHexString(SHA256.HashData(sectionStream));
            if (!sectionHashes.Add(sectionHash)) throw new FormatException("Des sections identiques ont été détectées : comparaison refusée.");
        }
        foreach (var entry in oldZip.Entries)
        {
            if (entry.FullName.EndsWith('/')) continue;
            var replacement = newZip.GetEntry(entry.FullName) ?? throw new FormatException("Une ancienne ressource est absente de la nouvelle édition.");
            if (entry.FullName == old.PackagePath || old.Navigation.Contains(entry.FullName)) continue;
            using var a = entry.Open(); using var b = replacement.Open();
            if (!CryptographicOperations.FixedTimeEquals(SHA256.HashData(a), SHA256.HashData(b)))
                throw new FormatException("Un ancien chapitre ou une ressource a changé. Cette version native ne sait pas encore choisir les corrections : utilisez la version stable.");
        }
        if (Hash(oldPath) != oldHash || Hash(incomingPath) != newHash) throw new IOException("Un fichier a changé pendant la comparaison.");
        return new Preview(oldHash, newHash, incoming.Spine.Count - old.Spine.Count);
    }
    public static async Task ApplyAsync(NativeLibrary library, NativeBook book, string source, Preview preview)
    {
        var current = library.BookPath(book);
        var stage = current + "." + Guid.NewGuid().ToString("N") + ".new";
        var previous = current + ".previous";
        var backupStage = previous + "." + Guid.NewGuid().ToString("N") + ".tmp";
        var statePath = previous + ".json";
        var stateStage = statePath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.Copy(source, stage); File.Copy(current, backupStage);
            if (Hash(stage) != preview.IncomingHash || Hash(backupStage) != preview.OldHash || Hash(current) != preview.OldHash)
                throw new IOException("Un fichier a changé depuis la comparaison. Recommencez.");
            await File.WriteAllTextAsync(stateStage, JsonSerializer.Serialize(new RestoreState(preview.OldHash, book.Cfi, book.Progress)));
            File.Move(backupStage, previous, true);
            File.Move(stateStage, statePath, true);
            File.Move(stage, current, true);
        }
        finally { foreach (var path in new[] { stage, backupStage, stateStage }) if (File.Exists(path)) File.Delete(path); }
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
