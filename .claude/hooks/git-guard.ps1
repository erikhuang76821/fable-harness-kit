# PreToolUse hook:攔截危險指令(提詞管不住的事,交給硬閘門)
# stdin 收到 {tool_name, tool_input:{command,...}};exit 2 = 阻擋,stderr 回饋給模型

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }
$cmd = $payload.tool_input.command
if (-not $cmd) { exit 0 }

# 位置容忍設計:git 與子命令之間允許任意全域旗標(-c/-C/--git-dir 等)、rm/Remove-Item 旗標任意順序合併,
# 但 [^|&;]* 不跨越命令分隔符。regex 閘門是 best-effort 的最後防線,不是沙箱;主要防呆而非防蓄意繞過。
$patterns = @(
  'git\b[^|&;]*\bpush\b[^|&;]*\s(--force(-with-lease)?\b|-[A-Za-z]*f\b)',
  'git\b[^|&;]*\breset\s+--hard',
  'git\b[^|&;]*\bclean\b[^|&;]*\s-[A-Za-z-]*f',
  'git\b[^|&;]*\bbranch\b[^|&;]*\s-D\b',
  'git\b[^|&;]*\bcheckout\s+--\s',
  'git\b[^|&;]*\bstash\s+(drop|clear)',
  'git\b[^|&;]*\brebase\b[^|&;]*\s(-i\b|--interactive\b)',
  'rm\b(?=[^|&;]*\s-[A-Za-z]*r)(?=[^|&;]*\s-[A-Za-z]*f)[^|&;]*\s["'']?([/~]|[A-Za-z]:[\\/])',
  '(?i:Remove-Item|ri|del|erase)\b(?i)(?![^|&;]*-WhatIf(?!:\s*\$?false\b))(?=[^|&;]*-Recurse)(?=[^|&;]*-Force)[^|&;]*\s["'']?([A-Za-z]:[\\/]|[/~])',
  '(^|\s)(?i:rd|rmdir)\s+/s\b'
)

# -cmatch(區分大小寫):git 的 -d(刪已合併)與 -D(強刪)語意不同,不可混判
foreach ($p in $patterns) {
  if ($cmd -cmatch $p) {
    [Console]::Error.WriteLine("git-guard BLOCKED:指令符合危險模式 '$p'。此類操作不由 agent 執行;若確有必要,請說明理由並請使用者手動執行。")
    exit 2
  }
}
exit 0
