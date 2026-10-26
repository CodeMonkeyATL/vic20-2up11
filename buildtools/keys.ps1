param(
    [Parameter(Mandatory = $true)]
    [string]$Keys
)

# types keys into the running xvic (remote monitor on 127.0.0.1:6510) via the monitor's keybuf command
$client = New-Object System.Net.Sockets.TcpClient
try {
    $client.Connect('127.0.0.1', 6510)
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
    Write-Host 'Could not reach the xvic remote monitor on 127.0.0.1:6510. Is xvic running?'
    exit 1
} finally {
    $client.Close()
}

if (-not $reply) {
    Write-Host 'xvic did not answer; the remote monitor may be wedged.'
    exit 1
}

Write-Host "Typed into xvic: $Keys"
