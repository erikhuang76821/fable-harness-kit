# prompt-nudge.ps1 的黑箱測試(Pester 3.4)
# 契約:輸出 UserPromptSubmit additionalContext JSON(含 <nudge>);.claude/nudge-off 存在時靜默退出。

. (Join-Path $PSScriptRoot 'TestHelper.ps1')

Describe 'prompt-nudge' {
  BeforeEach {
    $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force (Join-Path $script:root '.claude') | Out-Null
  }

  It '正常輸出:JSON 含 UserPromptSubmit 與 nudge 標籤(ConvertTo-Json 會把 < 轉義為 <)' {
    $r = Invoke-Hook 'prompt-nudge.ps1' '{}' $script:root
    $r.ExitCode | Should Be 0
    $r.StdOut | Should Match 'UserPromptSubmit'
    $r.StdOut | Should Match 'additionalContext'
    $r.StdOut | Should Match '(<nudge>|\\u003cnudge\\u003e)'
  }

  It '輪播內容屬於既定四句之一' {
    $r = Invoke-Hook 'prompt-nudge.ps1' '{}' $script:root
    $r.StdOut | Should Match '(證據先於宣稱|交付優先|動工前|慢下來訊號)'
  }

  It '關閉開關:.claude/nudge-off 存在 → 靜默退出、零輸出' {
    Set-Content -Path (Join-Path $script:root '.claude\nudge-off') -Value '' -Encoding utf8
    $r = Invoke-Hook 'prompt-nudge.ps1' '{}' $script:root
    $r.ExitCode | Should Be 0
    $r.StdOut.Trim() | Should Be ''
  }
}
