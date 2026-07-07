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

  It '編碼契約:CP950 主控台下輸出位元組仍為 UTF-8(2026-07-07 dogfood 亂碼回歸鎖)' {
    # 測試盲區的教訓:一般 Invoke-Hook 繼承本 harness 的主控台碼頁,測不出 Claude Code
    # spawn 環境(預設碼頁)下的亂碼——此案例強制 CP950 再收原始位元組驗證。
    # chcp 作用於「共享主控台」:必須保存/還原,不得留下全域副作用
    $orig = [int]((cmd /c chcp) -replace '\D', '')
    try {
      $hook = Join-Path (Split-Path $PSScriptRoot -Parent) '.claude\hooks\prompt-nudge.ps1'
      $tmp = Join-Path $TestDrive 'nudge-bytes.bin'
      cmd /d /c "chcp 950 >nul & powershell -NoProfile -ExecutionPolicy Bypass -File `"$hook`" > `"$tmp`""
      $text = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($tmp))
      $text | Should Match '(證據先於宣稱|交付優先|動工前|慢下來訊號)'
    } finally {
      cmd /c "chcp $orig >nul"
    }
  }
}
