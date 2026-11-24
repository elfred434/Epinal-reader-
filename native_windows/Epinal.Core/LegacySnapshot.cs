using System.Security.Cryptography;

namespace Epinal.Core;

/// Creates an independent, verified copy without changing the Flutter profile.
/// The app must be closed while making the snapshot; files changing during
/// copying are rejected. The target must not yet exist.
public static class LegacySnapshot
{
    public static async Task CreateAsync(string source, string destination, CancellationToken cancellation = default)
    {
        source = Path.GetFullPath(source).TrimEnd(Path.DirectorySeparatorChar);
        destination = Path.GetFullPath(destination).TrimEnd(Path.DirectorySeparatorChar);
        var comparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
        if (source.Equals(destination, comparison) || destination.StartsWith(source + Path.DirectorySeparatorChar, comparison) || source.StartsWith(destination + Path.DirectorySeparatorChar, comparison))
            throw new ArgumentException("Les dossiers source et destination doivent être distincts.");
        if (!Directory.Exists(source)) throw new DirectoryNotFoundException(source);
        if (File.Exists(destination) || Directory.Exists(destination)) throw new IOException("La destination existe déjà.");
        var parent = Path.GetDirectoryName(destination) ?? throw new ArgumentException("Destination invalide.");
        Directory.CreateDirectory(parent);
        var stage = Path.Combine(parent, ".epinal-migration-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(stage);
        try
        {
            await CopyDirectory(source, stage, cancellation);
            Directory.Move(stage, destination);
        }
        catch
        {
            if (Directory.Exists(stage)) Directory.Delete(stage, true);
            throw;
        }
    }

    private static async Task CopyDirectory(string source, string destination, CancellationToken cancellation)
    {
        foreach (var entry in Directory.EnumerateFileSystemEntries(source))
        {
            cancellation.ThrowIfCancellationRequested();
            var attributes = File.GetAttributes(entry);
            if ((attributes & FileAttributes.ReparsePoint) != 0)
                throw new IOException("La bibliothèque contient un lien symbolique : " + entry);
            var target = Path.Combine(destination, Path.GetFileName(entry));
            if ((attributes & FileAttributes.Directory) != 0)
            {
                Directory.CreateDirectory(target);
                await CopyDirectory(entry, target, cancellation);
            }
            else
            {
                await using (var input = new FileStream(entry, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, true))
                await using (var output = new FileStream(target, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true))
                    await input.CopyToAsync(output, cancellation);
                // A second read of the source detects changes while copying.
                var a = await PositionCode.FileHashAsync(entry, cancellation);
                var b = await PositionCode.FileHashAsync(target, cancellation);
                if (!CryptographicOperations.FixedTimeEquals(Convert.FromHexString(a), Convert.FromHexString(b)))
                    throw new IOException("Un fichier a changé pendant la copie : " + entry);
            }
        }
    }
}
