# stop-retro-gate.ps1 的黑箱測試(Pester 3.4)
# 契約:kit 專案內、session 有修改、沒寫過教訓也沒聲明「檢討:無」→ block 一次;其餘放行。

. (Join-Path $PSScriptRoot 'TestHelper.ps1')

function New-Payload($transcript, $stopActive = $false) {
  (@{ transcript_path = $transcript; stop_hook_active = $stopActive } | ConvertTo-Json -Compress)
}

$EDIT_LINE    = '{"type":"assistant","name":"Edit","input":{"file_path":"C:\\proj\\src\\app.js"}}'
$LESSON_WRITE = '{"type":"assistant","name":"Write","input":{"file_path":"C:\\proj\\.fable\\LESSONS.md","content":"x"}}'
$LESSON_READ  = '{"type":"assistant","name":"Read","input":{"file_path":"C:\\proj\\.fable\\LESSONS.md"}}'
$DECLARED     = '{"type":"assistant","text":"收尾。檢討:無"}'

Describe 'stop-retro-gate' {
  BeforeEach {
    $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $script:root | Out-Null
    New-KitDir -Root $script:root
    $script:tpath = Join-Path $script:root 'transcript.jsonl'
  }

  It '有修改、無檢討、無聲明 → block' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_LINE)
    $r = Invoke-Hook 'stop-retro-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Match '"decision"\s*:\s*"block"'
  }

  It '有修改且寫過 LESSONS → 放行' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_LINE, $LESSON_WRITE)
    $r = Invoke-Hook 'stop-retro-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '誤放行防護:只 Read 過 LESSONS(未寫)不算檢討 → 仍 block' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_LINE, $LESSON_READ)
    $r = Invoke-Hook 'stop-retro-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Match '"decision"\s*:\s*"block"'
  }

  It '聲明「檢討:無」 → 放行' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_LINE, $DECLARED)
    $r = Invoke-Hook 'stop-retro-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '無修改 → 放行' {
    New-Transcript -Path $script:tpath -Lines @('{"type":"assistant","text":"純問答"}')
    $r = Invoke-Hook 'stop-retro-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It 'stop_hook_active=true → 放行(防無限迴圈)' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_LINE)
    $r = Invoke-Hook 'stop-retro-gate.ps1' (New-Payload $script:tpath $true) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '非 kit 專案 → 放行' {
    $bare = Join-Path $TestDrive ('bare-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $bare | Out-Null
    $tp = Join-Path $bare 't.jsonl'
    New-Transcript -Path $tp -Lines @($EDIT_LINE)
    $r = Invoke-Hook 'stop-retro-gate.ps1' (New-Payload $tp) $bare
    $r.StdOut | Should Not Match 'block'
  }
}
