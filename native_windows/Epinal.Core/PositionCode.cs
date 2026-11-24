using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Epinal.Core;

/// Compatible with EPINAL1 codes produced by the Android Flutter reader.
public sealed record PositionCode(string BookHash, string Cfi, double Progress)
{
    private const int MaxLength = 12000;
    private static readonly Regex HashPattern = new("^[a-f0-9]{64}$", RegexOptions.CultureInvariant);
    private static readonly Regex PayloadPattern = new("^[A-Za-z0-9_-]+$", RegexOptions.CultureInvariant);
    private static readonly Regex CheckPattern = new("^[a-f0-9]{12}$", RegexOptions.CultureInvariant);

    private void Validate()
    {
        if (!HashPattern.IsMatch(BookHash) || Cfi.Length > 4096 ||
            !Cfi.StartsWith("epubcfi(", StringComparison.Ordinal) || !Cfi.EndsWith(')') ||
            Cfi.Any(c => c < 32 || c == 127) || !double.IsFinite(Progress) || Progress < 0 || Progress > 1)
            throw new FormatException("Position de lecture invalide.");
    }

    public string Encode()
    {
        Validate();
        var data = JsonSerializer.SerializeToUtf8Bytes(new { h = BookHash, c = Cfi, p = Progress });
        var payload = Convert.ToBase64String(data).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var content = "EPINAL1." + payload;
        var checksum = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(content))).ToLowerInvariant()[..12];
        var code = content + "." + checksum;
        if (code.Length > MaxLength) throw new FormatException("Position trop longue.");
        return code;
    }

    public static PositionCode Decode(string raw)
    {
        if (raw.Length > MaxLength) throw new FormatException("Code trop long.");
        var code = string.Concat(raw.Where(c => !char.IsWhiteSpace(c)));
        var parts = code.Split('.');
        if (parts.Length != 3 || parts[0] != "EPINAL1" || !PayloadPattern.IsMatch(parts[1]) || !CheckPattern.IsMatch(parts[2]))
            throw new FormatException("Code de lecture invalide.");
        var digest = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(parts[0] + "." + parts[1]))).ToLowerInvariant()[..12];
        if (!CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(digest), Encoding.ASCII.GetBytes(parts[2])))
            throw new FormatException("Code incomplet ou modifié.");
        try
        {
            var payload = parts[1].Replace('-', '+').Replace('_', '/');
            payload = payload.PadRight((payload.Length + 3) / 4 * 4, '=');
            using var doc = JsonDocument.Parse(Convert.FromBase64String(payload));
            var root = doc.RootElement;
            var result = new PositionCode(root.GetProperty("h").GetString()!, root.GetProperty("c").GetString()!, root.GetProperty("p").GetDouble());
            if (result.BookHash is null || result.Cfi is null) throw new FormatException("Code de lecture invalide.");
            result.Validate();
            return result;
        }
        catch (Exception e) when (e is JsonException or InvalidOperationException or KeyNotFoundException or ArgumentException)
        {
            throw new FormatException("Code de lecture invalide.", e);
        }
    }

    public static async Task<string> FileHashAsync(string path, CancellationToken cancellation = default)
    {
        await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, true);
        return Convert.ToHexString(await SHA256.HashDataAsync(stream, cancellation)).ToLowerInvariant();
    }
}
