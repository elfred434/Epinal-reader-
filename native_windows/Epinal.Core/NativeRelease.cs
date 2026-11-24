using System.Text.Json;
using System.Text.RegularExpressions;

namespace Epinal.Core;

/// Parses only dedicated, stable Windows-native release assets. An Android
/// release or older Windows Flutter installer can never be selected.
public sealed record NativeRelease(Version Version, Uri Url, string Sha256)
{
    private const string FileName = "Epinal-Native-Setup-x64.exe";
    public static NativeRelease? Select(JsonElement releases, Version installed, NativeRelease? best = null)
    {
        if (releases.ValueKind != JsonValueKind.Array) throw new FormatException("Réponse GitHub invalide.");
        foreach (var release in releases.EnumerateArray())
        {
            if (release.ValueKind != JsonValueKind.Object ||
                (release.TryGetProperty("draft", out var draft) && draft.ValueKind == JsonValueKind.True) ||
                (release.TryGetProperty("prerelease", out var pre) && pre.ValueKind == JsonValueKind.True) ||
                !release.TryGetProperty("tag_name", out var tagValue) || tagValue.ValueKind != JsonValueKind.String) continue;
            var tag = tagValue.GetString()!;
            var match = Regex.Match(tag, @"^windows-v(\d+\.\d+\.\d+)$", RegexOptions.CultureInvariant);
            if (!match.Success || !Version.TryParse(match.Groups[1].Value, out var version) || version <= installed || (best is not null && version <= best.Version)) continue;
            if (!release.TryGetProperty("assets", out var assets) || assets.ValueKind != JsonValueKind.Array) throw new FormatException("Liste des fichiers invalide.");
            foreach (var asset in assets.EnumerateArray())
            {
                if (!asset.TryGetProperty("name", out var name) || name.GetString() != FileName) continue;
                var digest = asset.TryGetProperty("digest", out var d) ? d.GetString() : null;
                var address = asset.TryGetProperty("browser_download_url", out var u) ? u.GetString() : null;
                if (digest is null || !Regex.IsMatch(digest, "^sha256:[a-fA-F0-9]{64}$") ||
                    !Uri.TryCreate(address, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps ||
                    uri.Host != "github.com" || !uri.IsDefaultPort || !string.IsNullOrEmpty(uri.UserInfo) ||
                    !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment) ||
                    uri.AbsolutePath != $"/elfred434/Epinal-reader-/releases/download/{tag}/{FileName}")
                    throw new FormatException("Métadonnées de mise à jour invalides.");
                best = new NativeRelease(version, uri, digest[7..].ToLowerInvariant());
                break;
            }
        }
        return best;
    }
}
