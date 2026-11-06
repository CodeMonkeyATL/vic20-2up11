param(
    [string]$OutFile,
    # vic20 (xvic, the default) or c64 (x64sc); see machine.ps1
    [string]$Machine = 'vic20'
)

. (Join-Path $PSScriptRoot 'machine.ps1')
$m = Get-Machine $Machine
$emulator = $m.Emulator
$port = $m.Port

# asks the running emulator (remote monitor on 127.0.0.1, the machine's port) to save its screen as a PNG
if (-not $OutFile) {
    $root = Split-Path -Parent $PSScriptRoot
    $tempDir = Join-Path $root 'screenshots\temp'
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    $OutFile = Join-Path $tempDir ("$emulator-{0}.png" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$OutFile = [System.IO.Path]::GetFullPath($OutFile)
Remove-Item $OutFile -ErrorAction SilentlyContinue

$client = New-Object System.Net.Sockets.TcpClient
try {
    $client.Connect('127.0.0.1', $port)
    $stream = $client.GetStream()
    $unix = $OutFile -replace '\\', '/'
    # format 2 = PNG; don't send "x" -- exiting the monitor before disconnecting wedges VICE's remote monitor
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("screenshot `"$unix`" 2`n")
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()

    $deadline = [DateTime]::Now.AddSeconds(3)
    while ([DateTime]::Now -lt $deadline -and -not (Test-Path $OutFile)) {
        Start-Sleep -Milliseconds 100
    }

    # drain the monitor's reply before closing; closing with unread data resets the socket and can wedge VICE
    $buffer = New-Object byte[] 4096
    $quiet = [DateTime]::Now.AddMilliseconds(300)
    while ([DateTime]::Now -lt $quiet) {
        if ($stream.DataAvailable) {
            [void]$stream.Read($buffer, 0, $buffer.Length)
            $quiet = [DateTime]::Now.AddMilliseconds(300)
        } else {
            Start-Sleep -Milliseconds 50
        }
    }
} catch {
    Write-Host "Could not reach the $emulator remote monitor on 127.0.0.1:$port. Is $emulator running?"
    exit 1
} finally {
    $client.Close()
}

if (-not (Test-Path $OutFile)) {
    Write-Host "$emulator did not write a screenshot."
    exit 1
}

Write-Host "Screenshot saved: $OutFile"
