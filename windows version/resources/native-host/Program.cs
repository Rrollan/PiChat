using System.Diagnostics;

static string FindNode()
{
    var candidates = new List<string>();
    var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
    var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    if (!string.IsNullOrWhiteSpace(appData)) candidates.Add(Path.Combine(appData, "npm", "node.exe"));
    if (!string.IsNullOrWhiteSpace(localAppData)) candidates.Add(Path.Combine(localAppData, "Programs", "nodejs", "node.exe"));
    candidates.Add(@"C:\Program Files\nodejs\node.exe");
    candidates.Add(@"C:\Program Files (x86)\nodejs\node.exe");

    foreach (var candidate in candidates)
    {
        if (File.Exists(candidate)) return candidate;
    }

    var path = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
    foreach (var dir in path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
    {
        var candidate = Path.Combine(dir, "node.exe");
        if (File.Exists(candidate)) return candidate;
    }

    return "node.exe";
}

var hostDir = AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
var scriptPath = Path.Combine(hostDir, "browspi-native-host.mjs");
if (!File.Exists(scriptPath))
{
    Console.Error.WriteLine($"PiChat native host script not found: {scriptPath}");
    return 2;
}

Environment.SetEnvironmentVariable("BROWSPI_PAIRING_DIR", hostDir);
Environment.SetEnvironmentVariable("BROWSPI_PAIRING_CONFIG", Path.Combine(hostDir, "pairing.json"));
Environment.SetEnvironmentVariable("BROWSPI_BROWSER_TOOLS_EXTENSION", Path.Combine(hostDir, "browser-tools", "index.ts"));

var psi = new ProcessStartInfo
{
    FileName = FindNode(),
    UseShellExecute = false,
    RedirectStandardInput = true,
    RedirectStandardOutput = true,
    RedirectStandardError = true,
    CreateNoWindow = true
};
psi.ArgumentList.Add(scriptPath);

using var child = new Process { StartInfo = psi, EnableRaisingEvents = true };
if (!child.Start())
{
    Console.Error.WriteLine("Could not start Node.js for PiChat native host.");
    return 3;
}

var stdinTask = Task.Run(async () =>
{
    try
    {
        await Console.OpenStandardInput().CopyToAsync(child.StandardInput.BaseStream);
        child.StandardInput.Close();
    }
    catch { /* browser closed stdin */ }
});

var stdoutTask = Task.Run(async () =>
{
    try
    {
        await child.StandardOutput.BaseStream.CopyToAsync(Console.OpenStandardOutput());
        await Console.OpenStandardOutput().FlushAsync();
    }
    catch { /* browser closed stdout */ }
});

var stderrTask = Task.Run(async () =>
{
    try
    {
        await child.StandardError.BaseStream.CopyToAsync(Console.OpenStandardError());
        await Console.OpenStandardError().FlushAsync();
    }
    catch { /* stderr unavailable */ }
});

await Task.WhenAny(Task.Run(() => child.WaitForExit()), stdinTask);
if (!child.HasExited)
{
    try { child.Kill(entireProcessTree: true); } catch { }
}

await Task.WhenAll(stdoutTask, stderrTask).WaitAsync(TimeSpan.FromSeconds(3)).ContinueWith(_ => { });
return child.ExitCode;
