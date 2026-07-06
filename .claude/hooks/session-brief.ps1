# SessionStart hook:每個 session 開頭(startup/clear/compact)注入核心鐵律 + 最近教訓
# 靈感來自 obra/superpowers 的 session-start 注入;內容對應本套件的 CLAUDE.md 與 .fable/
# 價值:LESSONS 變成連日常對話都躲不掉的 context;compact 後核心規則自動重新注入

$brief = @"
<harness-brief>
你在 fable-harness 專案內工作。核心鐵律(完整版見 CLAUDE.md / docs/DECISION-CORE.md):
1. 任務分級路由:預設 Tier 0(提詞層 inline);碰錢/資料/不可逆才升級;fable-emu 僅互動式 session。
2. 證據先於宣稱:本則訊息內沒跑過驗證指令,不得宣稱通過。
3. 交付優先:可逆的先做再報,不可逆的才停下問;問錯問題時第一責任是指出來。
4. 動工前讀 .fable/LESSONS.md 與 .fable/DECISIONS.md,避免重蹈與翻案。
"@

# 待審 kit 建議計數(人審迴路的「讀」端)
$sugPath = ".fable/KIT-SUGGESTIONS.md"
if (Test-Path $sugPath) {
  try {
    $pending = @(Select-String -Path $sugPath -Pattern '^\s*-\s*\[pending\]' -ErrorAction Stop).Count
    if ($pending -gt 0) {
      $brief += "`n⚠ 待審 kit 建議:$pending 條([pending],見 .fable/KIT-SUGGESTIONS.md)。請提醒使用者審核;僅 [accepted] 可入法規則檔。"
    }
  } catch {}
}

# 蒸餾觸發器:教訓/建議累積過長 → 提示升格與歸檔
foreach ($f in @(".fable/LESSONS.md", ".fable/KIT-SUGGESTIONS.md")) {
  if (Test-Path $f) {
    try {
      if (@(Get-Content $f -ErrorAction Stop).Count -gt 80) {
        $brief += "`n⚠ $f 已超過 80 行 —— 該蒸餾:重複教訓升格為規則(經人審),過時項歸檔。"
      }
    } catch {}
  }
}

$lessonsPath = ".fable/LESSONS.md"
if (Test-Path $lessonsPath) {
  try {
    $tail = (Get-Content $lessonsPath -Tail 40 -ErrorAction Stop) -join "`n"
    if ($tail.Trim()) {
      $brief += "`n`n## 最近的教訓(.fable/LESSONS.md 末 40 行,動工前必讀)`n" + $tail
    }
  } catch {}
}

$decisionsPath = ".fable/DECISIONS.md"
if (Test-Path $decisionsPath) {
  try {
    $dtail = (Get-Content $decisionsPath -Tail 25 -ErrorAction Stop) -join "`n"
    if ($dtail.Trim()) {
      $brief += "`n`n## 最近的決策(.fable/DECISIONS.md 末 25 行,翻案前必讀)`n" + $dtail
    }
  } catch {}
}
$brief += "`n</harness-brief>"

$out = @{
  hookSpecificOutput = @{
    hookEventName     = "SessionStart"
    additionalContext = $brief
  }
}
$out | ConvertTo-Json -Depth 5
exit 0
