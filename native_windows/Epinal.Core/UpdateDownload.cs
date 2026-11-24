using System.Net;
using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace Epinal.Core;

/// Download only. Installation and user consent belong in the Windows UI.
/// GitHub's digest detects damaged downloads, not a compromised publisher.
public static class UpdateDownload
{
    public const long MaxBytes = 512L * 1024 * 1024;
    private static readonly HashSet<string> Hosts = new(StringComparer.OrdinalIgnoreCase)
        { "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com" };

    public static async Task DownloadAsync(Uri asset, string sha256, string destination, IProgress<long>? progress = null, CancellationToken cancellation = default)
    {
        if (!Regex.IsMatch(sha256, "^[a-fA-F0-9]{64}$")) throw new ArgumentException("SHA-256 invalide.");
        if (File.Exists(destination) || Directory.Exists(destination)) throw new IOException("Le fichier de destination existe déjà.");
        var stage = Path.GetFullPath(destination) + "." + Guid.NewGuid().ToString("N") + ".part";
        using var handler = new HttpClientHandler { AllowAutoRedirect = false };
        using var client = new HttpClient(handler) { Timeout = TimeSpan.FromMinutes(15) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Epinal-Native-Update/1.0");
        try
        {
            var current = asset;
            for (int redirects = 0; redirects <= 5; redirects++)
            {
                if (current.Scheme != Uri.UriSchemeHttps || !Hosts.Contains(current.Host) || !string.IsNullOrEmpty(current.UserInfo) || !current.IsDefaultPort)
                    throw new InvalidOperationException("Adresse de téléchargement non autorisée.");
                using var response = await client.GetAsync(current, HttpCompletionOption.ResponseHeadersRead, cancellation);
                if ((int)response.StatusCode is >= 300 and < 400)
                {
                    if (response.Headers.Location is null || redirects == 5) throw new HttpRequestException("Redirection invalide.");
                    current = new Uri(current, response.Headers.Location);
                    continue;
                }
                response.EnsureSuccessStatusCode();
                if (response.Content.Headers.ContentLength > MaxBytes) throw new IOException("Téléchargement trop volumineux.");
                await using (var input = await response.Content.ReadAsStreamAsync(cancellation))
                await using (var output = new FileStream(stage, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true))
                {
                    var buffer = new byte[81920];
                    long total = 0;
                    int n;
                    while ((n = await input.ReadAsync(buffer, cancellation)) != 0)
                    {
                        total += n;
                        if (total > MaxBytes) throw new IOException("Téléchargement trop volumineux.");
                        await output.WriteAsync(buffer.AsMemory(0, n), cancellation);
                        progress?.Report(total);
                    }
                }
                var actual = await PositionCode.FileHashAsync(stage, cancellation);
                if (!CryptographicOperations.FixedTimeEquals(Convert.FromHexString(actual), Convert.FromHexString(sha256)))
                    throw new InvalidDataException("L'intégrité du téléchargement ne correspond pas.");
                File.Move(stage, destination);
                return;
            }
            throw new HttpRequestException("Trop de redirections.");
        }
        finally { if (File.Exists(stage)) File.Delete(stage); }
    }
}
