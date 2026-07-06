# session-brief.ps1 的黑箱測試(Pester 3.4)
# 契約:輸出 SessionStart additionalContext JSON;含鐵律;有 pending 建議時報數;LESSONS 過長時提示蒸餾。

. (Join-Path $PSScriptRoot 'TestHelper.ps1')

Describe 'session-brief' {
  BeforeEach {
    $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force (Join-Path $script:root '.fable') | Out-Null
  }

  It '基本輸出:JSON 含 harness-brief 與核心鐵律' {
    $r = Invoke-Hook 'session-brief.ps1' '{}' $script:root
    $r.ExitCode | Should Be 0
    $r.StdOut | Should Match 'harness-brief'
    $r.StdOut | Should Match '證據先於宣稱'
  }

  It '有 [pending] 建議 → 報待審數' {
    Set-Content -Path (Join-Path $script:root '.fable\KIT-SUGGESTIONS.md') -Value @"
# KIT-SUGGESTIONS
- [pending] 建議一(證據:x;2026-07-06)
- [accepted] 已核准(證據:y;2026-07-05)
- [pending] 建議二(證據:z;2026-07-06)
"@ -Encoding utf8
    $r = Invoke-Hook 'session-brief.ps1' '{}' $script:root
    $r.StdOut | Should Match '待審 kit 建議'
    $r.StdOut | Should Match '2'
  }

  It 'LESSONS 超過 80 行 → 提示蒸餾' {
    $lines = 1..85 | ForEach-Object { "- 教訓 $_" }
    Set-Content -Path (Join-Path $script:root '.fable\LESSONS.md') -Value ($lines -join "`n") -Encoding utf8
    $r = Invoke-Hook 'session-brief.ps1' '{}' $script:root
    $r.StdOut | Should Match '蒸餾'
  }

  It '無 .fable 檔案 → 仍輸出基本 brief,不炸' {
    $bare = Join-Path $TestDrive ('bare-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $bare | Out-Null
    $r = Invoke-Hook 'session-brief.ps1' '{}' $bare
    $r.ExitCode | Should Be 0
    $r.StdOut | Should Match 'harness-brief'
  }
}
