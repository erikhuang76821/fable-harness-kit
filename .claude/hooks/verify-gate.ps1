# Stop hook:證據閘門(Definition of Done 硬化)
# 本 session 修改過程式檔、「最後一次修改之後」無任何測試/驗證指令執行痕跡、
# 也沒明說「已修改、未驗證」→ block 一次,要求補證據或誠實聲明。
# 防護:stop_hook_active 放行(防迴圈);非 kit 專案放行。
# 註:與 stop-retro-gate 同掛 Stop、本 hook 排前(證據優先於檢討)。兩支各自因
#     stop_hook_active 最多擋一次;單次收尾最壞被擋兩次(一次證據、一次檢討),
#     不會無限迴圈——實際擋幾次取決於 Claude Code 對同一 Stop 事件多 hook 的處理。

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }

if ($payload.stop_hook_active) { exit 0 }
if (-not (Test-Path ".claude/workflows/fable-emu.js")) { exit 0 }

$t = $payload.transcript_path
if (-not $t -or -not (Test-Path $t)) { exit 0 }

# 1) 改過「程式檔」嗎?(排除純文件 md/txt/markdown/rst;含無副檔名程式檔與 NotebookEdit)
$editPatterns = @(
  '"name"\s*:\s*"(Edit|MultiEdit|Write)"[^\r\n]*"file_path"\s*:\s*"[^"]*\.(?!(md|txt|markdown|rst)")[A-Za-z0-9]+"',
  '"name"\s*:\s*"(Edit|MultiEdit|Write)"[^\r\n]*"file_path"\s*:\s*"[^"]*(Dockerfile|Makefile|Jenkinsfile|Rakefile|\.env(\.[A-Za-z0-9]+)?)"',
  '"name"\s*:\s*"NotebookEdit"[^\r\n]*"notebook_path"'
)
$lastEditLine = 0
foreach ($p in $editPatterns) {
  $m = Select-String -Path $t -Pattern $p
  foreach ($hit in $m) { if ($hit.LineNumber -gt $lastEditLine) { $lastEditLine = $hit.LineNumber } }
}
if ($lastEditLine -eq 0) { exit 0 }

# 2) 「最後一次修改之後」有測試/驗證指令的執行痕跡嗎?
#    行號比較假設 transcript 為一行一事件(JSONL,與 stop-retro-gate 同一假設);
#    同行並存 edit+test 時判 block(保守側:寧可多要一次證據,不假放行)。
#    白名單 token 必須位於指令開頭或 && ; | 分隔符之後——「echo pytest」「rg pytest」這類
#    只是提到測試字樣的指令不算證據;先測後改也不算(順序判準)。
$testPattern = '"name"\s*:\s*"(Bash|PowerShell)"[^\r\n]*"command"\s*:\s*"(?:[^"]*?(?:&&|;|\|)\s*)?(?:python3?\s+-m\s+)?(pytest|invoke-pester|vitest|jest|playwright|go test|cargo test|dotnet test|node --test|node --check|npm (run )?test|pnpm test|yarn test|rspec|phpunit|ctest|mvn test|gradle test)\b'
$lastTestLine = 0
foreach ($hit in (Select-String -Path $t -Pattern $testPattern)) {
  if ($hit.LineNumber -gt $lastTestLine) { $lastTestLine = $hit.LineNumber }
}
if ($lastTestLine -gt $lastEditLine) { exit 0 }

# 3) 誠實聲明豁免:已明說「已修改、未驗證」(或引用 subagent 的驗證證據時通常伴隨測試指令,見 2)
# 容忍常見變體:「已修改、未驗證」「已修改,尚未驗證」(2026-07-06 金絲雀實證:模型會寫「尚未」)
$declared = Select-String -Path $t -Pattern '已修改[^。\r\n]{0,6}未驗證' -Quiet
if ($declared) { exit 0 }

$out = @{
  decision = 'block'
  reason   = '證據閘門(hook 強制,僅此一次):本 session 修改了程式檔,但沒有任何測試/驗證指令的執行痕跡。三選一:(1) 現在補跑對應驗證並貼出真實輸出;(2) 驗證已在 subagent/workflow 內完成 → 在回覆中引用該證據(含指令與結果);(3) 確實無法驗證 → 明說「已修改、未驗證」並說明原因。不得無聲明收尾。'
}
$out | ConvertTo-Json -Compress
exit 0
