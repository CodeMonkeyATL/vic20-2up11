param(
    [Parameter(Mandatory = $true)]
    [string]$BasFile
)

# checks a petcat source file against the BASIC guidelines (meta repo, docs/basic-guidelines.md) and prints warnings;
# it never fails the build, so it always exits 0
# the longest editable line depends on the machine, which the file name picks (see machine.ps1)
. (Join-Path $PSScriptRoot 'machine.ps1')
$maxListed = (Get-MachineForFile $BasFile).MaxListed

# BASIC V2 keywords in token order ($80 upward); the tokenizer takes the first one in this order that matches
# at the current position, so input# is tried before input, and go (last) only when goto doesn't match
$keywords = @(
    'end', 'for', 'next', 'data', 'input#', 'input', 'dim', 'read', 'let', 'goto', 'run', 'if', 'restore', 'gosub',
    'return', 'rem', 'stop', 'on', 'wait', 'load', 'save', 'verify', 'def', 'poke', 'print#', 'print', 'cont', 'list',
    'clr', 'cmd', 'sys', 'open', 'close', 'get', 'new', 'tab(', 'to', 'fn', 'spc(', 'then', 'not', 'step',
    '+', '-', '*', '/', '^', 'and', 'or', '>', '=', '<',
    'sgn', 'int', 'abs', 'usr', 'fre', 'pos', 'sqr', 'rnd', 'log', 'exp', 'cos', 'sin', 'tan', 'atn', 'peek', 'len',
    'str$', 'val', 'asc', 'chr$', 'left$', 'right$', 'mid$', 'go'
)
# keywords that begin a statement, and functions, which must be followed by "("
$statementWords = @('end', 'for', 'next', 'data', 'input#', 'input', 'dim', 'read', 'let', 'goto', 'run', 'if',
    'restore', 'gosub', 'return', 'rem', 'stop', 'on', 'wait', 'load', 'save', 'verify', 'def', 'poke', 'print#',
    'print', 'cont', 'list', 'clr', 'cmd', 'sys', 'open', 'close', 'get', 'new', 'go')
$functionWords = @('sgn', 'int', 'abs', 'usr', 'fre', 'pos', 'sqr', 'rnd', 'log', 'exp', 'cos', 'sin', 'tan', 'atn',
    'peek', 'len', 'str$', 'val', 'asc', 'chr$', 'left$', 'right$', 'mid$')

# splits a line's text the way petcat and the VIC tokenize it: keywords (kw), other characters (ch),
# strings (str, with quotes), and the text after rem or data, which isn't tokenized (rem, data; data runs to ":")
function Get-Tokens([string]$text) {
    $tokens = New-Object System.Collections.Generic.List[object]
    $lower = $text.ToLowerInvariant()
    $i = 0
    while ($i -lt $text.Length) {
        $ch = $text[$i]
        if ($ch -eq '"') {
            $end = $text.IndexOf('"', $i + 1)
            if ($end -lt 0) { $end = $text.Length - 1 }
            $tokens.Add([pscustomobject]@{ Type = 'str'; Text = $text.Substring($i, $end - $i + 1); Pos = $i })
            $i = $end + 1
            continue
        }
        if ($ch -eq '{') {
            # a petcat {code} outside a string is one character
            $end = $text.IndexOf('}', $i)
            if ($end -lt 0) { $end = $text.Length - 1 }
            $tokens.Add([pscustomobject]@{ Type = 'ch'; Text = $text.Substring($i, $end - $i + 1); Pos = $i })
            $i = $end + 1
            continue
        }
        $kw = $null
        foreach ($k in $keywords) {
            if ($i + $k.Length -le $lower.Length -and $lower.Substring($i, $k.Length) -eq $k) {
                $kw = $k
                break
            }
        }
        if ($null -eq $kw) {
            $tokens.Add([pscustomobject]@{ Type = 'ch'; Text = [string]$ch; Pos = $i })
            $i++
            continue
        }
        $tokens.Add([pscustomobject]@{ Type = 'kw'; Text = $kw; Pos = $i })
        $i += $kw.Length
        if ($kw -eq 'rem') {
            if ($i -lt $text.Length) {
                $tokens.Add([pscustomobject]@{ Type = 'rem'; Text = $text.Substring($i); Pos = $i })
            }
            break
        }
        if ($kw -eq 'data') {
            # data items stay as typed up to the next ":" outside quotes
            $start = $i
            $inQuote = $false
            while ($i -lt $text.Length -and ($inQuote -or $text[$i] -ne ':')) {
                if ($text[$i] -eq '"') { $inQuote = -not $inQuote }
                $i++
            }
            if ($i -gt $start) {
                $tokens.Add([pscustomobject]@{ Type = 'data'; Text = $text.Substring($start, $i - $start); Pos = $start })
            }
        }
    }
    return , $tokens
}

# finds keywords that ended up where no keyword belongs, the sign that a variable name ran into a keyword
# (tand7 is TAN d7, fori=stop has STOP, x=pto9 has TO); returns one message per problem
function Find-KeywordProblems($tokens, [string]$text) {
    $problems = New-Object System.Collections.Generic.List[string]
    $atStart = $true      # the next token begins a statement
    $statement = ''       # the statement's first keyword
    $seenIf = $false
    $seenOn = $false
    for ($t = 0; $t -lt $tokens.Count; $t++) {
        $tok = $tokens[$t]
        $next = if ($t + 1 -lt $tokens.Count) { $tokens[$t + 1] } else { $null }
        if ($tok.Type -eq 'ch' -and $tok.Text -eq ':') {
            $atStart = $true
            $statement = ''
            $seenIf = $false
            $seenOn = $false
            continue
        }
        if ($tok.Type -eq 'ch' -and $tok.Text -eq '?') {
            $problems.Add("'?' outside a string: petcat doesn't turn it into print, so the VIC sees a plain '?'; write print")
        }
        if ($tok.Type -ne 'kw') {
            $atStart = $false
            continue
        }
        $kw = $tok.Text
        # the source around the keyword, to show where it came from
        $from = [Math]::Max(0, $tok.Pos - 4)
        $context = $text.Substring($from, [Math]::Min($text.Length, $tok.Pos + $kw.Length + 4) - $from)
        $name = $kw.ToUpperInvariant()

        if ($statementWords -contains $kw) {
            # goto/gosub/go may follow "if x" or "on x"; any other statement keyword must start a statement
            $allowed = $atStart -or (($kw -in @('goto', 'gosub', 'go')) -and ($seenIf -or $seenOn))
            if (-not $allowed) {
                $problems.Add("$name inside a statement ('$context'); a name probably ran into a keyword")
            }
            if ($atStart) { $statement = $kw }
            if ($kw -eq 'go' -and -not ($null -ne $next -and $next.Type -eq 'kw' -and $next.Text -eq 'to')) {
                $problems.Add("GO not followed by to ('$context'); a name probably ran into a keyword")
            }
        } elseif ($functionWords -contains $kw) {
            if (-not ($null -ne $next -and $next.Type -eq 'ch' -and $next.Text -eq '(')) {
                $problems.Add("$name not followed by '(' ('$context'); a name probably ran into a keyword")
            }
        } elseif ($kw -eq 'to' -and $statement -ne 'for' -and -not ($t -gt 0 -and $tokens[$t - 1].Text -eq 'go')) {
            $problems.Add("TO outside a for statement ('$context'); a name probably ran into a keyword")
        } elseif ($kw -eq 'step' -and $statement -ne 'for') {
            $problems.Add("STEP outside a for statement ('$context'); a name probably ran into a keyword")
        } elseif ($kw -eq 'then' -and -not $seenIf) {
            $problems.Add("THEN without if ('$context'); a name probably ran into a keyword")
        } elseif ($kw -eq 'fn' -and -not ($null -ne $next -and $next.Type -eq 'ch' -and $next.Text -match '^[a-z]$')) {
            $problems.Add("FN not followed by a function name ('$context'); a name probably ran into a keyword")
        }

        if ($kw -eq 'if') { $seenIf = $true }
        if ($kw -eq 'on') { $seenOn = $true }
        if ($kw -eq 'then') {
            # what follows then is a new statement (or a line number)
            $atStart = $true
            $statement = ''
            $seenIf = $false
            $seenOn = $false
            continue
        }
        $atStart = $false
    }
    return , $problems
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

    $tokens = Get-Tokens $text
    foreach ($p in (Find-KeywordProblems $tokens $text)) {
        Warn $srcLine $label $p
    }

    # the code part: strings and rem text removed
    $code = -join ($tokens | Where-Object { $_.Type -in @('kw', 'ch', 'data') } | ForEach-Object { $_.Text })
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
