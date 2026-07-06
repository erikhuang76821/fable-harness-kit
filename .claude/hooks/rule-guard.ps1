# PostToolUse hook(matcher: Edit|Write):規則檔血統留痕
# 規則檔(CLAUDE.md / invariants.md / DECISION-CORE.md)被修改時,自動 append 稽核紀錄到 .fable/DECISIONS.md
# 不阻擋(修改已發生),只留可追溯證據鏈:規則變更應來自已核准的 KIT-SUGGESTIONS 條目或使用者明示

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }

$fp = $payload.tool_input.file_path
if (-not $fp) { exit 0 }

# 只關心規則檔
if ($fp -notmatch '(CLAUDE\.md|invariants\.md|DECISION-CORE\.md)$') { exit 0 }
# 排除 .fable 底下與模板目錄的同名檔
if ($fp -match '\\\.fable\\|/\.fable/|templates') { exit 0 }

if (-not (Test-Path ".fable")) { New-Item -ItemType Directory -Force ".fable" | Out-Null }
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$leaf = Split-Path $fp -Leaf
$entry = "- [$ts] 規則檔變更(hook 自動留痕):$leaf 被本 session 修改。血統要求:此變更應可追溯至 KIT-SUGGESTIONS 的 [accepted] 條目、實驗數據、或使用者明示指示;若無,視為未經批准的規則漂移,應回退。"
Add-Content -Path ".fable/DECISIONS.md" -Value $entry -Encoding utf8
exit 0
