using Epinal.Core;
using System.Text;
using System.IO.Compression;
using System.Xml.Linq;

static void Check(bool value, string message) { if (!value) throw new Exception(message); }
static void Fails(Action action) { try { action(); } catch (FormatException) { return; } throw new Exception("FormatException expected"); }
static async Task FailsAsync(Func<Task> action) { try { await action(); } catch (Exception e) when (e is IOException or ArgumentException or InvalidOperationException) { return; } throw new Exception("Error expected"); }

static void ExtendEpub(string path, bool changeOld = false, bool duplicate = false)
{
    using var zip = ZipFile.Open(path, ZipArchiveMode.Update);
    var opf = zip.GetEntry("OEBPS/content.opf")!;
    XDocument document; using (var reader = new StreamReader(opf.Open())) document = XDocument.Parse(reader.ReadToEnd());
    var ns = document.Root!.Name.Namespace;
    document.Descendants(ns + "manifest").Single().Add(new XElement(ns + "item", new XAttribute("id", "extra"), new XAttribute("href", "extra.xhtml"), new XAttribute("media-type", "application/xhtml+xml")));
    document.Descendants(ns + "spine").Single().Add(new XElement(ns + "itemref", new XAttribute("idref", "extra")));
    opf.Delete(); using (var writer = new StreamWriter(zip.CreateEntry("OEBPS/content.opf").Open())) writer.Write(document.ToString());
    string extra = "<html xmlns='http://www.w3.org/1999/xhtml'><body>Suite</body></html>";
    if (duplicate) { using var reader = new StreamReader(zip.GetEntry("OEBPS/chapter.xhtml")!.Open()); extra = reader.ReadToEnd(); }
    using (var writer = new StreamWriter(zip.CreateEntry("OEBPS/extra.xhtml").Open())) writer.Write(extra);
    if (changeOld) { var old = zip.GetEntry("OEBPS/chapter.xhtml")!; old.Delete(); using var writer = new StreamWriter(zip.CreateEntry("OEBPS/chapter.xhtml").Open()); writer.Write("<html>modifié</html>"); }
}

const string fixture = "EPINAL1.eyJoIjoiYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYSIsImMiOiJlcHViY2ZpKC82LzQhLzQvMjoxMSkiLCJwIjowLjYzfQ.da8a79106293";
var pos = PositionCode.Decode(" \n" + fixture + "  ");
Check(pos.BookHash == new string('a', 64) && pos.Cfi == "epubcfi(/6/4!/4/2:11)" && pos.Progress == .63, "Flutter fixture decoding");
Check(PositionCode.Decode(pos.Encode()) == pos, "Round trip");
Fails(() => PositionCode.Decode(fixture[..^1] + "0"));
Fails(() => PositionCode.Decode(new string('x', 12001)));
Fails(() => new PositionCode(new string('a', 64), "invalid", .1).Encode());
Fails(() => new PositionCode(new string('a', 64), "epubcfi(/6/2)", double.NaN).Encode());

var releases = System.Text.Json.JsonSerializer.Serialize(new object[] {
    new { tag_name = "v1.0.99", draft = false, prerelease = false, assets = new object[] { } },
    new { tag_name = "windows-v1.0.99", draft = false, prerelease = true, assets = new object[] { } },
    new { tag_name = "windows-v1.0.30", draft = false, prerelease = false, assets = new[] { new { name = "Epinal-Setup-x64.exe" } } },
    new { tag_name = "windows-v1.0.31", draft = false, prerelease = false, assets = new[] { new { name = "Epinal-Native-Setup-x64.exe", digest = "sha256:" + new string('a', 64), browser_download_url = "https://github.com/elfred434/Epinal-reader-/releases/download/windows-v1.0.31/Epinal-Native-Setup-x64.exe" } } },
});
using (var json = System.Text.Json.JsonDocument.Parse(releases))
{
    var update = NativeRelease.Select(json.RootElement, new Version(1, 0, 27));
    Check(update is not null && update.Version == new Version(1, 0, 31), "Only stable native Windows release selected");
    Check(NativeRelease.Select(json.RootElement, new Version(1, 0, 31)) is null, "No downgrade");
}

var temp = Path.Combine(Path.GetTempPath(), "epinal-core-test-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(temp);
try
{
    var source = Path.Combine(temp, "flutter");
    var dest = Path.Combine(temp, "snapshot");
    Directory.CreateDirectory(Path.Combine(source, "books"));
    var legacyBooks = "[{\"id\":\"a\",\"title\":\"Roman\",\"author\":\"Auteur\",\"cfi\":\"epubcfi(/6/2)\",\"progress\":0.4,\"categories\":[\"Romans\"]}]";
    var preferences = System.Text.Json.JsonSerializer.Serialize(new Dictionary<string, object> { ["flutter.library.v2"] = legacyBooks, ["flutter.categories.v1"] = new[] { "Romans" }, ["flutter.marks.a"] = "[]" });
    await File.WriteAllTextAsync(Path.Combine(source, "shared_preferences.json"), preferences);
    await File.WriteAllTextAsync(Path.Combine(source, "books", "a.epub"), "original", Encoding.UTF8);
    await LegacySnapshot.CreateAsync(source, dest);
    Check(await File.ReadAllTextAsync(Path.Combine(dest, "books", "a.epub")) == "original", "Book preserved");
    var loaded = LegacyLibrary.Load(dest);
    Check(loaded.Books.Count == 1 && loaded.Books[0].Cfi == "epubcfi(/6/2)" && loaded.Books[0].EpubExists && loaded.Categories[0] == "Romans", "Legacy profile read");
    Check((await File.ReadAllTextAsync(Path.Combine(dest, "shared_preferences.json"))).Contains("flutter.marks.a"), "Annotations copied without alteration");
    await File.WriteAllTextAsync(Path.Combine(dest, "books", "a.epub"), "new");
    Check(await File.ReadAllTextAsync(Path.Combine(source, "books", "a.epub")) == "original", "Source unchanged");
    await FailsAsync(() => LegacySnapshot.CreateAsync(source, dest));
    await FailsAsync(() => LegacySnapshot.CreateAsync(source, Path.Combine(source, "nested")));
    var local = new NativeLibrary(Path.Combine(temp, "native"));
    await local.LoadAsync();
    var selected = Path.Combine(temp, "selected.epub");
    File.Copy(Path.Combine("native_windows", "Epinal.Core.Tests", "Fixtures", "with_cover.epub"), selected);
    var original = await File.ReadAllBytesAsync(selected);
    var added = await local.ImportAsync(selected);
    Check(await File.ReadAllBytesAsync(local.BookPath(added)) is var internalBytes && internalBytes.SequenceEqual(original), "Imported book is an independent copy");
    Check(File.Exists(local.CoverPath(added)), "Original EPUB cover extracted");
    var originalCover = await File.ReadAllBytesAsync(local.CoverPath(added));
    await local.SetCoverAsync(added, new byte[] { 1, 2, 3 });
    Check(await local.RestoreCoverAsync(added) && (await File.ReadAllBytesAsync(local.CoverPath(added))).SequenceEqual(originalCover), "Original cover restored");
    local.Categories.Add("Vide");
    await local.SaveAsync();
    Check((await local.ImportAsync(selected)).Id == added.Id && local.Books.Count == 1, "Duplicate import");
    File.Delete(selected);
    Check(File.Exists(local.BookPath(added)), "Source may be removed after import");
    added.Cfi = "epubcfi(/6/2)"; added.Progress = .2; added.Highlights.Add(new NativeHighlight { Cfi = "epubcfi(/6/2)", Text = "passage", Note = "note" });
    await local.SaveAsync();
    var reloaded = new NativeLibrary(local.Root); await reloaded.LoadAsync();
    Check(reloaded.Categories.Contains("Vide"), "Empty category survives reload");
    Check(reloaded.Books.Count == 1 && reloaded.Books[0].Cfi == added.Cfi && reloaded.Books[0].Highlights[0].Note == "note", "Library reload retains position and notes");
    var invalid = Path.Combine(temp, "invalid.epub"); await File.WriteAllTextAsync(invalid, "invalid");
    try { await local.ImportAsync(invalid); throw new Exception("Invalid EPUB accepted"); } catch (InvalidDataException) { }
    Check(local.Books.Count == 1, "Invalid import does not alter library");
    var incoming = Path.Combine(temp, "suite.epub"); File.WriteAllBytes(incoming, original); ExtendEpub(incoming);
    var badIncoming = Path.Combine(temp, "suite-modifiee.epub"); File.WriteAllBytes(badIncoming, original); ExtendEpub(badIncoming, true);
    var changed = AppendEdition.Compare(local.BookPath(added), badIncoming);
    Check(changed.Conflicts.Count == 1 && changed.Conflicts[0].IsChapter && changed.AddedSections == 1, "Changed chapter offered for review");
    try { await AppendEdition.ApplyAsync(local, added, badIncoming, changed); throw new Exception("Missing choice accepted"); } catch (FormatException) { }
    Check((await File.ReadAllBytesAsync(local.BookPath(added))).SequenceEqual(original), "Missing choice leaves book untouched");
    await AppendEdition.ApplyAsync(local, added, badIncoming, changed, new Dictionary<string, bool> { [changed.Conflicts[0].Path] = true });
    using (var result = ZipFile.OpenRead(local.BookPath(added)))
    using (var originalZip = ZipFile.OpenRead(badIncoming))
    {
        Check(result.GetEntry("OEBPS/extra.xhtml") is not null, "New chapter retained with old chapter choice");
        using var chosen = new StreamReader(result.GetEntry(changed.Conflicts[0].Path)!.Open());
        Check(!(await chosen.ReadToEndAsync()).Contains("modifié"), "Old chapter retained");
    }
    await AppendEdition.RestoreAsync(local, added);
    changed = AppendEdition.Compare(local.BookPath(added), badIncoming);
    await AppendEdition.ApplyAsync(local, added, badIncoming, changed, new Dictionary<string, bool> { [changed.Conflicts[0].Path] = false });
    using (var result = ZipFile.OpenRead(local.BookPath(added)))
    using (var chosen = new StreamReader(result.GetEntry(changed.Conflicts[0].Path)!.Open()))
        Check((await chosen.ReadToEndAsync()).Contains("modifié"), "New chapter accepted");
    await AppendEdition.RestoreAsync(local, added);
    var resourceIncoming = Path.Combine(temp, "suite-ressource.epub"); File.WriteAllBytes(resourceIncoming, original); ExtendEpub(resourceIncoming, true);
    using (var zip = ZipFile.Open(resourceIncoming, ZipArchiveMode.Update)) { zip.GetEntry("OEBPS/cover.png")!.Delete(); using var writer = zip.CreateEntry("OEBPS/cover.png").Open(); writer.Write(new byte[] { 1, 2, 3 }); }
    var mixed = AppendEdition.Compare(local.BookPath(added), resourceIncoming);
    Check(mixed.Conflicts.Count == 2 && mixed.Conflicts.Any(x => !x.IsChapter), "All changed resources require independent choices");
    var decisions = mixed.Conflicts.ToDictionary(x => x.Path, x => x.IsChapter);
    await AppendEdition.ApplyAsync(local, added, resourceIncoming, mixed, decisions);
    using (var zip = ZipFile.OpenRead(local.BookPath(added)))
    {
        using var cover = zip.GetEntry("OEBPS/cover.png")!.Open(); using var memory = new MemoryStream(); cover.CopyTo(memory);
        Check(memory.ToArray().SequenceEqual(new byte[] { 1, 2, 3 }), "Resource choice applied independently");
    }
    await AppendEdition.RestoreAsync(local, added);
    var duplicateIncoming = Path.Combine(temp, "suite-dupliquee.epub"); File.WriteAllBytes(duplicateIncoming, original); ExtendEpub(duplicateIncoming, duplicate: true);
    Fails(() => AppendEdition.Compare(local.BookPath(added), duplicateIncoming));
    var stale = AppendEdition.Compare(local.BookPath(added), badIncoming);
    await File.AppendAllTextAsync(badIncoming, "changed");
    try { await AppendEdition.ApplyAsync(local, added, badIncoming, stale, new Dictionary<string, bool> { [stale.Conflicts[0].Path] = false }); throw new Exception("Changed source accepted"); } catch (IOException) { }
    Check((await File.ReadAllBytesAsync(local.BookPath(added))).SequenceEqual(original), "Stale comparison leaves book intact");
    var comparison = AppendEdition.Compare(local.BookPath(added), incoming);
    Check(comparison.AddedSections == 1, "One section added");
    var incomingBytes = await File.ReadAllBytesAsync(incoming);
    await AppendEdition.ApplyAsync(local, added, incoming, comparison);
    Check((await File.ReadAllBytesAsync(local.BookPath(added))).SequenceEqual(incomingBytes), "Internal book updated");
    Check((await File.ReadAllBytesAsync(incoming)).SequenceEqual(incomingBytes), "Incoming file untouched");
    added.Cfi = "epubcfi(/6/4)"; added.Progress = .9;
    await AppendEdition.RestoreAsync(local, added);
    Check((await File.ReadAllBytesAsync(local.BookPath(added))).SequenceEqual(original) && added.Cfi == "epubcfi(/6/2)" && added.Progress == .2, "Previous edition and position restored");

    var oldProfile = Path.Combine(temp, "legacy-real"); Directory.CreateDirectory(Path.Combine(oldProfile, "books"));
    await File.WriteAllBytesAsync(Path.Combine(oldProfile, "books", "a.epub"), original);
    await File.WriteAllBytesAsync(Path.Combine(oldProfile, "books", "a.previous.epub"), original);
    var backupHash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(original)).ToLowerInvariant();
    var backupState = System.Text.Json.JsonSerializer.Serialize(new { sha256 = backupHash, cfi = "epubcfi(/6/2)", progress = 0.35 });
    var prefsReal = System.Text.Json.JsonSerializer.Serialize(new Dictionary<string, object> { ["flutter.library.v2"] = legacyBooks, ["flutter.categories.v1"] = new[] { "Romans" }, ["flutter.reader.font"] = 24, ["flutter.reader.theme"] = 3, ["flutter.reader.mode"] = "longStrip", ["flutter.edition.backup.a"] = backupState, ["flutter.marks.a"] = "[{\"cfi\":\"epubcfi(/6/2)\"}]", ["flutter.highlights.a"] = "[{\"cfi\":\"epubcfi(/6/2)\",\"text\":\"Passage\",\"note\":\"Note\"}]" });
    await File.WriteAllTextAsync(Path.Combine(oldProfile, "shared_preferences.json"), prefsReal);
    var migrated = new NativeLibrary(Path.Combine(temp, "native-migrated")); await migrated.LoadAsync();
    var backup = await LegacyMigration.ImportAsync(migrated, oldProfile);
    var readerPrefs = await ReaderPreferences.LoadAsync(migrated.Root);
    Check(readerPrefs.FontPercent == 133 && readerPrefs.Theme == 3 && readerPrefs.Scrolling, "Migration transfers supported reading settings");
    readerPrefs.RecentBookId = "a"; await readerPrefs.SaveAsync(migrated.Root);
    Check((await ReaderPreferences.LoadAsync(migrated.Root)).RecentBookId == "a", "Recent book persisted");
    Check(migrated.Categories.Contains("Romans"), "Migration retains categories");
    Check(migrated.Books.Count == 1 && migrated.Books[0].Bookmarks.Count == 1 && migrated.Books[0].Highlights[0].Note == "Note", "Migration transfers marks and notes");
    Check((await File.ReadAllBytesAsync(migrated.BookPath(migrated.Books[0]))).SequenceEqual(original), "Migration copies EPUB");
    Check(File.Exists(migrated.BookPath(migrated.Books[0]) + ".previous"), "Migration transfers previous edition");
    await AppendEdition.RestoreAsync(migrated, migrated.Books[0]);
    Check(migrated.Books[0].Cfi == "epubcfi(/6/2)" && migrated.Books[0].Progress == .35, "Migrated backup restores the verified position");
    Check(File.Exists(Path.Combine(backup, "shared_preferences.json")) && (await File.ReadAllTextAsync(Path.Combine(oldProfile, "shared_preferences.json"))) == prefsReal, "Migration retains backup and source");
    await FailsAsync(() => LegacyMigration.ImportAsync(migrated, oldProfile));
    await FailsAsync(() => UpdateDownload.DownloadAsync(new Uri("http://github.com/test"), new string('a', 64), Path.Combine(temp, "setup.exe")));
    await FailsAsync(() => UpdateDownload.DownloadAsync(new Uri("https://evil.example/test"), new string('a', 64), Path.Combine(temp, "setup.exe")));
    Check(!File.Exists(Path.Combine(temp, "setup.exe")), "Rejected update must not create file");
}
finally { Directory.Delete(temp, true); }
Console.WriteLine("All core checks passed.");
Console.WriteLine("Native EPINAL1 example: " + pos.Encode());
