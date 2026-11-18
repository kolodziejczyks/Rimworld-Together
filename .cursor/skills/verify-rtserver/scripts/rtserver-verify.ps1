param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet("launch", "doctor", "send", "evidence", "cleanup")]
    [string]$Action,
    [Parameter(Position = 1)]
    [string]$CommandText,
    [string]$Expect,
    [string]$Feature = "unspecified",
    [int]$TimeoutSec = 15
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$RunsRoot = Join-Path $RepoRoot ".verify-runs"
$CurrentFile = Join-Path $RunsRoot "current.txt"
$EvidenceRoot = Join-Path $RepoRoot ".cursor\skills\verify-rtserver\evidence"
$Dll = Join-Path $RepoRoot "Source\Server\bin\Debug\net10.0\RTServer.dll"
$Project = Join-Path $RepoRoot "Source\Server\RTServer.csproj"
$Supervisor = Join-Path $PSScriptRoot "rtserver-supervisor.ps1"

function Get-Dotnet {
    $local = Join-Path $RepoRoot ".verify-tools\dotnet\dotnet.exe"
    if (Test-Path $local) { return $local }
    $cmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "No .NET SDK. Install the 10.0 SDK with https://dot.net/v1/dotnet-install.ps1 -Channel 10.0 -InstallDir `"$RepoRoot\.verify-tools\dotnet`"."
}

function Get-Instance {
    if (-not (Test-Path $CurrentFile)) { throw "No verification instance. Run launch first." }
    $id = (Get-Content $CurrentFile -Raw).Trim()
    $dir = Join-Path $RunsRoot $id
    $metaPath = Join-Path $dir "instance.json"
    if (-not (Test-Path $metaPath)) { throw "Instance $id has no instance.json." }
    $meta = Get-Content $metaPath -Raw | ConvertFrom-Json
    return [pscustomobject]@{ Id = $id; Dir = $dir; Meta = $meta; MetaPath = $metaPath }
}

function Get-SystemLog([string]$Dir) {
    $day = Get-Date -Format "yyyy-MM-dd"
    return (Join-Path $Dir "Logs\System\$day.txt")
}

function Test-ProcessAlive([int]$ProcessId) {
    if ($ProcessId -le 0) { return $false }
    return $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
}

function Wait-ForLog([string]$Path, [string]$Needle, [int]$Seconds, [int]$StartLength) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $Path) {
            $text = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
            if ($null -eq $text) { $text = "" }
            if ($text.Length -ge $StartLength -and $text.Substring($StartLength).Contains($Needle)) {
                return $text
            }
        }
        Start-Sleep -Milliseconds 200
    }
    throw "Timed out after $Seconds s waiting for '$Needle' in $Path."
}

function Log-Length([string]$Path) {
    if (-not (Test-Path $Path)) { return 0 }
    $text = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    if ($null -eq $text) { return 0 }
    return $text.Length
}

switch ($Action) {
    "launch" {
        New-Item -ItemType Directory -Force -Path $RunsRoot | Out-Null
        if (Test-Path $CurrentFile) {
            $existingId = (Get-Content $CurrentFile -Raw).Trim()
            $existingMetaPath = Join-Path $RunsRoot "$existingId\instance.json"
            if (Test-Path $existingMetaPath) {
                $old = Get-Content $existingMetaPath -Raw | ConvertFrom-Json
                if (Test-ProcessAlive ([int]$old.pid)) {
                    throw "Instance $existingId is still running as pid $($old.pid). Run cleanup before launch."
                }
            }
        }
        $dotnet = Get-Dotnet
        if (-not (Test-Path $Dll)) {
            & $dotnet build $Project -c Debug
            if ($LASTEXITCODE -ne 0) { throw "dotnet build failed." }
        }
        $id = Get-Date -Format "yyyyMMdd-HHmmss-fff"
        $dir = Join-Path $RunsRoot $id
        New-Item -ItemType Directory -Force -Path (Join-Path $dir "Configs") | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $dir "queue") | Out-Null
        $port = 25556
        while (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { $port++ }
        @{
            Name = "verify-$id"
            Description = "verification instance $id"
            DiscordURL = ""
            SteamWorkshopURL = ""
            ServerImageURL = ""
            IP = "127.0.0.1"
            Port = $port
            MaxPlayers = 8
            Verbosity = 0
            DisplayChatInConsole = $false
            UseUPnP = $false
            UseClientSave = $false
            EnableServerBrowser = $false
            EnableServerTelemetry = $false
        } | ConvertTo-Json | Set-Content -Path (Join-Path $dir "Configs\ServerConfig.json") -Encoding utf8
        $meta = [ordered]@{
            id = $id
            pid = 0
            supervisorPid = 0
            port = $port
            dataDir = $dir
            dll = $Dll
            version = "26.11.2.1"
            hotfix = 5
        }
        $meta | ConvertTo-Json | Set-Content -Path (Join-Path $dir "instance.json") -Encoding utf8
        $sup = Start-Process -FilePath "powershell.exe" -WindowStyle Hidden -PassThru -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Supervisor,
            "-DataDir", $dir, "-Dotnet", $dotnet, "-Dll", $Dll
        )
        $meta.supervisorPid = $sup.Id
        $meta | ConvertTo-Json | Set-Content -Path (Join-Path $dir "instance.json") -Encoding utf8
        Set-Content -Path $CurrentFile -Value $id -Encoding ascii
        $log = Get-SystemLog $dir
        Wait-ForLog $log "Type 'help' to get a list of available commands" $TimeoutSec 0 | Out-Null
        $pidFile = Join-Path $dir "pid.txt"
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        while (-not (Test-Path $pidFile) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
        if (-not (Test-Path $pidFile)) { throw "Supervisor did not record the server pid." }
        $serverPid = [int](Get-Content $pidFile -Raw).Trim()
        $meta.pid = $serverPid
        $meta | ConvertTo-Json | Set-Content -Path (Join-Path $dir "instance.json") -Encoding utf8
        Write-Output "launched id=$id pid=$serverPid port=$port data=$dir"
    }
    "doctor" {
        $inst = Get-Instance
        $meta = Get-Content $inst.MetaPath -Raw | ConvertFrom-Json
        if (-not (Test-ProcessAlive ([int]$meta.pid))) { throw "Server pid $($meta.pid) is not running." }
        if (-not (Test-ProcessAlive ([int]$meta.supervisorPid))) { throw "Supervisor pid $($meta.supervisorPid) is not running." }
        $listen = Get-NetTCPConnection -LocalPort ([int]$meta.port) -State Listen -ErrorAction SilentlyContinue |
            Where-Object { $_.OwningProcess -eq [int]$meta.pid }
        if (-not $listen) { throw "Port $($meta.port) is not owned by pid $($meta.pid)." }
        $log = Get-SystemLog $inst.Dir
        if (-not (Test-Path $log)) { throw "System log is missing: $log" }
        $text = Get-Content $log -Raw
        $listenLine = "Listening for users at 127.0.0.1:$($meta.port)"
        if ($text -notlike "*$listenLine*") { throw "Log does not contain '$listenLine'." }
        if ($text -notlike "*Server version 26.11.2.1 (5)*") { throw "Log does not contain server version 26.11.2.1 (5)." }
        if ($meta.dataDir -ne $inst.Dir) { throw "Data dir mismatch." }
        Write-Output "doctor ok id=$($inst.Id) pid=$($meta.pid) port=$($meta.port)"
    }
    "send" {
        if ([string]::IsNullOrWhiteSpace($CommandText)) { throw "send requires the console command as the next argument." }
        $inst = Get-Instance
        $meta = Get-Content $inst.MetaPath -Raw | ConvertFrom-Json
        if (-not (Test-ProcessAlive ([int]$meta.pid))) { throw "Server pid $($meta.pid) is not running." }
        $log = Get-SystemLog $inst.Dir
        $start = Log-Length $log
        $stamp = Get-Date -Format "yyyyMMddHHmmssfff"
        $queueFile = Join-Path $inst.Dir "queue\$stamp.cmd"
        Set-Content -Path $queueFile -Value $CommandText -Encoding ascii
        if ($Expect) {
            Wait-ForLog $log $Expect $TimeoutSec $start | Out-Null
        } else {
            $deadline = (Get-Date).AddSeconds($TimeoutSec)
            while ((Test-Path $queueFile) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
            if (Test-Path $queueFile) { throw "Supervisor did not consume $queueFile." }
        }
        Write-Output "sent: $CommandText"
    }
    "evidence" {
        $inst = Get-Instance
        $dest = Join-Path $EvidenceRoot "$($inst.Id)\$Feature"
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        $log = Get-SystemLog $inst.Dir
        if (Test-Path $log) { Copy-Item $log (Join-Path $dest "system-log.txt") -Force }
        $stdout = Join-Path $inst.Dir "stdout.txt"
        if (Test-Path $stdout) { Copy-Item $stdout (Join-Path $dest "stdout.txt") -Force }
        $password = Join-Path $inst.Dir "Configs\PasswordConfig.json"
        if (Test-Path $password) { Copy-Item $password (Join-Path $dest "PasswordConfig.json") -Force }
        $chatDay = Get-Date -Format "yyyy-MM-dd"
        $chat = Join-Path $inst.Dir "Logs\Chat\$chatDay.txt"
        if (Test-Path $chat) { Copy-Item $chat (Join-Path $dest "chat-log.txt") -Force }
        Set-Content -Path (Join-Path $dest "feature.txt") -Value $Feature -Encoding ascii
        Write-Output "evidence $dest"
    }
    "cleanup" {
        if (-not (Test-Path $CurrentFile)) { Write-Output "nothing to clean"; break }
        $inst = Get-Instance
        $meta = Get-Content $inst.MetaPath -Raw | ConvertFrom-Json
        if (Test-ProcessAlive ([int]$meta.pid)) {
            $stamp = Get-Date -Format "yyyyMMddHHmmssfff"
            Set-Content -Path (Join-Path $inst.Dir "queue\$stamp.cmd") -Value "quit" -Encoding ascii
            $deadline = (Get-Date).AddSeconds($TimeoutSec)
            while ((Test-ProcessAlive ([int]$meta.pid)) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
            if (Test-ProcessAlive ([int]$meta.pid)) { Stop-Process -Id ([int]$meta.pid) -Force }
        }
        if (Test-ProcessAlive ([int]$meta.supervisorPid)) { Stop-Process -Id ([int]$meta.supervisorPid) -Force }
        Remove-Item -Path $CurrentFile -Force -ErrorAction SilentlyContinue
        if (Test-Path $inst.Dir) { Remove-Item -Path $inst.Dir -Recurse -Force }
        Write-Output "cleaned $($inst.Id)"
    }
}
