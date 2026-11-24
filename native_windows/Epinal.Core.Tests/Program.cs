using Epinal.Core;
using System.Text;
using System.IO.Compression;
using System.Xml.Linq;

static void Check(bool value, string message) { if (!value) throw new Exception(message); }
static void Fails(Action action) { try { action(); } catch (FormatException) { return; } throw new Exception("FormatException expected"); }
static async Task FailsAsync(Func<Task> action) { try { await action(); } catch (Exception e) when (e is IOException or ArgumentException or InvalidOperationException) { return; } throw new Exception("Error expected"); }

static void ExtendEpub(string path, bool changeOld = false)
{
    using var zip = ZipFile.Open(path, ZipArchiveMode.Update);
    var opf = zip.GetEntry("OEBPS/content.opf")!;
    XDocument document; using (var reader = new StreamReader(opf.Open())) document = XDocument.Parse(reader.ReadToEnd());
    var ns = document.Root!.Name.Namespace;
    document.Descendants(ns + "manifest").Single().Add(new XElement(ns + "item", new XAttribute("id", "extra"), new XAttribute("href", "extra.xhtml"), new XAttribute("media-type", "application/xhtml+xml")));
    document.Descendants(ns + "spine").Single().Add(new XElement(ns + "itemref", new XAttribute("idref", "extra")));
    opf.Delete(); using (var writer = new StreamWriter(zip.CreateEntry("OEBPS/content.opf").Open())) writer.Write(document.ToString());
    using (var writer = new StreamWriter(zip.CreateEntry("OEBPS/extra.xhtml").Open())) writer.Write("<html xmlns='http://www.w3.org/1999/xhtml'><body>Suite</body></html>");
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
    File.Copy(Path.Combine("test", "fixtures", "with_cover.epub"), selected);
    var original = await File.ReadAllBytesAsync(selected);
    var added = await local.ImportAsync(selected);
    Check(await File.ReadAllBytesAsync(local.BookPath(added)) is var internalBytes && internalBytes.SequenceEqual(original), "Imported book is an independent copy");
    Check((await local.ImportAsync(selected)).Id == added.Id && local.Books.Count == 1, "Duplicate import");
    File.Delete(selected);
    Check(File.Exists(local.BookPath(added)), "Source may be removed after import");
    added.Cfi = "epubcfi(/6/2)"; added.Progress = .2; added.Highlights.Add(new NativeHighlight { Cfi = "epubcfi(/6/2)", Text = "passage", Note = "note" });
    await local.SaveAsync();
    var reloaded = new NativeLibrary(local.Root); await reloaded.LoadAsync();
    Check(reloaded.Books.Count == 1 && reloaded.Books[0].Cfi == added.Cfi && reloaded.Books[0].Highlights[0].Note == "note", "Library reload retains position and notes");
    var invalid = Path.Combine(temp, "invalid.epub"); await File.WriteAllTextAsync(invalid, "invalid");
    try { await local.ImportAsync(invalid); throw new Exception("Invalid EPUB accepted"); } catch (InvalidDataException) { }
    Check(local.Books.Count == 1, "Invalid import does not alter library");
    var incoming = Path.Combine(temp, "suite.epub"); File.WriteAllBytes(incoming, original); ExtendEpub(incoming);
    var badIncoming = Path.Combine(temp, "suite-modifiee.epub"); File.WriteAllBytes(badIncoming, original); ExtendEpub(badIncoming, true);
    Fails(() => AppendEdition.Compare(local.BookPath(added), badIncoming));
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
    var prefsReal = System.Text.Json.JsonSerializer.Serialize(new Dictionary<string, object> { ["flutter.library.v2"] = legacyBooks, ["flutter.categories.v1"] = new[] { "Romans" }, ["flutter.marks.a"] = "[{\"cfi\":\"epubcfi(/6/2)\"}]", ["flutter.highlights.a"] = "[{\"cfi\":\"epubcfi(/6/2)\",\"text\":\"Passage\",\"note\":\"Note\"}]" });
    await File.WriteAllTextAsync(Path.Combine(oldProfile, "shared_preferences.json"), prefsReal);
    var migrated = new NativeLibrary(Path.Combine(temp, "native-migrated")); await migrated.LoadAsync();
    var backup = await LegacyMigration.ImportAsync(migrated, oldProfile);
    Check(migrated.Books.Count == 1 && migrated.Books[0].Bookmarks.Count == 1 && migrated.Books[0].Highlights[0].Note == "Note", "Migration transfers marks and notes");
    Check((await File.ReadAllBytesAsync(migrated.BookPath(migrated.Books[0]))).SequenceEqual(original), "Migration copies EPUB");
    Check(File.Exists(Path.Combine(backup, "shared_preferences.json")) && (await File.ReadAllTextAsync(Path.Combine(oldProfile, "shared_preferences.json"))) == prefsReal, "Migration retains backup and source");
    await FailsAsync(() => LegacyMigration.ImportAsync(migrated, oldProfile));
    await FailsAsync(() => UpdateDownload.DownloadAsync(new Uri("http://github.com/test"), new string('a', 64), Path.Combine(temp, "setup.exe")));
    await FailsAsync(() => UpdateDownload.DownloadAsync(new Uri("https://evil.example/test"), new string('a', 64), Path.Combine(temp, "setup.exe")));
    Check(!File.Exists(Path.Combine(temp, "setup.exe")), "Rejected update must not create file");
}
finally { Directory.Delete(temp, true); }
Console.WriteLine("All core checks passed.");
Console.WriteLine("Native EPINAL1 example: " + pos.Encode());
