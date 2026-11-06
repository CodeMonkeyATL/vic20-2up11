param(
    [Parameter(Mandatory = $true)]
    [string]$Keys,
    # vic20 (xvic, the default) or c64 (x64sc); see machine.ps1
    [string]$Machine = 'vic20'
)

. (Join-Path $PSScriptRoot 'machine.ps1')
$m = Get-Machine $Machine
$emulator = $m.Emulator
$port = $m.Port

# types keys into the running emulator (remote monitor on 127.0.0.1, the machine's port) via the monitor's keybuf command
$client = New-Object System.Net.Sockets.TcpClient
try {
    $client.Connect('127.0.0.1', $port)
    $stream = $client.GetStream()
    # don't send "x" -- exiting the monitor before disconnecting wedges VICE's remote monitor
    # keybuf types its argument literally, so quotes would be typed too; \n types Return
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("keybuf $Keys`n")
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()

    # drain the monitor's reply before closing; closing with unread data resets the socket and can wedge VICE
    $buffer = New-Object byte[] 4096
    $reply = ''
    $quiet = [DateTime]::Now.AddMilliseconds(500)
    while ([DateTime]::Now -lt $quiet) {
        if ($stream.DataAvailable) {
            $count = $stream.Read($buffer, 0, $buffer.Length)
            $reply += [System.Text.Encoding]::ASCII.GetString($buffer, 0, $count)
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

if (-not $reply) {
    Write-Host "$emulator did not answer; the remote monitor may be wedged."
    exit 1
}

Write-Host "Typed into ${emulator}: $Keys"
