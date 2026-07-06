# UserPromptSubmit hook:每回合一行輕推,對抗長 session 的規則衰減(SessionStart 注入會隨 context 變長而稀釋)
# 關閉方式:在專案根目錄建立 .claude/nudge-off(空檔即可)——實戰若證明是噪音,一行指令關掉
# 輪播依分鐘數取模,無狀態、無外部依賴

if (Test-Path ".claude/nudge-off") { exit 0 }

$nudges = @(
  '證據先於宣稱:本則訊息內沒跑過驗證指令,不得宣稱通過。',
  '交付優先:可逆的先做再報,不可逆的才停下問。',
  '動工前:讀過 .fable/LESSONS.md 了嗎?範圍(碰什麼/不碰什麼)宣告了嗎?',
  '慢下來訊號:正要寫「應該可以」= 沒證據;同一錯誤第二次出現 = 換路,不是重試。'
)
$i = (Get-Date).Minute % $nudges.Count

$out = @{
  hookSpecificOutput = @{
    hookEventName     = 'UserPromptSubmit'
    additionalContext = "<nudge>$($nudges[$i])</nudge>"
  }
}
$out | ConvertTo-Json -Depth 4
exit 0
