
$file = "index.html"
$c = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)

# Replace common garbage patterns with clean characters
# (Using hex codes to avoid script encoding issues)
# â”€ -> ─ (U+2500)
$c = $c -replace [char]0xE2 + [char]0x80 + [char]0x94, [char]0x2014
$c = $c -replace [char]0xE2 + [char]0x94 + [char]0x24, [char]0x2500

# Fix the HistoryPanel buttons
$oldBtns = '<Btn onClick={() => setConfirmDeleteId(e.id)} color={C.danger} style={{ fontSize: 11, padding: "6px 12px" }}>'
$newBtns = '<Btn onClick={() => onEdit && onEdit(e)} color={C.amber} style={{ fontSize: 11, padding: "6px 12px" }}>✏ Editar</Btn>' + "`r`n                      <Btn onClick={() => setConfirmDeleteId(e.id)} color={C.danger} style={{ fontSize: 11, padding: \"6px 12px\" }}>"

if ($c.Contains($oldBtns) -and -not $c.Contains("onEdit(e)")) {
    $c = $c.Replace($oldBtns, $newBtns)
}

# Final encoding cleanup - replace some common misinterpretations
# This is a bit aggressive but helps when things get messy
$c = $c.Replace("âœ ", "✏")
$c = $c.Replace("ðŸ“‹", "📋")
$c = $c.Replace("ðŸ“…", "📅")
$c = $c.Replace("ðŸ“Š", "📊")
$c = $c.Replace("âš™", "⚙")
$c = $c.Replace("ðŸ”¬", "🔬")

# Re-save as UTF8 with BOM
$utf8bom = New-Object System.Text.Utf8Encoding($true)
[System.IO.File]::WriteAllText($file, $c, $utf8bom)
Write-Host "Success"
