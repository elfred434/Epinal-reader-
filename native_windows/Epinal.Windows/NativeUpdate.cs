using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using Epinal.Core;

namespace Epinal.Windows;

internal static class NativeUpdate
{
    public static async Task<NativeRelease?> FindAsync()
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Epinal-Native/0.1");
        var installed = Assembly.GetExecutingAssembly().GetName().Version ?? new Version(0, 1);
        NativeRelease? best = null;
        // Windows releases do not replace Android's GitHub latest release.
        for (var page = 1; page <= 10; page++)
        {
            using var response = await client.GetAsync($"https://api.github.com/repos/elfred434/Epinal-reader-/releases?per_page=100&page={page}", HttpCompletionOption.ResponseHeadersRead);
            response.EnsureSuccessStatusCode();
            if (response.Content.Headers.ContentLength > 1024 * 1024) throw new IOException("Réponse de mise à jour trop volumineuse.");
            await using var stream = await response.Content.ReadAsStreamAsync();
            using var buffer = new MemoryStream();
            var bytes = new byte[16384]; int read;
            while ((read = await stream.ReadAsync(bytes)) != 0)
            {
                if (buffer.Length + read > 1024 * 1024) throw new IOException("Réponse de mise à jour trop volumineuse.");
                buffer.Write(bytes, 0, read);
            }
            using var json = JsonDocument.Parse(buffer.ToArray());
            best = NativeRelease.Select(json.RootElement, installed, best);
            if (json.RootElement.GetArrayLength() < 100) break;
        }
        return best;
    }
}
