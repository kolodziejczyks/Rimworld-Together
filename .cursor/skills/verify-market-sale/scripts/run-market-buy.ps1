$ErrorActionPreference = "Stop"
$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RepoRoot = (Resolve-Path (Join-Path $SkillRoot "..\..\..")).Path
$LocalJava = Join-Path $RepoRoot ".verify-tools\java\jdk-17.0.21+9-jre\bin\java.exe"
$Jar = Join-Path $RepoRoot ".verify-tools\tla\tla2tools.jar"
if (Test-Path $LocalJava) { $java = $LocalJava }
else {
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "Java 17+ is required. A portable JRE belongs at $LocalJava." }
    $java = $cmd.Source
}
if (-not (Test-Path $Jar)) {
    throw "Missing $Jar. Download https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar to that path."
}
$outDir = Join-Path $SkillRoot "runs"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outFile = Join-Path $outDir "tlc-$stamp.txt"
& $java "-XX:+UseParallelGC" -jar $Jar -deadlock -nowarning -workers 1 -config (Join-Path $SkillRoot "MarketBuy.cfg") (Join-Path $SkillRoot "MarketBuy.tla") 2>&1 |
    Tee-Object -FilePath $outFile
Remove-Item (Join-Path $SkillRoot "MarketBuy_TTrace_*") -Force -ErrorAction SilentlyContinue
$code = $LASTEXITCODE
Write-Output "tlc-exit=$code"
Write-Output "tlc-output=$outFile"
exit $code
