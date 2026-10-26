param(
    [Parameter(Mandatory = $true)]
    [string]$BasFile,
    [string]$PrgName
)
if ([System.IO.Path]::GetExtension($BasFile) -ne '.bas') {
    Write-Host 'Open a .bas file in the editor, then run Build.'
    exit 1
}

if (-not $PrgName) {
    $PrgName = [System.IO.Path]::GetFileNameWithoutExtension($BasFile)
}

$root = Split-Path -Parent $PSScriptRoot
$prgs = Join-Path $root 'prgs'
New-Item -ItemType Directory -Force -Path $prgs | Out-Null
$prg = Join-Path $prgs $PrgName

# warnings only; the build goes ahead either way
& (Join-Path $PSScriptRoot 'check-basic.ps1') -BasFile $BasFile

& petcat.exe -w2 -l 1001 -o $prg $BasFile
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# sends one monitor command and waits for a reply matching $expect; a wedged monitor accepts the connection
# but never answers, so this returns $false after 2 seconds. Always reads the reply before closing.
function Send-ViceCommand([string]$command, [string]$expect) {
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect('127.0.0.1', 6510)
        $stream = $client.GetStream()
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("$command`n")
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()

        $reply = ''
        $buffer = New-Object byte[] 4096
        $deadline = [DateTime]::Now.AddSeconds(2)
        while ([DateTime]::Now -lt $deadline -and $reply -notmatch $expect) {
            if ($stream.DataAvailable) {
                $count = $stream.Read($buffer, 0, $buffer.Length)
                $reply += [System.Text.Encoding]::ASCII.GetString($buffer, 0, $count)
            } else {
                Start-Sleep -Milliseconds 50
            }
        }
        return $reply -match $expect
    } catch {
        return $false
    } finally {
        if ($client) {
            $client.Close()
        }
    }
}

function Try-ViceAutostart([string]$prgPath) {
    # autostart re-types the last monitor keybuf string (e.g. from keys.ps1) after RUN, so a test's old keys
    # would reach the new program. Replace that string with one "z" first; the program's own flush drops it.
    # keybuf and autostart must go out on separate connections: sent together, the monitor wedges.
    if (Send-ViceCommand 'keybuf z' '\(C:') {
        Start-Sleep -Milliseconds 300
    }
    $unix = $prgPath -replace '\\', '/'
    return Send-ViceCommand "autostart `"$unix`"" 'autostarting'
}

if (Try-ViceAutostart $prg) {
    Write-Host "Autostarted in running xvic: $prg"
    exit 0
}

$stale = Get-Process -Name xvic -ErrorAction SilentlyContinue
if ($stale) {
    Write-Host 'xvic remote monitor did not respond on 127.0.0.1:6510; restarting xvic.'
    $stale | Stop-Process -Force
    $stale | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
}

Start-Process xvic.exe -ArgumentList '-memory', 'none', '-keymap', '0', '-remotemonitor', '-autostart', $prg
Write-Host "Started xvic with remote monitor: $prg"
