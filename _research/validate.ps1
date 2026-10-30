param([string]$Root = "L:\site\majiang")

$ErrorActionPreference = "Stop"
$web = Join-Path $Root "web"
$pagesFile = Join-Path $Root "_research\pages.psd1"
$pages = @([scriptblock]::Create([IO.File]::ReadAllText($pagesFile)).Invoke())
$legalSlugs = @()
foreach ($p in $pages) { if ($p.Kind -eq "legal") { $legalSlugs += $p.Slug } }

$files = Get-ChildItem $web -Filter *.html | Sort-Object Name
$problems = New-Object System.Collections.ArrayList
function Add-Problem([string]$msg) { [void]$problems.Add($msg) }

$VOID = @("meta","link","br","img","input","hr","source","area","base","col","embed","param","track","wbr","path","circle","rect","line","polyline","polygon","ellipse","stop","use","text")

$titles = @{}
$descs = @{}

foreach ($f in $files) {
  $html = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $name = $f.Name
  $is404 = ($name -eq "404.html")

  # title
  $tm = [regex]::Match($html, '(?s)<title>(.*?)</title>')
  if (-not $tm.Success) { Add-Problem "$name : missing title" }
  else {
    $t = $tm.Groups[1].Value.Trim()
    if ($t.Length -gt 60) { Add-Problem ("{0} : title {1} chars (max 60)" -f $name, $t.Length) }
    if ($titles.ContainsKey($t)) { Add-Problem ("{0} : duplicate title of {1}" -f $name, $titles[$t]) } else { $titles[$t] = $name }
  }

  # description
  if (-not $is404) {
    $dm = [regex]::Match($html, '<meta name="description" content="([^"]*)"')
    if (-not $dm.Success) { Add-Problem "$name : missing description" }
    else {
      $d = $dm.Groups[1].Value
      if ($d.Length -lt 110 -or $d.Length -gt 165) { Add-Problem ("{0} : description {1} chars (want 110-165)" -f $name, $d.Length) }
      if ($descs.ContainsKey($d)) { Add-Problem ("{0} : duplicate description of {1}" -f $name, $descs[$d]) } else { $descs[$d] = $name }
    }
  }

  # canonical — a 404 page carries noindex instead, so no canonical is expected there
  if (-not $is404) {
    $cm = [regex]::Match($html, '<link rel="canonical" href="([^"]*)"')
    if (-not $cm.Success) { Add-Problem "$name : missing canonical" }
    elseif ($cm.Groups[1].Value -match "\.html$") { Add-Problem "$name : canonical has .html suffix" }
  }
  else {
    if ($html -notmatch 'name="robots" content="noindex') { Add-Problem "$name : 404 page is not noindex" }
  }

  # h1
  $h1n = [regex]::Matches($html, '<h1[ >]').Count
  if ($h1n -ne 1) { Add-Problem ("{0} : {1} h1 tags" -f $name, $h1n) }

  # JSON-LD
  $ldBlocks = [regex]::Matches($html, '(?s)<script type="application/ld\+json">(.*?)</script>')
  if ($ldBlocks.Count -lt 2 -and -not $is404) { Add-Problem ("{0} : only {1} JSON-LD blocks" -f $name, $ldBlocks.Count) }
  foreach ($m in $ldBlocks) {
    try { $null = $m.Groups[1].Value | ConvertFrom-Json } catch { Add-Problem "$name : JSON-LD does not parse" }
  }

  # internal links
  foreach ($m in [regex]::Matches($html, 'href="(/[^"#?]*)(#[^"]*)?"')) {
    $path = $m.Groups[1].Value
    if ($path -eq "/") { continue }
    if (-not (Test-Path (Join-Path $web ($path.TrimStart('/') + ".html")))) {
      Add-Problem ("{0} : broken link {1}" -f $name, $path)
    }
  }

  # ad slots on article pages
  if ($pages) {
    $meta = $pages | Where-Object { $_.Slug -eq ($name -replace "\.html$", "") }
    if ($meta -and $meta.Kind -ne "legal") {
      $ads = [regex]::Matches($html, 'class="ad-slot').Count
      if ($ads -lt 2) { Add-Problem ("{0} : only {1} ad slots" -f $name, $ads) }
    }
  }

  # tag balance (stack parser)
  $stack = New-Object System.Collections.ArrayList
  $line = 1
  $idx = 0
  foreach ($m in [regex]::Matches($html, '<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>')) {
    $before = $html.Substring($idx, $m.Index - $idx)
    $line += ([regex]::Matches($before, "\n")).Count
    $idx = $m.Index + $m.Length
    $closing = $m.Groups[1].Value
    $tag = $m.Groups[2].Value.ToLowerInvariant()
    $rest = $m.Groups[3].Value
    if ($rest.EndsWith("/")) { continue }
    if ($VOID -contains $tag) { continue }
    if ($closing -eq "") { [void]$stack.Add(@{ Tag = $tag; Line = $line }) ; continue }
    if ($stack.Count -eq 0) { Add-Problem ("{0}:{1} : stray </{2}>" -f $name, $line, $tag); continue }
    $top = $stack[$stack.Count - 1]
    if ($top.Tag -eq $tag) { $stack.RemoveAt($stack.Count - 1); continue }
    $found = $false
    for ($i = $stack.Count - 1; $i -ge 0; $i--) {
      if ($stack[$i].Tag -eq $tag) { $found = $true; break }
    }
    if ($found) {
      while ($stack.Count - 1 -gt $i) {
        Add-Problem ("{0}:{1} : <{2}> not closed before </{3}>" -f $name, $stack[$stack.Count - 1].Line, $stack[$stack.Count - 1].Tag, $tag)
        $stack.RemoveAt($stack.Count - 1)
      }
      $stack.RemoveAt($stack.Count - 1)
    } else {
      Add-Problem ("{0}:{1} : stray </{2}>" -f $name, $line, $tag)
    }
  }
  foreach ($s in $stack) { Add-Problem ("{0}:{1} : <{2}> never closed" -f $name, $s.Line, $s.Tag) }
}

# sitemap consistency
$sitemap = [IO.File]::ReadAllText((Join-Path $web "sitemap.xml"), [Text.Encoding]::UTF8)
$locs = [regex]::Matches($sitemap, '<loc>https://mahjongrules.fun([^<]*)</loc>')
foreach ($m in $locs) {
  $p = $m.Groups[1].Value
  if ($p -eq "" -or $p -eq "/") { continue }
  if (-not (Test-Path (Join-Path $web ($p.TrimStart('/') + ".html")))) { Add-Problem "sitemap : URL without a page $p" }
}
foreach ($p in $pages) {
  if ($p.Kind -eq "legal") { continue }
  if ($sitemap -notmatch ("/" + [regex]::Escape($p.Slug) + "<")) { Add-Problem ("sitemap : missing {0}" -f $p.Slug) }
}
if ($sitemap -notmatch "/mahjong-rules<") { Add-Problem "sitemap : missing mahjong-rules" }
Write-Host ("sitemap URLs: {0}" -f $locs.Count)

# repeated long sentences outside template chrome
$sentences = @{}
foreach ($f in $files) {
  $text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $text = [regex]::Replace($text, '(?s)<(script|style)[^>]*>.*?</\1>', " ")
  $text = [regex]::Replace($text, '(?s)<header class="site-header".*?</header>', " ")
  $text = [regex]::Replace($text, '(?s)<footer class="site-footer".*?</footer>', " ")
  $text = [regex]::Replace($text, '(?s)<section class="subscribe".*?</section>', " ")
  $text = [regex]::Replace($text, '(?s)<aside class="side".*?</aside>', " ")
  $text = [regex]::Replace($text, '<[^>]+>', " ")
  $text = [regex]::Replace($text, '\s+', " ")
  foreach ($s in [regex]::Matches($text, '[^.!?]{70,}\.')) {
    $key = $s.Value.Trim()
    if ($sentences.ContainsKey($key)) { $sentences[$key] = $sentences[$key] + ", " + $f.Name }
    else { $sentences[$key] = $f.Name }
  }
}
$dupes = @($sentences.GetEnumerator() | Where-Object { $_.Value -match "," })
foreach ($d in $dupes) {
  $short = $d.Key
  if ($short.Length -gt 90) { $short = $short.Substring(0, 90) + "..." }
  Add-Problem ("repeated sentence in {0} :: {1}" -f $d.Value, $short)
}

Write-Host ""
if ($problems.Count -eq 0) { Write-Host "ALL CHECKS PASSED" }
else {
  Write-Host ("PROBLEMS: {0}" -f $problems.Count)
  foreach ($p in $problems) { Write-Host (" - " + $p) }
}
