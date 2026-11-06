param(
    [Parameter(Mandatory = $true)]
    [string]$BasFile,
    [string]$PrgName
)
if ([System.IO.Path]::GetExtension($BasFile) -ne '.bas') {
    Write-Host 'Open a .bas file in the editor, then run Build.'
    exit 1
}

. (Join-Path $PSScriptRoot 'machine.ps1')
# the file name picks the machine: name-c64.bas is a C64 program, anything else a VIC-20 one
$machine = Get-MachineForFile $BasFile
$emulator = $machine.Emulator
$port = $machine.Port

if (-not $PrgName) {
    $PrgName = [System.IO.Path]::GetFileNameWithoutExtension($BasFile)
}

$root = Split-Path -Parent $PSScriptRoot
$reposDir = Split-Path -Parent $root
$prgs = Join-Path $root 'prgs'
New-Item -ItemType Directory -Force -Path $prgs | Out-Null
$prg = Join-Path $prgs $PrgName

# warnings only; the build goes ahead either way
& (Join-Path $PSScriptRoot 'check-basic.ps1') -BasFile $BasFile

& petcat.exe -w2 -l $machine.LoadAddress -o $prg $BasFile
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# a shared folder next to the repo (opt-in: create it to use it) collects every repo's newest build
# for that machine (prgs-latest for the VIC-20, sd-c64 for the C64), and the emulator autostarts from
# there, so drive 8 holds the programs side by side and they can load each other.
$shared = Join-Path $reposDir $machine.Shared
if (Test-Path -PathType Container $shared) {
    Copy-Item -Force $prg $shared
    $prg = Join-Path $shared $PrgName
}

# sends one monitor command and waits for a reply matching $expect; a wedged monitor accepts the connection
# but never answers, so this returns $false after 2 seconds. Always reads the reply before closing.
function Send-ViceCommand([string]$command, [string]$expect) {
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect('127.0.0.1', $port)
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
    # autostart through the virtual filesystem, so drive 8 is the PRG's folder and a program can
    # load another one from it (the launcher handoff). Other modes give drive 8 a one-file disk.
    [void](Send-ViceCommand 'resourceset "AutostartPrgMode" "0"' '\(C:')
    Start-Sleep -Milliseconds 300
    $unix = $prgPath -replace '\\', '/'
    return Send-ViceCommand "autostart `"$unix`"" 'autostarting'
}

if (Try-ViceAutostart $prg) {
    Write-Host "Autostarted in running ${emulator}: $prg"
    exit 0
}

$stale = Get-Process -Name $emulator -ErrorAction SilentlyContinue
if ($stale) {
    Write-Host "$emulator remote monitor did not respond on 127.0.0.1:${port}; restarting $emulator."
    $stale | Stop-Process -Force
    $stale | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
}

# each machine's monitor has its own port, so a VIC-20 and a C64 can run side by side
$arguments = $machine.Args + @('-remotemonitor', '-remotemonitoraddress', "ip4://127.0.0.1:$port") +
    (Get-NetMockArgs $reposDir) + @('-autostartprgmode', '0', '-autostart', $prg)
Start-Process "$emulator.exe" -ArgumentList $arguments
Write-Host "Started $emulator with remote monitor on port ${port}: $prg"
