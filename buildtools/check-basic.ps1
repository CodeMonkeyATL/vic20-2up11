param(
    [Parameter(Mandatory = $true)]
    [string]$BasFile
)

# checks a petcat source file against the BASIC guidelines (meta repo, docs/basic-guidelines.md) and prints warnings;
# it never fails the build, so it always exits 0
$maxListed = 88

# splits a line's text into its code part (strings and rem text removed) and whether it has a rem
function Split-Code([string]$text) {
    $code = New-Object System.Text.StringBuilder
    $inQuote = $false
    for ($i = 0; $i -lt $text.Length; $i++) {
        $ch = $text[$i]
        if ($ch -eq '"') {
            $inQuote = -not $inQuote
            continue
        }
        if ($inQuote) {
            continue
        }
        # BASIC tokenizes "rem" anywhere outside a string, and the rest of the line is comment
        if ($i + 3 -le $text.Length -and $text.Substring($i, 3) -eq 'rem') {
            break
        }
        [void]$code.Append($ch)
    }
    return $code.ToString()
}

$warnings = New-Object System.Collections.Generic.List[string]
function Warn([int]$srcLine, [string]$label, [string]$message) {
    $warnings.Add(("{0}:{1}: line {2}: {3}" -f (Split-Path -Leaf $BasFile), $srcLine, $label, $message))
}

$lines = [System.IO.File]::ReadAllLines($BasFile)
$numbers = @{}
$targets = New-Object System.Collections.Generic.List[object]
$previous = -1

for ($n = 0; $n -lt $lines.Length; $n++) {
    $srcLine = $n + 1
    $raw = $lines[$n]
    if ($raw.Trim() -eq '') {
        continue
    }

    if ($raw -match '^\s*(\d+)\s?(.*)$') {
        $number = [int]$Matches[1]
        $text = $Matches[2]
    } else {
        # petcat numbers an unnumbered line as the previous line + 2
        $number = $previous + 2
        $text = $raw.Trim()
        Warn $srcLine $number 'unnumbered line; petcat numbers it previous + 2'
    }
    $label = [string]$number

    if ($numbers.ContainsKey($number)) {
        Warn $srcLine $label ("duplicate line number (also source line {0}); petcat keeps both, but the VIC editor can't" -f $numbers[$number])
    } elseif ($number -le $previous) {
        Warn $srcLine $label ("line number not above the previous line ({0})" -f $previous)
    }
    $numbers[$number] = $srcLine
    $previous = $number

    # the VIC lists "<number> <text>", with each petcat {code} as one character
    $listed = $label.Length + 1 + ($text -replace '\{[^}]*\}', 'x').Length
    if ($listed -gt $maxListed) {
        Warn $srcLine $label ("{0} characters as listed (limit {1})" -f $listed, $maxListed)
    }

    $code = Split-Code $text
    $spaces = ($code.ToCharArray() | Where-Object { $_ -eq ' ' }).Count
    if ($spaces -gt 0) {
        Warn $srcLine $label ("{0} space(s) outside strings" -f $spaces)
    }

    # goto/gosub/then targets, including "on x goto a,b,c" lists
    foreach ($m in [regex]::Matches($code, '(goto|gosub|then)\s*(\d+(\s*,\s*\d+)*)')) {
        foreach ($t in ($m.Groups[2].Value -split ',')) {
            $targets.Add([pscustomobject]@{ Target = [int]$t.Trim(); SrcLine = $srcLine; Label = $label })
        }
    }
}

foreach ($t in $targets) {
    if (-not $numbers.ContainsKey($t.Target)) {
        Warn $t.SrcLine $t.Label ("jumps to line {0}, which doesn't exist" -f $t.Target)
    }
}

foreach ($w in $warnings) {
    Write-Host "warning: $w"
}
Write-Host ("check-basic: {0} warning(s) in {1}" -f $warnings.Count, (Split-Path -Leaf $BasFile))
exit 0
