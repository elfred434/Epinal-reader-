using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Epinal.Core;
using Microsoft.Web.WebView2.Core;
using Microsoft.Win32;

namespace Epinal.Windows;

public partial class MainWindow : Window
{
    private const string Origin = "https://epinal.local/";
    private readonly NativeLibrary library = new(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Epinal Native Experimental"));
    private NativeBook? current;
    private List<(string Label, string Href)> toc = [];
    private readonly System.Speech.Synthesis.SpeechSynthesizer speech = new();
    private bool scrolling, dark;
    private int size = 100;
    private string? selectionCfi, selectionText;
    private bool ready;
    private readonly string? smokeBook = Environment.GetEnvironmentVariable("EPINAL_SMOKE_EPUB");
    private readonly string? smokeLog = Environment.GetEnvironmentVariable("EPINAL_SMOKE_LOG");
    private bool smokeDisplayed, smokePosition, smokeToc;
    private System.Windows.Threading.DispatcherTimer? smokeTimer;
    private void SmokeLog(string message) { if (!string.IsNullOrEmpty(smokeLog)) File.AppendAllText(smokeLog, message + Environment.NewLine); }
    private void CheckSmoke()
    {
        if (string.IsNullOrEmpty(smokeBook) || !smokeDisplayed || !smokePosition || !smokeToc) return;
        SmokeLog("OK: EPUB affiché, sommaire et position reçus");
        smokeTimer?.Stop(); Application.Current.Shutdown(0);
    }

    public MainWindow()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        Closed += (_, _) => speech.Dispose();
    }
    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (!string.IsNullOrEmpty(smokeBook))
        {
            smokeTimer = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromSeconds(90) };
            smokeTimer.Tick += (_, _) => { SmokeLog("Délai dépassé : EPUB non chargé"); smokeTimer.Stop(); Application.Current.Shutdown(2); };
            smokeTimer.Start();
        }
        try
        {
            await library.LoadAsync();
            Refresh();
            var environment = await CoreWebView2Environment.CreateAsync(userDataFolder: Path.Combine(library.Root, "webview"));
            await Reader.EnsureCoreWebView2Async(environment);
            var web = Reader.CoreWebView2;
            web.Settings.AreDevToolsEnabled = false;
            web.Settings.AreDefaultContextMenusEnabled = false;
            web.Settings.IsStatusBarEnabled = false;
            web.Settings.IsZoomControlEnabled = false;
            web.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.All);
            web.WebResourceRequested += HandleResource;
            web.NavigationStarting += (_, args) => { if (args.Uri != Origin + "index.html") args.Cancel = true; };
            web.NewWindowRequested += (_, args) => args.Handled = true;
            web.WebMessageReceived += HandleMessage;
            ready = true;
            Status.Text = "Prototype expérimental : vos données Flutter ne sont pas modifiées.";
            if (!string.IsNullOrEmpty(smokeBook)) { SmokeLog("Initialisation OK"); var book = await library.ImportAsync(smokeBook); Open(book); }
        }
        catch (Exception ex) { if (!string.IsNullOrEmpty(smokeBook)) { SmokeLog("Initialisation : " + ex); Application.Current.Shutdown(2); } else Error("Initialisation impossible", ex); }
    }
    private void HandleResource(object? sender, CoreWebView2WebResourceRequestedEventArgs e)
    {
        try
        {
            var path = new Uri(e.Request.Uri);
            if (path.Scheme != "https" || path.Host != "epinal.local" || !path.IsDefaultPort || !string.IsNullOrEmpty(path.Query))
            { e.Response = Reader.CoreWebView2.Environment.CreateWebResourceResponse(null, 403, "Forbidden", ""); return; }
            var name = path.AbsolutePath;
            string file, type;
            if (name == "/book.epub" && current is not null) { file = library.BookPath(current); type = "application/epub+zip"; }
            else
            {
                var types = new Dictionary<string, string> { ["/index.html"] = "text/html; charset=utf-8", ["/reader.css"] = "text/css", ["/reader.js"] = "text/javascript", ["/epub.js"] = "text/javascript", ["/jszip.min.js"] = "text/javascript" };
                if (!types.TryGetValue(name, out var mime)) { e.Response = Reader.CoreWebView2.Environment.CreateWebResourceResponse(null, 404, "Not Found", ""); return; }
                file = Path.Combine(AppContext.BaseDirectory, "Reader", name.TrimStart('/'));
                type = mime;
            }
            // Serve only a strict allowlist; do not map the profile or filesystem.
            var bytes = File.ReadAllBytes(file);
            e.Response = Reader.CoreWebView2.Environment.CreateWebResourceResponse(new MemoryStream(bytes), 200, "OK", $"Content-Type: {type}\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n");
        }
        catch { e.Response = Reader.CoreWebView2.Environment.CreateWebResourceResponse(null, 500, "Error", ""); }
    }
    private async void HandleMessage(object? sender, CoreWebView2WebMessageReceivedEventArgs e)
    {
        if (e.Source != Origin + "index.html") return;
        try
        {
            using var json = JsonDocument.Parse(e.WebMessageAsJson);
            var root = json.RootElement;
            var type = root.GetProperty("type").GetString();
            if (type == "ready" && current is not null)
                await Script($"openBook({JsonSerializer.Serialize(current.Cfi)},{JsonSerializer.Serialize(current.Progress)})");
            else if (type == "position" && current is not null)
            {
                var data = root.GetProperty("data");
                var cfi = data.GetProperty("cfi").GetString();
                var value = data.GetProperty("progress").GetDouble();
                if (cfi is null || cfi.Length > 4096 || !double.IsFinite(value) || value is < 0 or > 1) return;
                current.Cfi = cfi; current.Progress = value;
                Progress.Text = $"{value:P0}";
                await library.SaveAsync();
                smokePosition = true; CheckSmoke();
            }
            else if (type == "speak")
            {
                var text = root.GetProperty("data").GetString();
                if (!string.IsNullOrWhiteSpace(text)) { speech.SpeakAsyncCancelAll(); speech.SpeakAsync(text); Status.Text = "Lecture vocale en cours."; }
            }
            else if (type == "displayed" && current is not null)
            {
                foreach (var highlight in current.Highlights) await Script("addHighlight(" + JsonSerializer.Serialize(highlight.Cfi) + ")");
                smokeDisplayed = true; CheckSmoke();
            }
            else if (type == "selection")
            {
                var data = root.GetProperty("data");
                selectionCfi = data.GetProperty("cfi").GetString();
                selectionText = data.GetProperty("text").GetString();
                Status.Text = "Texte sélectionné : utilisez Surligner pour l’enregistrer.";
            }
            else if (type == "search")
            {
                var results = root.GetProperty("data").EnumerateArray().Select(x => (x.GetProperty("label").GetString() ?? "", x.GetProperty("href").GetString() ?? "")).ToList();
                var value = Choose("Résultats de recherche", results);
                if (value is not null) await Script("goTo(" + JsonSerializer.Serialize(value) + ")");
            }
            else if (type == "toc")
            {
                toc = root.GetProperty("data").EnumerateArray().Select(x => (x.GetProperty("label").GetString() ?? "", x.GetProperty("href").GetString() ?? "")).ToList();
                smokeToc = toc.Count > 0; CheckSmoke();
            }
            else if (type == "error") { Status.Text = "Lecteur : " + root.GetProperty("data").GetString(); SmokeLog(Status.Text); }
        }
        catch (Exception ex) { Status.Text = "Erreur du lecteur : " + ex.Message; SmokeLog(Status.Text); }
    }
    private void Refresh()
    {
        if (BooksList is null) return;
        var query = Filter.Text.Trim();
        BooksList.ItemsSource = library.Books.Where(b => b.Title.Contains(query, StringComparison.CurrentCultureIgnoreCase) || b.Author.Contains(query, StringComparison.CurrentCultureIgnoreCase) || b.Categories.Any(c => c.Contains(query, StringComparison.CurrentCultureIgnoreCase))).ToList();
    }
    private async Task Script(string script) { if (ready && current is not null) await Reader.ExecuteScriptAsync(script); }
    private void Error(string title, Exception error) => MessageBox.Show(this, error.Message, title, MessageBoxButton.OK, MessageBoxImage.Error);
    private async void ImportClick(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog { Filter = "Livres EPUB (*.epub)|*.epub", Title = "Importer un livre" };
        if (dialog.ShowDialog(this) != true) return;
        try { var book = await library.ImportAsync(dialog.FileName); Refresh(); BooksList.SelectedItem = book; Status.Text = "Livre copié dans la bibliothèque interne."; }
        catch (Exception ex) { Error("Import impossible", ex); }
    }
    private void FilterChanged(object sender, TextChangedEventArgs e) => Refresh();
    private void OpenClick(object sender, RoutedEventArgs e) { if (BooksList.SelectedItem is NativeBook b) Open(b); }
    private void ResumeClick(object sender, RoutedEventArgs e) { var book = current ?? library.Books.FirstOrDefault(); if (book is not null) Open(book); }
    private void Open(NativeBook book)
    {
        if (!ready) { MessageBox.Show(this, "Le lecteur n’est pas prêt. WebView2 Runtime est nécessaire."); return; }
        if (!File.Exists(library.BookPath(book))) { MessageBox.Show(this, "Le fichier interne de ce livre est introuvable."); return; }
        current = book; toc.Clear(); selectionCfi = selectionText = null; CurrentTitle.Text = book.Title; Progress.Text = $"{book.Progress:P0}";
        Reader.CoreWebView2.Navigate(Origin + "index.html");
    }
    private async void PreviousClick(object sender, RoutedEventArgs e) => await Script("goPrevious()");
    private async void NextClick(object sender, RoutedEventArgs e) => await Script("goNext()");
    private async void SpeakClick(object sender, RoutedEventArgs e) => await Script("readPage()");
    private void StopSpeakClick(object sender, RoutedEventArgs e) { speech.SpeakAsyncCancelAll(); Status.Text = "Lecture vocale arrêtée."; }
    private async void FlowClick(object sender, RoutedEventArgs e) { scrolling = !scrolling; await Script("setFlow(" + JsonSerializer.Serialize(scrolling ? "scrolled-doc" : "paginated") + ")"); }
    private async void ThemeClick(object sender, RoutedEventArgs e) { dark = !dark; await Script("setTheme(" + (dark ? "true" : "false") + ")"); }
    private async void CategoriesClick(object sender, RoutedEventArgs e)
    {
        if (BooksList.SelectedItem is not NativeBook book) return;
        var input = Prompt("Classer le livre", "Catégories, séparées par des virgules :", string.Join(", ", book.Categories));
        if (input is null) return;
        book.Categories = input.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).Where(x => x.Length <= 40).Distinct(StringComparer.CurrentCultureIgnoreCase).ToList();
        await library.SaveAsync(); Refresh(); Status.Text = "Catégories enregistrées.";
    }
    private async void SmallerClick(object sender, RoutedEventArgs e) { size = Math.Max(60, size - 10); await Script($"fontSize({size})"); }
    private async void BiggerClick(object sender, RoutedEventArgs e) { size = Math.Min(220, size + 10); await Script($"fontSize({size})"); }
    private async void TocClick(object sender, RoutedEventArgs e) { var value = Choose("Sommaire", toc); if (value is not null) await Script("goTo(" + JsonSerializer.Serialize(value) + ")"); }
    private async void SearchClick(object sender, RoutedEventArgs e)
    {
        if (current is null) return;
        var text = Prompt("Rechercher dans le livre", "Texte à rechercher :", "");
        if (!string.IsNullOrWhiteSpace(text)) { Status.Text = "Recherche en cours…"; await Script("searchBook(" + JsonSerializer.Serialize(text) + ")"); }
    }
    private async void HighlightClick(object sender, RoutedEventArgs e)
    {
        if (current is null || string.IsNullOrWhiteSpace(selectionCfi) || string.IsNullOrWhiteSpace(selectionText)) { MessageBox.Show(this, "Sélectionnez d’abord un passage dans le livre."); return; }
        var note = Prompt("Surligner", "Note facultative :", "");
        if (note is null) return;
        if (selectionCfi.Length > 4096 || selectionText.Length > 20000) { MessageBox.Show(this, "Sélection trop longue."); return; }
        var highlight = new NativeHighlight { Cfi = selectionCfi, Text = selectionText, Note = note };
        current.Highlights.Add(highlight);
        await library.SaveAsync();
        await Script("addHighlight(" + JsonSerializer.Serialize(highlight.Cfi) + ")");
        selectionCfi = selectionText = null; Status.Text = "Passage enregistré.";
    }
    private async void HighlightsClick(object sender, RoutedEventArgs e)
    {
        if (current is null) return;
        var choices = current.Highlights.Select(x => ((x.Text.Length > 130 ? x.Text[..130] + "…" : x.Text) + (string.IsNullOrEmpty(x.Note) ? "" : " — " + x.Note), x.Cfi)).ToList();
        var selected = Choose("Mes passages", choices); if (selected is not null) await Script("goTo(" + JsonSerializer.Serialize(selected) + ")");
    }
    private string? Prompt(string title, string label, string initial)
    {
        var text = new TextBox { Text = initial, Margin = new Thickness(12) };
        var ok = new Button { Content = "Valider", IsDefault = true, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(12) };
        var panel = new StackPanel(); panel.Children.Add(new TextBlock { Text = label, Margin = new Thickness(12, 12, 12, 0) }); panel.Children.Add(text); panel.Children.Add(ok);
        var dialog = new Window { Title = title, Width = 450, SizeToContent = SizeToContent.Height, Owner = this, Content = panel, WindowStartupLocation = WindowStartupLocation.CenterOwner };
        ok.Click += (_, _) => dialog.DialogResult = true;
        return dialog.ShowDialog() == true ? text.Text : null;
    }
    private async void BookmarkClick(object sender, RoutedEventArgs e)
    {
        if (current?.Cfi is null) return;
        if (!current.Bookmarks.Contains(current.Cfi)) { current.Bookmarks.Add(current.Cfi); await library.SaveAsync(); }
        Status.Text = "Signet ajouté.";
    }
    private async void BookmarksClick(object sender, RoutedEventArgs e)
    {
        if (current is null) return;
        var choices = current.Bookmarks.Select((x, i) => ($"Signet {i + 1}", x)).ToList();
        var selected = Choose("Mes signets", choices); if (selected is not null) await Script("goTo(" + JsonSerializer.Serialize(selected) + ")");
    }
    private string? Choose(string title, List<(string Label, string Href)> values)
    {
        if (values.Count == 0) { MessageBox.Show(this, "Aucun élément disponible.", title); return null; }
        var list = new ListBox { Margin = new Thickness(12), ItemsSource = values, DisplayMemberPath = "Label" };
        var dialog = new Window { Title = title, Width = 480, Height = 520, Owner = this, Content = list, WindowStartupLocation = WindowStartupLocation.CenterOwner };
        list.MouseDoubleClick += (_, _) => { if (list.SelectedItem is not null) dialog.DialogResult = true; };
        return dialog.ShowDialog() == true && list.SelectedItem is ValueTuple<string, string> choice ? choice.Item2 : null;
    }
    private async void CopyPositionClick(object sender, RoutedEventArgs e)
    {
        try { if (current?.Cfi is null) return; var hash = await PositionCode.FileHashAsync(library.BookPath(current)); Clipboard.SetText(new PositionCode(hash, current.Cfi, current.Progress).Encode()); Status.Text = "Code de position copié."; }
        catch (Exception ex) { Error("Copie impossible", ex); }
    }
    private async void PastePositionClick(object sender, RoutedEventArgs e)
    {
        try
        {
            if (current is null || !Clipboard.ContainsText()) return;
            var code = PositionCode.Decode(Clipboard.GetText());
            if (await PositionCode.FileHashAsync(library.BookPath(current)) != code.BookHash) { MessageBox.Show(this, "Ce code correspond à une autre édition EPUB."); return; }
            if (MessageBox.Show(this, "Remplacer la position actuelle par celle du presse-papiers ?", "Position de lecture", MessageBoxButton.YesNo) != MessageBoxResult.Yes) return;
            current.Cfi = code.Cfi; current.Progress = code.Progress; await library.SaveAsync(); await Script("goTo(" + JsonSerializer.Serialize(code.Cfi) + ")");
        }
        catch (Exception ex) { Error("Position invalide", ex); }
    }
    private async void ExportClick(object sender, RoutedEventArgs e)
    {
        if (BooksList.SelectedItem is not NativeBook book) return;
        var dialog = new SaveFileDialog { Filter = "Livre EPUB (*.epub)|*.epub", FileName = "Livre.epub" };
        if (dialog.ShowDialog(this) != true) return;
        try
        {
            if (Path.GetFullPath(dialog.FileName).Equals(Path.GetFullPath(library.BookPath(book)), StringComparison.OrdinalIgnoreCase)) throw new IOException("Choisissez un emplacement différent du fichier interne.");
            await using var input = File.OpenRead(library.BookPath(book)); await using var output = new FileStream(dialog.FileName, FileMode.Create, FileAccess.Write, FileShare.None, 81920, true); await input.CopyToAsync(output);
            Status.Text = "Livre exporté.";
        }
        catch (Exception ex) { Error("Export impossible", ex); }
    }
    private async void DeleteClick(object sender, RoutedEventArgs e)
    {
        if (BooksList.SelectedItem is not NativeBook book || MessageBox.Show(this, "Supprimer ce livre de la bibliothèque native ?", "Confirmation", MessageBoxButton.YesNo) != MessageBoxResult.Yes) return;
        try
        {
            library.Books.Remove(book); try { await library.SaveAsync(); } catch { library.Books.Add(book); throw; }
            if (current == book) { current = null; Reader.CoreWebView2.Navigate(Origin + "index.html"); CurrentTitle.Text = ""; }
            File.Delete(library.BookPath(book)); Refresh();
        }
        catch (Exception ex) { Error("Suppression impossible", ex); }
    }
    private async void AppendClick(object sender, RoutedEventArgs e)
    {
        if (BooksList.SelectedItem is not NativeBook book) { MessageBox.Show(this, "Choisissez le livre dans la bibliothèque."); return; }
        var dialog = new OpenFileDialog { Filter = "Livres EPUB (*.epub)|*.epub", Title = "Choisir le livre complet mis à jour" };
        if (dialog.ShowDialog(this) != true) return;
        try
        {
            Status.Text = "Comparaison en cours…";
            var preview = await Task.Run(() => AppendEdition.Compare(library.BookPath(book), dialog.FileName));
            if (MessageBox.Show(this, $"{preview.AddedSections} nouvelle(s) section(s). Les anciennes sections et ressources sont identiques. Ajouter la suite à la copie interne ?", "Ajouter la suite", MessageBoxButton.YesNo) != MessageBoxResult.Yes) return;
            if (current == book) { current = null; Reader.CoreWebView2.Navigate(Origin + "index.html"); }
            await AppendEdition.ApplyAsync(library, book, dialog.FileName, preview);
            Status.Text = "Suite ajoutée à la copie interne. Version précédente conservée.";
        }
        catch (Exception ex) { Error("Ajout de la suite impossible", ex); }
    }
    private async void RestoreClick(object sender, RoutedEventArgs e)
    {
        if (BooksList.SelectedItem is not NativeBook book || MessageBox.Show(this, "Rétablir la version précédente et sa position ?", "Rétablir", MessageBoxButton.YesNo) != MessageBoxResult.Yes) return;
        try
        {
            if (current == book) { current = null; Reader.CoreWebView2.Navigate(Origin + "index.html"); }
            await AppendEdition.RestoreAsync(library, book); Status.Text = "Version précédente rétablie.";
        }
        catch (Exception ex) { Error("Restauration impossible", ex); }
    }
    private async void UpdateClick(object sender, RoutedEventArgs e)
    {
        try
        {
            Status.Text = "Recherche de mise à jour native…";
            var update = await NativeUpdate.FindAsync();
            if (update is null) { Status.Text = "Aucune mise à jour native disponible."; return; }
            var message = $"Version {update.Version} disponible. Télécharger l’installateur Windows natif ?\n\nUn contrôle SHA-256 détectera les fichiers endommagés. L’installateur n’est pas encore signé ; ce contrôle ne garantit pas l’identité de l’éditeur.";
            if (MessageBox.Show(this, message, "Mise à jour", MessageBoxButton.YesNo, MessageBoxImage.Information) != MessageBoxResult.Yes) return;
            var dir = Path.Combine(Path.GetTempPath(), "Epinal-update-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(dir);
            var path = Path.Combine(dir, "Epinal-Native-Setup-x64.exe");
            var progress = new System.Progress<long>(n => Status.Text = $"Téléchargement : {n / 1048576.0:F1} Mo");
            await UpdateDownload.DownloadAsync(update.Url, update.Sha256, path, progress);
            if (MessageBox.Show(this, "Téléchargement vérifié. Fermer Épinal et lancer l’installation ?", "Installer", MessageBoxButton.YesNo) != MessageBoxResult.Yes) { File.Delete(path); Directory.Delete(dir); Status.Text = "Installation annulée."; return; }
            var process = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(path) { UseShellExecute = true });
            if (process is null) throw new IOException("Impossible de lancer l’installateur.");
            Application.Current.Shutdown();
        }
        catch (Exception ex) { Error("Mise à jour impossible", ex); Status.Text = "Mise à jour interrompue ; votre application reste inchangée."; }
    }
    private async void MigrateClick(object sender, RoutedEventArgs e)
    {
        var source = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Epinal Reader", "Epinal");
        var message = "Fermez d’abord l’ancienne version Flutter d’Épinal. Sa bibliothèque sera copiée sans être modifiée et une sauvegarde complète sera conservée. Cette reprise expérimentale copie livres, positions, catégories, signets, passages et dernière version sauvegardée de chaque livre. Continuer ?";
        if (MessageBox.Show(this, message, "Reprendre la bibliothèque", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
        try
        {
            IsEnabled = false; Status.Text = "Sauvegarde et copie de l’ancienne bibliothèque…";
            var snapshot = await LegacyMigration.ImportAsync(library, source);
            Refresh(); Status.Text = "Bibliothèque copiée. Sauvegarde : " + snapshot;
        }
        catch (Exception ex) { Error("Reprise impossible", ex); Status.Text = "L’ancienne bibliothèque n’a pas été modifiée."; }
        finally { IsEnabled = true; }
    }
}
