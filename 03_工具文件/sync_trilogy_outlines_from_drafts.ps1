$ErrorActionPreference = 'Stop'

$root = 'e:/DONT_TOUCH/12M-2025-Novels/wuxia-novels'
$draftDir = Join-Path $root '40_generation/章节草稿'
$outWrite = Join-Path $root '00_source/大纲设计/三部曲-写作大纲-2026-0418.md'
$outDesign = Join-Path $root '00_source/大纲设计/三部曲-大纲设计-2026-0418.md'

$chapters = Get-ChildItem -Path $draftDir -File | Where-Object {
  $_.Name -match '^ch(\d{3})-(.+)-草稿-v1\.md$' -and $matches[1] -ne '000'
} | ForEach-Object {
  $_.Name -match '^ch(\d{3})-(.+)-草稿-v1\.md$' | Out-Null
  [PSCustomObject]@{
    Num = [int]$matches[1]
    Ch = $matches[1]
    Title = $matches[2]
    File = $_.Name
    Full = $_.FullName
  }
} | Sort-Object Num

if ($chapters.Count -ne 132) {
  throw "Expected 132 chapters, got $($chapters.Count)"
}

function Get-VolumeName([int]$idx) {
  switch ($idx) {
    1 { '第一卷 旧约裂口（ch001~ch022）' }
    2 { '第二卷 追缉成网（ch023~ch044）' }
    3 { '第三卷 谈战并线（ch045~ch066）' }
    4 { '第四卷 代际接令（ch067~ch088）' }
    5 { '第五卷 治理硬仗（ch089~ch110）' }
    6 { '第六卷 立碑复议（ch111~ch132）' }
  }
}

function Get-Beats([string]$path) {
  $lines = Get-Content -Path $path -Encoding UTF8
  $headings = @()
  foreach ($line in $lines) {
    if ($line -match '^###\s*(.+)$') {
      $headings += $matches[1].Trim()
    }
  }

  $defaults = @{
    '开场' = '开场推进'
    '对抗' = '冲突升级'
    '反转' = '反转揭示'
    '收束' = '收束钩子'
  }

  $result = [ordered]@{}
  foreach ($k in @('开场', '对抗', '反转', '收束')) {
    $hit = $headings | Where-Object { $_ -like "*$k*" } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($hit)) {
      $result[$k] = $defaults[$k]
    }
    else {
      $result[$k] = $hit
    }
  }

  # If explicit beat headings are missing, try extracting 4 clauses from A3正文.
  $allDefault = $true
  foreach ($k in @('开场', '对抗', '反转', '收束')) {
    if ($result[$k] -ne $defaults[$k]) {
      $allDefault = $false
      break
    }
  }

  if ($allDefault) {
    $a3Start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^##\s*正文.*A3') {
        $a3Start = $i + 1
        break
      }
    }

    if ($a3Start -ge 0) {
      $a3Lines = @()
      for ($j = $a3Start; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^##\s+') { break }
        $t = $lines[$j].Trim()
        if ([string]::IsNullOrWhiteSpace($t)) { continue }
        if ($t -match '^[-#]') { continue }
        $a3Lines += $t
      }

      if ($a3Lines.Count -gt 0) {
        $a3Text = ($a3Lines -join '')
        $parts = [System.Text.RegularExpressions.Regex]::Split($a3Text, '[。！？；]') |
          ForEach-Object { $_.Trim() } |
          Where-Object { $_.Length -ge 6 }

        if ($parts.Count -lt 4) {
          $extra = [System.Text.RegularExpressions.Regex]::Split($a3Text, '[，、]') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_.Length -ge 6 }
          if ($extra.Count -gt 0) {
            $parts = @($parts + $extra)
          }
        }

        if ($parts.Count -gt 0) {
          $clip = {
            param([string]$s)
            if ($s.Length -gt 16) { return $s.Substring(0, 16) + '…' }
            return $s
          }
          if ($parts.Count -ge 1) { $result['开场'] = '开场（' + (&$clip $parts[0]) + '）' }
          if ($parts.Count -ge 2) { $result['对抗'] = '对抗（' + (&$clip $parts[1]) + '）' }
          if ($parts.Count -ge 3) { $result['反转'] = '反转（' + (&$clip $parts[2]) + '）' }
          if ($parts.Count -ge 4) { $result['收束'] = '收束（' + (&$clip $parts[3]) + '）' }
        }
      }
    }
  }

  return $result
}

$beatsMap = @{}
foreach ($c in $chapters) {
  $beatsMap[$c.Ch] = Get-Beats $c.Full
}

# File 1: 三部曲-写作大纲
$sb1 = New-Object System.Text.StringBuilder
[void]$sb1.AppendLine('# 三部曲-写作大纲-2026-0418')
[void]$sb1.AppendLine('')
[void]$sb1.AppendLine('## 同步说明')
[void]$sb1.AppendLine('')
[void]$sb1.AppendLine('- 同步来源：40_generation/章节草稿/ch001~ch132-草稿-v1.md。')
[void]$sb1.AppendLine('- 章名与顺序以草稿目录为唯一口径。')
[void]$sb1.AppendLine('- 每章四节采用草稿中的“开场/对抗/反转/收束”标题抽取；缺失项使用默认补齐。')
[void]$sb1.AppendLine('')
[void]$sb1.AppendLine('---')
[void]$sb1.AppendLine('')

for ($v = 1; $v -le 6; $v++) {
  $start = ($v - 1) * 22 + 1
  $end = $v * 22
  [void]$sb1.AppendLine("## $(Get-VolumeName $v)")
  [void]$sb1.AppendLine('')
  foreach ($c in $chapters | Where-Object { $_.Num -ge $start -and $_.Num -le $end }) {
    $b = $beatsMap[$c.Ch]
    [void]$sb1.AppendLine("- ch$($c.Ch) $($c.Title)：$($b['开场']) / $($b['对抗']) / $($b['反转']) / $($b['收束'])")
    [void]$sb1.AppendLine("  - 草稿：40_generation/章节草稿/$($c.File)")
  }
  [void]$sb1.AppendLine('')
  [void]$sb1.AppendLine('---')
  [void]$sb1.AppendLine('')
}

[void]$sb1.AppendLine('## 附录A 三部曲章名总表（同步版）')
[void]$sb1.AppendLine('')
for ($part = 1; $part -le 3; $part++) {
  $pStart = ($part - 1) * 44 + 1
  $pEnd = $part * 44
  $partName = switch ($part) {
    1 { '第一部：戮世魔罗（ch001~ch044）' }
    2 { '第二部：绝世双雄（ch045~ch088）' }
    3 { '第三部：君临天下（ch089~ch132）' }
  }
  [void]$sb1.AppendLine("### $partName")
  [void]$sb1.AppendLine('')
  $idx = 1
  foreach ($c in $chapters | Where-Object { $_.Num -ge $pStart -and $_.Num -le $pEnd }) {
    [void]$sb1.AppendLine("$idx. $($c.Title)")
    $idx++
  }
  [void]$sb1.AppendLine('')
}

Set-Content -Path $outWrite -Value $sb1.ToString() -Encoding UTF8

# File 2: 三部曲-大纲设计
$sb2 = New-Object System.Text.StringBuilder
[void]$sb2.AppendLine('# 三部曲-大纲设计-2026-0418')
[void]$sb2.AppendLine('')
[void]$sb2.AppendLine('## 文档定位')
[void]$sb2.AppendLine('')
[void]$sb2.AppendLine('- 本文件为三部曲结构设计总览（宏观层）。')
[void]$sb2.AppendLine('- 章节执行索引见：00_source/大纲设计/三部曲-写作大纲-2026-0418.md。')
[void]$sb2.AppendLine('- 同步基准见：40_generation/章节草稿/ch001~ch132-草稿-v1.md。')
[void]$sb2.AppendLine('')
[void]$sb2.AppendLine('## 结构总览')
[void]$sb2.AppendLine('')
[void]$sb2.AppendLine('- 总章节：132 章')
[void]$sb2.AppendLine('- 三部结构：每部 44 章')
[void]$sb2.AppendLine('- 六卷结构：每卷 22 章')
[void]$sb2.AppendLine('- 四节结构：开场 / 对抗 / 反转 / 收束')
[void]$sb2.AppendLine('')

for ($part = 1; $part -le 3; $part++) {
  $pStart = ($part - 1) * 44 + 1
  $pEnd = $part * 44
  $partName = switch ($part) {
    1 { '第一部：戮世魔罗（ch001~ch044）' }
    2 { '第二部：绝世双雄（ch045~ch088）' }
    3 { '第三部：君临天下（ch089~ch132）' }
  }
  [void]$sb2.AppendLine("## $partName")
  [void]$sb2.AppendLine('')
  [void]$sb2.AppendLine('### 章节设计清单（同步）')
  [void]$sb2.AppendLine('')
  foreach ($c in $chapters | Where-Object { $_.Num -ge $pStart -and $_.Num -le $pEnd }) {
    $b = $beatsMap[$c.Ch]
    [void]$sb2.AppendLine("- ch$($c.Ch) $($c.Title)：$($b['开场']) / $($b['对抗']) / $($b['反转']) / $($b['收束'])")
  }
  [void]$sb2.AppendLine('')
}

[void]$sb2.AppendLine('## 六卷切分（排期口径）')
[void]$sb2.AppendLine('')
for ($v = 1; $v -le 6; $v++) {
  [void]$sb2.AppendLine("- $(Get-VolumeName $v)")
}

[void]$sb2.AppendLine('')
[void]$sb2.AppendLine('## 维护规则')
[void]$sb2.AppendLine('')
[void]$sb2.AppendLine('1. 新增或改名章节时，先更新 40_generation/章节草稿。')
[void]$sb2.AppendLine('2. 再同步本文件与《三部曲-写作大纲-2026-0418》。')
[void]$sb2.AppendLine('3. 统一使用 ch001~ch132，不保留 e 章并行口径。')

Set-Content -Path $outDesign -Value $sb2.ToString() -Encoding UTF8
Write-Output 'ENHANCED_SYNC_WITH_BEATS_OK'
