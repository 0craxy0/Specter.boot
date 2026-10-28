[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '.')
)

$ErrorActionPreference = 'Stop'

function Add-Issue {
    param([string]$File, [string]$Message)
    $script:Issues += [pscustomobject]@{ File = $File; Message = $Message }
}

function Test-BalancedDelimiters {
    param([string]$Text)

    $stack = [System.Collections.Generic.Stack[char]]::new()
    $pairs = @{ ')' = '('; ']' = '['; '}' = '{' }
    $quote = $null
    $lineComment = $false
    $blockComment = $false
    $escaped = $false

    for ($i = 0; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        $next = if ($i + 1 -lt $Text.Length) { $Text[$i + 1] } else { [char]0 }

        if ($lineComment) {
            if ($c -eq "`n") { $lineComment = $false }
            continue
        }
        if ($blockComment) {
            if ($c -eq ']' -and $next -eq ']') { $blockComment = $false; $i++ }
            continue
        }
        if ($quote) {
            if ($escaped) { $escaped = $false; continue }
            if ($c -eq '\') { $escaped = $true; continue }
            if ($c -eq $quote) { $quote = $null }
            continue
        }
        if ($c -eq '-' -and $next -eq '-') {
            if ($i + 3 -lt $Text.Length -and $Text.Substring($i, 4) -eq '--[[') { $blockComment = $true; $i += 3 }
            else { $lineComment = $true; $i++ }
            continue
        }
        if ($c -eq '"' -or $c -eq "'") { $quote = $c; continue }
        if ($c -eq '(' -or $c -eq '[' -or $c -eq '{') { $stack.Push($c); continue }
        if ($pairs.ContainsKey([string]$c)) {
            if ($stack.Count -eq 0 -or $stack.Pop() -ne $pairs[[string]$c]) { return "unexpected closing delimiter '$c'" }
        }
    }

    if ($quote) { return "unterminated string literal" }
    if ($blockComment) { return "unterminated block comment" }
    if ($stack.Count -gt 0) { return "unclosed delimiter '$($stack.Peek())'" }
    return $null
}

$script:Issues = @()
$resolvedRoot = (Resolve-Path -LiteralPath $Root -ErrorAction SilentlyContinue)
if (-not $resolvedRoot -or -not (Test-Path -LiteralPath $resolvedRoot.Path -PathType Container)) {
    Write-Error "Specter validation root does not exist: $Root"
    exit 1
}

$files = @(Get-ChildItem -LiteralPath $resolvedRoot.Path -Recurse -File -Include '*.luau', '*.lua' | Sort-Object FullName)
Write-Output "Specter Luau static validation"
Write-Output "Root: $($resolvedRoot.Path)"
Write-Output "Files discovered: $($files.Count)"

if ($files.Count -eq 0) { Add-Issue '<root>' 'no Specter .luau or .lua hub/catalog files found' }

$requiredSymbols = @('WindUI', 'CreateWindow', ':Tab')
$combined = ''
foreach ($file in $files) {
    $relative = $file.FullName.Substring($resolvedRoot.Path.Length).TrimStart('\')
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $combined += "`n$text"
    $delimiterIssue = Test-BalancedDelimiters $text
    if ($delimiterIssue) { Add-Issue $relative $delimiterIssue }
    $dangerous = @(
        '\b(?:os\.remove|os\.rename|delfile|delfolder|rmdir|writefile|appendfile)\s*\(',
        '\b(?:Shutdown|Kick|FireServer|InvokeServer)\s*\('
    )
    foreach ($pattern in $dangerous) {
        $match = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) { Add-Issue $relative "possible destructive call: $($match.Value)" }
    }
    Write-Output "[OK] scanned $relative"
}

foreach ($symbol in $requiredSymbols) {
    if ($combined -notmatch "\b$([regex]::Escape($symbol))\b") { Add-Issue '<catalog>' "required WindUI symbol missing: $symbol" }
}

if ($Issues.Count -gt 0) {
    Write-Output ""
    Write-Output "SPECTER VALIDATION FAILED ($($Issues.Count) issue(s))"
    foreach ($issue in $Issues) { Write-Output "[FAIL] $($issue.File): $($issue.Message)" }
    exit 1
}

Write-Output ""
Write-Output "SPECTER VALIDATION PASSED"
exit 0
