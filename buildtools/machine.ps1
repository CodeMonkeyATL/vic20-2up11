# the target machines the build tools know, dot-sourced by the other scripts. One switch picks
# everything that differs between machines; add a machine here and the rest of the tools follow.
#   Emulator     VICE's program for it
#   Port         the emulator's remote monitor port, different per machine so both can run at once
#   LoadAddress  where BASIC programs start (petcat -l, in hex)
#   MaxListed    longest line the screen editor can edit, as listed (4 rows of 22 on a VIC, 2 of 40 on a C64)
#   Shared       folder next to the repos (opt-in) that collects each build and is the emulator's drive 8
#   Args         emulator options for a fresh start
# drive 8 as a folder on the PC (the virtual filesystem): no true drive emulation, and the kernal traps on.
# Given on every start, so the tools don't depend on settings VICE saved from an earlier session.
$DriveArgs = @('+drive8truedrive', '-trapdevice8')

function Get-Machine([string]$name) {
    switch ($name) {
        'c64' {
            return @{ Name = 'c64'; Emulator = 'x64sc'; Port = 6511; LoadAddress = '0801'; MaxListed = 80
                      Shared = 'sd-c64'; Args = @('-keymap', '0') + $DriveArgs }
        }
        default {
            return @{ Name = 'vic20'; Emulator = 'xvic'; Port = 6510; LoadAddress = '1001'; MaxListed = 88
                      Shared = 'prgs-latest'; Args = @('-memory', 'none', '-keymap', '0') + $DriveArgs }
        }
    }
}

# a source file's machine comes from its name, the same suffixes as the CI workflow: name-c64.bas is
# a C64 program, anything else a VIC-20 one
function Get-MachineForFile([string]$basFile) {
    if ([System.IO.Path]::GetFileNameWithoutExtension($basFile) -match '-c64$') {
        return Get-Machine 'c64'
    }
    return Get-Machine 'vic20'
}

# a net-mock folder next to the repos (opt-in) becomes drive 9 on every emulator the tools start,
# so a VIC-20 and a C64 running side by side share it: the mock network between them
function Get-NetMockArgs([string]$reposDir) {
    $netMock = Join-Path $reposDir 'net-mock'
    if (Test-Path -PathType Container $netMock) {
        return @('+drive9truedrive', '-trapdevice9', '-fs9', $netMock)
    }
    return @()
}
