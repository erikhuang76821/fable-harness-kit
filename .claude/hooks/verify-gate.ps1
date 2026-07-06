# Stop hook:證據閘門(Definition of Done 硬化)
# 本 session 修改過程式檔、transcript 卻無任何測試/驗證指令執行痕跡、也沒明說「已修改、未驗證」
# → block 一次,要求補證據或誠實聲明。防護:stop_hook_active 放行(防迴圈);非 kit 專案放行。
# 註:與 stop-retro-gate 同掛 Stop;本 hook 排前(證據優先於檢討),兩者各自最多擋一次、
#     且任一擋過後 stop_hook_active=true 另一支即放行——單次收尾最多被擋一次,不會連環擋。

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }

if ($payload.stop_hook_active) { exit 0 }
if (-not (Test-Path ".claude/workflows/fable-emu.js")) { exit 0 }

$t = $payload.transcript_path
if (-not $t -or -not (Test-Path $t)) { exit 0 }

# 1) 改過「程式檔」嗎?(排除純文件:md/txt/markdown/rst;tool_use 為單行 JSON)
$codeEdit = Select-String -Path $t -Pattern '"name"\s*:\s*"(Edit|MultiEdit|Write)"[^\r\n]*"file_path"\s*:\s*"[^"]*\.(?!(md|txt|markdown|rst)")[A-Za-z0-9]+"' -Quiet
if (-not $codeEdit) { exit 0 }

# 2) 有測試/驗證指令的執行痕跡嗎?(白名單 + 字界,防「latest」「contest」誤中)
$testRun = Select-String -Path $t -Pattern '"name"\s*:\s*"(Bash|PowerShell)"[^\r\n]*"command"\s*:\s*"[^"]*\b(pytest|python3? -m pytest|invoke-pester|vitest|jest|playwright|go test|cargo test|dotnet test|node --test|node --check|npm (run )?test|pnpm test|yarn test|rspec|phpunit|ctest|mvn test|gradle test)\b' -Quiet
if ($testRun) { exit 0 }

# 3) 誠實聲明豁免:已明說「已修改、未驗證」(或引用 subagent 的驗證證據時通常伴隨測試指令,見 2)
$declared = Select-String -Path $t -Pattern '已修改[、,，]?\s*未驗證' -Quiet
if ($declared) { exit 0 }

$out = @{
  decision = 'block'
  reason   = '證據閘門(hook 強制,僅此一次):本 session 修改了程式檔,但沒有任何測試/驗證指令的執行痕跡。三選一:(1) 現在補跑對應驗證並貼出真實輸出;(2) 驗證已在 subagent/workflow 內完成 → 在回覆中引用該證據(含指令與結果);(3) 確實無法驗證 → 明說「已修改、未驗證」並說明原因。不得無聲明收尾。'
}
$out | ConvertTo-Json -Compress
exit 0
