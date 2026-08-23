$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$draftDir = Join-Path $repoRoot 'wuxia-novels/40_generation/章节草稿'
$worldDir = Join-Path $repoRoot 'wuxia-novels/10_worldbuilding'

$elementFiles = @(
  '元素-人物.md',
  '元素-门派.md',
  '元素-武学.md',
  '元素-兵器.md',
  '元素-丹药.md',
  '元素-地图.md',
  '元素-服装.md',
  '元素-道具.md',
  '元素-音乐.md'
)

function Get-ElementSummary {
  param([string]$filePath)

  $lines = Get-Content -Path $filePath -Encoding UTF8
  foreach ($raw in $lines) {
    $line = $raw.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.StartsWith('#')) { continue }
    if ($line.StartsWith('|')) { continue }
    if ($line -match '^>') { continue }

    $line = $line -replace '^[\-\*]\s*', ''
    if ($line.Length -gt 40) {
      return $line.Substring(0, 40) + '...'
    }
    return $line
  }

  return '见源文件定义。'
}

function Clip-Text {
  param(
    [string]$value,
    [int]$maxLen = 26
  )

  $t = ($value -replace '[`r`n]+', ' ').Trim()
  $t = $t.Trim('。', '！', '？', '；', '：', '，', '、', '“', '”', '"', "'", '《', '》', '（', '）', '(', ')')

  if ($t.Length -gt $maxLen) {
    $chunks = [System.Text.RegularExpressions.Regex]::Split($t, '[，、；：]') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_.Length -ge 6 }
    foreach ($c in $chunks) {
      if ($c.Length -le $maxLen) {
        return $c
      }
    }

    if ($chunks.Count -gt 0) {
      return $chunks[0]
    }
  }

  return $t
}

function Normalize-Snippet {
  param([string]$value)

  $s = ($value -replace '[`r`n]+', ' ').Trim()
  $s = $s -replace '^[-\*]\s*', ''
  $s = $s -replace '^[0-9]+[\.、]\s*', ''
  $s = $s.Trim('。', '！', '？', '；', '：', '，', '、', '“', '”', '"', "'", '《', '》', '（', '）', '(', ')', ' ')
  $s = $s -replace '\s+', ''
  return $s
}

function Is-WeakSnippet {
  param([string]$value)

  if ([string]::IsNullOrWhiteSpace($value)) { return $true }
  if ($value.Length -lt 6) { return $true }

  if ($value -match '^(张少侠亲启|书生|此章|本章|这一章|承接建议|语录候选)$') { return $true }
  if ($value -match '^(你来得|我改口|我不怕|你们大人物|驿卒喘着气)$') { return $true }

  # Dialogue-only fragments are usually weak as beat labels.
  if ($value -notmatch '[，。；：]' -and $value -match '[“”]') { return $true }

  return $false
}

function Get-FirstMeaningfulText {
  param(
    [string]$text,
    [string]$name
  )

  $pattern = '(?ms)^###\s*' + [regex]::Escape($name) + '(?:[（\(]([^）\)]+)[）\)])?\s*\r?\n(?<body>.*?)(?=^###\s|^##\s|\z)'
  $m = [regex]::Match($text, $pattern)
  if ($m.Success) {
    if ($m.Groups.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($m.Groups[1].Value)) {
      return (Clip-Text -value $m.Groups[1].Value)
    }

    $body = $m.Groups['body'].Value
    $lines = $body -split "`r?`n"
    foreach ($raw in $lines) {
      $line = $raw.Trim()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      if ($line.StartsWith('#')) { continue }
      $line = $line -replace '^[\-\*]\s*', ''
      $line = $line -replace '^[0-9]+[\.、]\s*', ''
      $line = $line.Trim('。', '！', '？', '；', '：')
      if ($line.Length -ge 4) {
        return (Clip-Text -value $line)
      }
    }
  }

  return ''
}

function Get-A3Snippets {
  param([string]$text)

  $a3Pattern = '(?ms)^##\s*正文(?:候选)?\s*A3.*?\r?\n(?<body>.*?)(?=^##\s|\z)'
  $m = [regex]::Match($text, $a3Pattern)
  if (-not $m.Success) {
    return @()
  }

  $a3Body = $m.Groups['body'].Value
  $a3Lines = @()
  foreach ($raw in ($a3Body -split "`r?`n")) {
    $line = $raw.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.StartsWith('#')) { continue }
    if ($line -match '^[-\*]') { continue }
    $a3Lines += $line
  }

  if ($a3Lines.Count -eq 0) {
    return @()
  }

  $full = ($a3Lines -join '')
  $parts = [System.Text.RegularExpressions.Regex]::Split($full, '[。！？；]') |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_.Length -ge 6 }

  if ($parts.Count -lt 4) {
    $extra = [System.Text.RegularExpressions.Regex]::Split($full, '[，、]') |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_.Length -ge 6 }
    if ($extra.Count -gt 0) {
      $parts = @($parts + $extra)
    }
  }

  $snips = @()
  $seen = @{}
  foreach ($p in $parts) {
    $n = Normalize-Snippet -value $p
    if (Is-WeakSnippet -value $n) { continue }
    if ($seen.ContainsKey($n)) { continue }
    $seen[$n] = $true
    $snips += (Clip-Text -value $n -maxLen 26)
  }
  return $snips
}

function Pick-A3BeatAt {
  param(
    [string[]]$snips,
    [string]$slot
  )

  if ($snips.Count -eq 0) { return '' }
  if ($snips.Count -eq 1) { return $snips[0] }

  $idx = 0
  switch ($slot) {
    'open' { $idx = 0 }
    'conflict' { $idx = [Math]::Floor(($snips.Count - 1) * 0.33) }
    'reversal' { $idx = [Math]::Floor(($snips.Count - 1) * 0.66) }
    'closure' { $idx = $snips.Count - 1 }
  }

  if ($idx -lt 0) { $idx = 0 }
  if ($idx -ge $snips.Count) { $idx = $snips.Count - 1 }
  return $snips[$idx]
}

function Upsert-SubsectionInSection {
  param(
    [string]$text,
    [string]$sectionTitle,
    [string]$subsectionTitle,
    [string]$subsectionBody
  )

  $sectionPattern = '(?ms)^##\s*' + [regex]::Escape($sectionTitle) + '\s*\r?\n(?<body>.*?)(?=^##\s|\z)'
  $sectionMatch = [regex]::Match($text, $sectionPattern)
  if (-not $sectionMatch.Success) {
    return $text
  }

  $oldBody = $sectionMatch.Groups['body'].Value
  $newBlock = "### $subsectionTitle`r`n`r`n$subsectionBody`r`n"

  $subPattern = '(?ms)^###\s*' + [regex]::Escape($subsectionTitle) + '\s*\r?\n.*?(?=^###\s|\z)'
  if ([regex]::IsMatch($oldBody, $subPattern)) {
    $newBody = [regex]::Replace($oldBody, $subPattern, $newBlock)
  }
  else {
    $trimmed = $oldBody.TrimEnd("`r", "`n")
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
      $newBody = "`r`n$newBlock"
    }
    else {
      $newBody = "$trimmed`r`n`r`n$newBlock"
    }
  }

  $start = $sectionMatch.Index + $sectionMatch.Length - $oldBody.Length
  $end = $start + $oldBody.Length
  return $text.Substring(0, $start) + $newBody + $text.Substring($end)
}

$elementEntries = foreach ($f in $elementFiles) {
  $full = Join-Path $worldDir $f
  $name = [System.IO.Path]::GetFileNameWithoutExtension($f) -replace '^元素-', ''
  $summary = Get-ElementSummary -filePath $full
  [PSCustomObject]@{
    Name = $name
    Rel = "10_worldbuilding/$f"
    Summary = $summary
  }
}

$chapters = Get-ChildItem -Path $draftDir -Filter 'ch*-草稿-v1.md' | Sort-Object Name
$updated = 0

foreach ($chapter in $chapters) {
  $text = Get-Content -Path $chapter.FullName -Raw -Encoding UTF8

  $openInfo = Get-FirstMeaningfulText -text $text -name '开场'
  $conflictInfo = Get-FirstMeaningfulText -text $text -name '对抗'
  $reversalInfo = Get-FirstMeaningfulText -text $text -name '反转'
  $closureInfo = Get-FirstMeaningfulText -text $text -name '收束'
  $a3Snips = Get-A3Snippets -text $text

  if ([string]::IsNullOrWhiteSpace($openInfo)) { $openInfo = Pick-A3BeatAt -snips $a3Snips -slot 'open' }
  if ([string]::IsNullOrWhiteSpace($conflictInfo)) { $conflictInfo = Pick-A3BeatAt -snips $a3Snips -slot 'conflict' }
  if ([string]::IsNullOrWhiteSpace($reversalInfo)) { $reversalInfo = Pick-A3BeatAt -snips $a3Snips -slot 'reversal' }
  if ([string]::IsNullOrWhiteSpace($closureInfo)) { $closureInfo = Pick-A3BeatAt -snips $a3Snips -slot 'closure' }

  $open = if ([string]::IsNullOrWhiteSpace($openInfo)) { '开场' } else { "开场（$openInfo）" }
  $conflict = if ([string]::IsNullOrWhiteSpace($conflictInfo)) { '对抗' } else { "对抗（$conflictInfo）" }
  $reversal = if ([string]::IsNullOrWhiteSpace($reversalInfo)) { '反转' } else { "反转（$reversalInfo）" }
  $closure = if ([string]::IsNullOrWhiteSpace($closureInfo)) { '收束' } else { "收束（$closureInfo）" }

  $basicBody = @(
    "- 第一节：$open"
    "- 第二节：$conflict"
    "- 第三节：$reversal"
    "- 第四节：$closure"
  ) -join "`r`n"

  $worldBodyLines = @()
  foreach ($entry in $elementEntries) {
    $worldBodyLines += "- $($entry.Name)：$($entry.Summary)（来源：$($entry.Rel)）"
  }
  $worldBody = $worldBodyLines -join "`r`n"

  $newText = $text
  $newText = Upsert-SubsectionInSection -text $newText -sectionTitle '基本信息' -subsectionTitle '本章四节（章节内子节）' -subsectionBody $basicBody
  $newText = Upsert-SubsectionInSection -text $newText -sectionTitle '九元素设定（本章）' -subsectionTitle '九大元素来源摘录（10_worldbuilding）' -subsectionBody $worldBody

  if ($newText -ne $text) {
    Set-Content -Path $chapter.FullName -Value $newText -Encoding UTF8
    $updated++
  }
}

Write-Host "CHAPTER_DRAFTS_OPTIMIZED: $updated / $($chapters.Count)"
