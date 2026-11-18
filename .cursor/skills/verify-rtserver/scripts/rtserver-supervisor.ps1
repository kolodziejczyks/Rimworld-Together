param(
    [Parameter(Mandatory = $true)][string]$DataDir,
    [Parameter(Mandatory = $true)][string]$Dotnet,
    [Parameter(Mandatory = $true)][string]$Dll
)

$ErrorActionPreference = "Stop"
$queue = Join-Path $DataDir "queue"
New-Item -ItemType Directory -Force -Path $queue | Out-Null

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $Dotnet
$psi.Arguments = "`"$Dll`""
$psi.WorkingDirectory = $DataDir
$psi.RedirectStandardInput = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
[void]$proc.Start()
Set-Content -Path (Join-Path $DataDir "pid.txt") -Value $proc.Id -Encoding ascii

while (-not $proc.HasExited) {
    $files = @(Get-ChildItem -Path $queue -Filter "*.cmd" -ErrorAction SilentlyContinue | Sort-Object Name)
    foreach ($file in $files) {
        $line = (Get-Content -Path $file.FullName -Raw).TrimEnd("`r", "`n")
        $proc.StandardInput.WriteLine($line)
        $proc.StandardInput.Flush()
        Remove-Item -Path $file.FullName -Force
    }
    Start-Sleep -Milliseconds 100
}
