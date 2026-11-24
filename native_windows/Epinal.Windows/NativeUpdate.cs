using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Epinal.Windows;

internal sealed record NativeUpdate(Version Version, Uri Url, string Sha256)
{
    // Exact asset name prevents accidentally installing the existing Flutter setup.
    public static async Task<NativeUpdate?> FindAsync()
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Epinal-Native/0.1");
        using var response = await client.GetAsync("https://api.github.com/repos/elfred434/Epinal-reader-/releases/latest", HttpCompletionOption.ResponseHeadersRead);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength > 1024 * 1024) throw new IOException("Réponse de mise à jour trop volumineuse.");
        await using var stream = await response.Content.ReadAsStreamAsync();
        using var buffer = new MemoryStream();
        var bytes = new byte[16384]; int read;
        while ((read = await stream.ReadAsync(bytes)) != 0) { if (buffer.Length + read > 1024 * 1024) throw new IOException("Réponse de mise à jour trop volumineuse."); buffer.Write(bytes, 0, read); }
        using var json = JsonDocument.Parse(buffer.ToArray());
        var root = json.RootElement;
        var tag = root.GetProperty("tag_name").GetString()?.TrimStart('v');
        if (!Version.TryParse(tag, out var version) || version <= (Assembly.GetExecutingAssembly().GetName().Version ?? new Version(0, 1))) return null;
        foreach (var asset in root.GetProperty("assets").EnumerateArray())
        {
            if (asset.GetProperty("name").GetString() != "Epinal-Native-Setup-x64.exe") continue;
            var digest = asset.TryGetProperty("digest", out var d) ? d.GetString() : null;
            var address = asset.GetProperty("browser_download_url").GetString();
            if (digest is null || !Regex.IsMatch(digest, "^sha256:[0-9a-fA-F]{64}$") || !Uri.TryCreate(address, UriKind.Absolute, out var uri))
                throw new FormatException("Métadonnées de mise à jour invalides.");
            return new NativeUpdate(version, uri, digest[7..]);
        }
        return null;
    }
}
