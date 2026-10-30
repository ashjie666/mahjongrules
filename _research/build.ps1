param(
  [string]$Root = "L:\site\majiang"
)

$ErrorActionPreference = "Stop"
$web = Join-Path $Root "web"
$src = Join-Path $Root "_src"
$pagesFile = Join-Path $Root "_research\pages.psd1"
# Import-PowerShellDataFile in Windows PowerShell 5.1 does not support a top-level array,
# so evaluate the data file as a literal expression instead.
$pages = @([scriptblock]::Create([IO.File]::ReadAllText($pagesFile)).Invoke())

$utf8 = New-Object System.Text.UTF8Encoding($false)
$domain = "mahjongrules.fun"
$TODAY = "2026-10-30"

function Html([string]$s) { return ([string]$s).Replace("&","&amp;") }

function Slug([string]$t) {
  $x = $t.ToLowerInvariant()
  $x = [regex]::Replace($x, "<[^>]+>", " ")
  $x = [regex]::Replace($x, "&[a-z]+;", " ")
  $x = [regex]::Replace($x, "[^a-z0-9]+", "-").Trim("-")
  return $x
}

function StripTags([string]$t) {
  $x = [regex]::Replace($t, "<[^>]+>", "")
  $x = $x.Replace("&amp;", "&").Replace("&nbsp;", " ").Replace("&lt;", "<").Replace("&gt;", ">").Replace("&quot;", '"').Replace("&#39;", "'")
  return [regex]::Replace($x, "\s+", " ").Trim()
}

$groupMeta = @{
  "start"     = @{ Label = "Getting started";       Url = "/mahjong-rules";              Name = "Getting started" }
  "chinese"   = @{ Label = "Chinese styles";        Url = "/mcr-mahjong-rules";          Name = "Chinese styles" }
  "western"   = @{ Label = "Japanese & Western";    Url = "/riichi-mahjong-rules";       Name = "Japanese & Western" }
  "scoring"   = @{ Label = "Scoring";               Url = "/mahjong-scoring";            Name = "Scoring" }
  "strategy"  = @{ Label = "Strategy";              Url = "/mahjong-tile-efficiency";    Name = "Strategy" }
  "reference" = @{ Label = "Reference";             Url = "/mahjong-terms";              Name = "Reference" }
}

# slug -> H1 lookup for related links
$titleBySlug = @{}
foreach ($p in $pages) { if ($p.Slug) { $titleBySlug[$p.Slug] = $p.H1 } }

$HEADER = @'
<header class="site-header">
  <div class="wrap header-inner">
    <a class="brand" href="/">
      <span class="brand-mark" aria-hidden="true">&#20013;</span>
      <span class="brand-text">
        <span class="brand-name">Mahjong Rules</span>
        <span class="brand-sub">Rules, scoring and strategy</span>
      </span>
    </a>
    <nav class="main-nav" id="main-nav" aria-label="Primary">
      <div class="nav-item">
        <a href="/mahjong-rules">Start</a>
        <div class="subnav">
          <a href="/mahjong-rules">Mahjong rules<span>The full turn sequence</span></a>
          <a href="/mahjong-tiles">Tiles &amp; setup<span>Counts, suits, the wall</span></a>
          <a href="/mahjong-hands">Winning hands<span>Five legal shapes</span></a>
        </div>
      </div>
      <div class="nav-item">
        <a href="/mcr-mahjong-rules">Chinese</a>
        <div class="subnav">
          <a href="/mcr-mahjong-rules">MCR (Chinese Official)<span>144 tiles, 8-fan minimum</span></a>
          <a href="/sichuan-mahjong-rules">Sichuan<span>Blood battle, no honours</span></a>
          <a href="/hong-kong-mahjong-rules">Hong Kong<span>3-fan or 8-fan tables</span></a>
          <a href="/taiwanese-mahjong-rules">Taiwanese<span>16 tiles, 5 tai</span></a>
        </div>
      </div>
      <div class="nav-item">
        <a href="/riichi-mahjong-rules">Japanese &amp; Western</a>
        <div class="subnav">
          <a href="/riichi-mahjong-rules">Riichi<span>Riichi, furiten, dora</span></a>
          <a href="/american-mahjong-rules">American (NMJL)<span>Charleston and Jokers</span></a>
          <a href="/british-mahjong-rules">British (BMJA)<span>One chow per hand</span></a>
          <a href="/three-player-mahjong">Three-player<span>No north wind</span></a>
        </div>
      </div>
      <div class="nav-item">
        <a href="/mahjong-scoring">Scoring</a>
        <div class="subnav">
          <a href="/mahjong-scoring">Scoring basics<span>Fan, fu, tai, points</span></a>
          <a href="/mcr-fan-list">MCR fan list<span>88 fan down to 1</span></a>
          <a href="/riichi-yaku-list">Riichi yaku<span>12 must-know hands</span></a>
        </div>
      </div>
      <div class="nav-item">
        <a href="/mahjong-tile-efficiency">Strategy</a>
        <div class="subnav">
          <a href="/mahjong-tile-efficiency">Tile efficiency<span>Waits and out tiles</span></a>
          <a href="/mahjong-defence">Defence<span>Suji, kabe, safe tiles</span></a>
          <a href="/mahjong-first-game">First game<span>A full hand, turn by turn</span></a>
        </div>
      </div>
      <div class="nav-item">
        <a href="/mahjong-terms">Reference</a>
        <div class="subnav">
          <a href="/mahjong-terms">Glossary<span>Chow, pung, kong and more</span></a>
          <a href="/mahjong-faq">FAQ<span>40 quick answers</span></a>
          <a href="/mahjong-rule-comparison">Rules compared<span>Five axes, seven styles</span></a>
          <a href="/mahjong-variants">Regional variants<span>Guangdong to Vietnam</span></a>
          <a href="/mahjong-quiz">Quiz<span>20 questions</span></a>
          <a href="/mahjong-solitaire">Solitaire vs mahjong<span>Not the same game</span></a>
        </div>
      </div>
    </nav>
    <div class="header-actions">
      <a class="btn-subscribe" href="#subscribe">Subscribe<span> &middot; free</span></a>
      <button class="icon-btn" id="theme-toggle" type="button" aria-label="Toggle color theme">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4"></path></svg>
      </button>
      <button class="icon-btn menu-btn" id="menu-toggle" type="button" aria-expanded="false" aria-controls="main-nav" aria-label="Toggle menu">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16"></path></svg>
      </button>
    </div>
  </div>
</header>
'@

$SUBSCRIBE = @'
<section class="subscribe" id="subscribe">
  <div class="subscribe-inner">
    <p class="eyebrow">Newsletter</p>
    <h2>Get the next guide first</h2>
    <p>If you are into Chinese games, leave your email and I will tell you the moment a new guide goes live. No spam, one message per launch.</p>
    <form class="subscribe-form nl-form" action="https://getform.io/f/dypmujyqftn" method="post">
      <label class="sr-only" for="sub-email">Email address</label>
      <input id="sub-email" type="email" name="fi-sender-email" placeholder="you@example.com" autocomplete="email" required>
      <button type="submit">Notify me</button>
      <input type="text" name="_gotcha" style="display:none" tabindex="-1" autocomplete="off" aria-hidden="true">
    </form>
    <p class="subscribe-note">Your address is only used for new-guide announcements. Unsubscribe any time.</p>
    <p class="subscribe-status" role="status"></p>
  </div>
</section>
'@

$FOOTER = @'
<footer class="site-footer">
  <div class="wrap footer-inner">
    <div class="footer-brand">
      <p class="brand-name">Mahjong Rules</p>
      <p class="footer-note">An independent reference for mahjong rules and strategy. Mahjong is a traditional public-domain game; this site is not affiliated with any publisher or platform.</p>
    </div>
    <nav class="footer-cols" aria-label="Footer">
      <div>
        <p class="footer-head">Learn</p>
        <a href="/mahjong-rules">Rules</a>
        <a href="/mahjong-tiles">Tiles</a>
        <a href="/mahjong-hands">Winning hands</a>
        <a href="/mahjong-first-game">First game</a>
      </div>
      <div>
        <p class="footer-head">Rules</p>
        <a href="/mcr-mahjong-rules">MCR</a>
        <a href="/riichi-mahjong-rules">Riichi</a>
        <a href="/sichuan-mahjong-rules">Sichuan</a>
        <a href="/mahjong-rule-comparison">Compare</a>
      </div>
      <div>
        <p class="footer-head">Site</p>
        <a href="/about">About</a>
        <a href="/privacy-policy">Privacy</a>
        <a href="/terms-of-use">Terms</a>
        <a href="/disclaimer">Disclaimer</a>
        <a href="/dmca">DMCA</a>
        <a href="/cookie-notice">Cookies</a>
      </div>
    </nav>
  </div>
  <div class="wrap footer-base">
    <p>&copy; 2026 Mahjong Rules &middot; Contact: <a href="mailto:yqin1090@gmail.com">yqin1090@gmail.com</a></p>
  </div>
</footer>
'@

$FAVICON = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect x='5' y='3' width='22' height='26' rx='4' fill='%23f6f1e6' stroke='%23b03a2e' stroke-width='1.6'/%3E%3Ccircle cx='16' cy='16' r='6.5' fill='none' stroke='%23b03a2e' stroke-width='2.6'/%3E%3C/svg%3E"

$THEME_BOOT = @'
<script>
  (function () {
    try {
      var t = localStorage.getItem("site:theme");
      if (t === "dark" || t === "light") document.documentElement.setAttribute("data-theme", t);
    } catch (e) {}
  })();
</script>
'@

$ADSENSE = '<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-5158836206262469" crossorigin="anonymous"></script>'

function Build-Breadcrumb($p) {
  if ($p.Kind -eq "legal") {
    $items = @(
      @{ "@type" = "ListItem"; "position" = 1; "name" = "Home"; "item" = "https://$domain/" },
      @{ "@type" = "ListItem"; "position" = 2; "name" = $p.Breadcrumb; "item" = "https://$domain/$($p.Slug)" }
    )
    $ld = @{ "@context" = "https://schema.org"; "@type" = "BreadcrumbList"; "itemListElement" = $items } | ConvertTo-Json -Depth 6
    $html = @"
    <nav class="breadcrumb" aria-label="Breadcrumb">
      <ol>
        <li><a href="/">Home</a></li>
        <li>$($p.Breadcrumb)</li>
      </ol>
    </nav>
"@
    return @{ Html = $html; Ld = $ld }
  }
  $g = $groupMeta[$p.Group]
  $items = @(
    @{ "@type" = "ListItem"; "position" = 1; "name" = "Home"; "item" = "https://$domain/" },
    @{ "@type" = "ListItem"; "position" = 2; "name" = $g.Name; "item" = "https://$domain$($g.Url)" },
    @{ "@type" = "ListItem"; "position" = 3; "name" = $p.Breadcrumb; "item" = "https://$domain/$($p.Slug)" }
  )
  $ld = @{ "@context" = "https://schema.org"; "@type" = "BreadcrumbList"; "itemListElement" = $items } | ConvertTo-Json -Depth 6
  $html = @"
    <nav class="breadcrumb" aria-label="Breadcrumb">
      <ol>
        <li><a href="/">Home</a></li>
        <li><a href="$($g.Url)">$($g.Label)</a></li>
        <li>$($p.Breadcrumb)</li>
      </ol>
    </nav>
"@
  return @{ Html = $html; Ld = $ld }
}

foreach ($p in $pages) {
  $bodyPath = Join-Path $src ($p.Slug + ".body.html")
  if (-not (Test-Path $bodyPath)) { Write-Host "SKIP (no body): $($p.Slug)"; continue }
  $body = [IO.File]::ReadAllText($bodyPath, [Text.Encoding]::UTF8)

  # inject ids into h2 and collect toc
  $toc = New-Object System.Collections.ArrayList
  $used = @{}
  $sb = New-Object System.Text.StringBuilder
  $last = 0
  foreach ($m in [regex]::Matches($body, '(?s)<h2>(.*?)</h2>')) {
    [void]$sb.Append($body.Substring($last, $m.Index - $last))
    $text = StripTags $m.Groups[1].Value
    $id = Slug $text
    if ($used.ContainsKey($id)) { $used[$id]++; $id = "$id-$($used[$id])" } else { $used[$id] = 1 }
    [void]$toc.Add(@{ Id = $id; Text = $text })
    [void]$sb.Append("<h2 id=""$id"">" + $m.Groups[1].Value + "</h2>")
    $last = $m.Index + $m.Length
  }
  [void]$sb.Append($body.Substring($last))
  $body = $sb.ToString()

  # faq schema
  $faqItems = @()
  $faqMatches = [regex]::Matches($body, '(?s)<details class="faq-item">\s*<summary>(.*?)</summary>\s*<p>(.*?)</p>')
  foreach ($m in $faqMatches) {
    $faqItems += @{
      "@type" = "Question"
      "name" = (StripTags $m.Groups[1].Value)
      "acceptedAnswer" = @{ "@type" = "Answer"; "text" = (StripTags $m.Groups[2].Value) }
    }
  }
  $faqLd = ""
  if ($faqItems.Count -gt 0) {
    $faqLd = (@{ "@context" = "https://schema.org"; "@type" = "FAQPage"; "mainEntity" = $faqItems } | ConvertTo-Json -Depth 8)
    $faqLd = "<script type=""application/ld+json"">`n$faqLd`n</script>"
  }

  $bc = Build-Breadcrumb $p
  $articleLd = @{
    "@context" = "https://schema.org"
    "@type" = "Article"
    "headline" = $p.H1
    "description" = $p.Description
    "inLanguage" = "en"
    "datePublished" = "2026-10-30"
    "dateModified" = "2026-10-30"
    "mainEntityOfPage" = "https://$domain/$($p.Slug)"
    "author" = @{ "@type" = "Organization"; "name" = "Mahjong Rules" }
    "publisher" = @{ "@type" = "Organization"; "name" = "Mahjong Rules" }
  } | ConvertTo-Json -Depth 6

  # related links
  $relatedHtml = ""
  if ($p.Related) {
    $lines = @()
    foreach ($r in $p.Related) {
      $label = $titleBySlug[$r]
      if (-not $label) { $label = $r }
      $lines += "            <li><a href=""/$r"">$(Html $label)</a></li>"
    }
    $relatedHtml = @"
        <div class="side-card">
          <h2>Related</h2>
          <ul>
$($lines -join "`n")
          </ul>
        </div>
"@
  }

  # toc html
  $tocLines = @()
  foreach ($t in $toc) { $tocLines += "            <li><a href=""#$($t.Id)"">$(Html $t.Text)</a></li>" }

  $isLegal = $p.Kind -eq "legal"

  if ($isLegal) {
    $main = @"
    <div class="wrap">
$($bc.Html)
      <article class="doc-main" style="max-width:780px;padding-bottom:2.5rem">
        <header class="article-head">
          <p class="eyebrow">Site information</p>
          <h1>$($p.H1)</h1>
          <p class="meta-row"><span>Last reviewed: <time datetime="$TODAY">30 October 2026</time></span></p>
        </header>
        <div class="prose">
$body
        </div>
      </article>
    </div>
"@
  } else {
    $main = @"
    <div class="wrap">
$($bc.Html)
      <div class="layout">
        <div class="doc">
          <article class="doc-main">
            <header class="article-head">
              <p class="eyebrow">$($p.Eyebrow)</p>
              <h1>$($p.H1)</h1>
              <p class="lede">$($p.Lede)</p>
              <p class="meta-row"><span class="badge badge--accent">$($p.Badge)</span><span>Last reviewed: <time datetime="$TODAY">30 October 2026</time></span><span>~$($p.ReadTime) min read</span></p>
            </header>
$body
          </article>
        </div>
        <aside class="side">
          <div class="side-card">
            <h2>On this page</h2>
            <ul>
$($tocLines -join "`n")
            </ul>
          </div>
          <div class="side-card side-cta">
            <h3>New guides by email</h3>
            <p>One message per launch. No spam, no drip sequence.</p>
            <a class="btn" href="#subscribe">Subscribe</a>
          </div>
$relatedHtml
        </aside>
      </div>
$SUBSCRIBE
    </div>
"@
  }

  $adsHead = if ($isLegal) { "" } else { $ADSENSE }
  $canonical = "https://$domain/$($p.Slug)"

  $page = @"
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$($p.Title)</title>
<meta name="description" content="$($p.Description)">
<link rel="canonical" href="$canonical">
<meta property="og:type" content="article">
<meta property="og:site_name" content="Mahjong Rules">
<meta property="og:title" content="$($p.Title)">
<meta property="og:description" content="$($p.Description)">
<meta property="og:url" content="$canonical">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#b03a2e">
<link rel="icon" href="$FAVICON">
<link rel="stylesheet" href="styles.css">
$THEME_BOOT
$adsHead
<script type="application/ld+json">
$articleLd
</script>
<script type="application/ld+json">
$($bc.Ld)
</script>
$faqLd
</head>
<body>
<a class="skip-link" href="#main">Skip to content</a>
$HEADER
<main id="main">
$main
</main>
$FOOTER
<script src="app.js" defer></script>
</body>
</html>
"@

  [IO.File]::WriteAllText((Join-Path $web ($p.Slug + ".html")), $page, $utf8)
  Write-Host "WROTE $($p.Slug).html"
}

# sitemap
$entries = @("<url><loc>https://$domain/</loc><changefreq>weekly</changefreq><priority>1.0</priority></url>")
$entries += "<url><loc>https://$domain/mahjong-rules</loc><changefreq>monthly</changefreq><priority>0.9</priority></url>"
foreach ($p in $pages) {
  if ($p.Kind -eq "legal") { continue }
  $entries += "<url><loc>https://$domain/$($p.Slug)</loc><changefreq>monthly</changefreq><priority>0.8</priority></url>"
}
$sitemap = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n  " + ($entries -join "`n  ") + "`n</urlset>`n"
[IO.File]::WriteAllText((Join-Path $web "sitemap.xml"), $sitemap, $utf8)
Write-Host "WROTE sitemap.xml"

$robots = "User-agent: *`nAllow: /`nSitemap: https://$domain/sitemap.xml`n"
[IO.File]::WriteAllText((Join-Path $web "robots.txt"), $robots, $utf8)

$ads = "google.com, pub-5158836206262469, DIRECT, f08c47fec0942fa0`n"
[IO.File]::WriteAllText((Join-Path $web "ads.txt"), $ads, $utf8)
Write-Host "WROTE robots.txt + ads.txt"
