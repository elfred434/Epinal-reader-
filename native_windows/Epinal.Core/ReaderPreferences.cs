using System.Text.Json;

namespace Epinal.Core;

/// User preferences are independent of the Flutter profile.
public sealed class ReaderPreferences
{
    public int FontPercent { get; set; } = 100;
    public int Theme { get; set; }
    public bool Scrolling { get; set; }
    public string? RecentBookId { get; set; }
    private static readonly SemaphoreSlim Gate = new(1, 1);
    private static string FileName(string root) => Path.Combine(root, "reader-preferences.json");
    public static async Task<ReaderPreferences> LoadAsync(string root)
    {
        var path = FileName(root);
        if (!File.Exists(path)) return new ReaderPreferences();
        var value = JsonSerializer.Deserialize<ReaderPreferences>(await File.ReadAllTextAsync(path)) ?? throw new FormatException("Réglages illisibles.");
        if (value.FontPercent is < 60 or > 220 || value.Theme is < 0 or > 3 || value.RecentBookId is { Length: > 128 }) throw new FormatException("Réglages invalides.");
        return value;
    }
    public async Task SaveAsync(string root)
    {
        if (FontPercent is < 60 or > 220 || Theme is < 0 or > 3 || RecentBookId is { Length: > 128 }) throw new FormatException("Réglages invalides.");
        await Gate.WaitAsync();
        try
        {
            Directory.CreateDirectory(root);
            var path = FileName(root); var stage = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try { await File.WriteAllTextAsync(stage, JsonSerializer.Serialize(this)); File.Move(stage, path, true); }
            finally { if (File.Exists(stage)) File.Delete(stage); }
        }
        finally { Gate.Release(); }
    }
    public static ReaderPreferences FromFlutter(JsonElement root)
    {
        var result = new ReaderPreferences();
        if (root.TryGetProperty("flutter.reader.font", out var font) && font.TryGetInt32(out var value) && value is >= 12 and <= 36) result.FontPercent = (int)Math.Round(value * 100.0 / 18);
        if (root.TryGetProperty("flutter.reader.theme", out var theme) && theme.TryGetInt32(out value) && value is >= 0 and <= 3) result.Theme = value;
        if (root.TryGetProperty("flutter.reader.mode", out var mode) && mode.ValueKind == JsonValueKind.String) result.Scrolling = mode.GetString() == "longStrip";
        return result;
    }
}
