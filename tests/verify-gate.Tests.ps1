# verify-gate.ps1 的黑箱測試(Pester 3.4)
# 契約:kit 專案內、本 session 改過程式檔、無測試指令痕跡、無「已修改、未驗證」聲明 → block 一次;其餘放行。

. (Join-Path $PSScriptRoot 'TestHelper.ps1')

function New-Payload($transcript, $stopActive = $false) {
  (@{ transcript_path = $transcript; stop_hook_active = $stopActive } | ConvertTo-Json -Compress)
}

$EDIT_PS1  = '{"type":"assistant","name":"Edit","input":{"file_path":"C:\\proj\\src\\app.ps1","old_string":"a","new_string":"b"}}'
$EDIT_MD   = '{"type":"assistant","name":"Write","input":{"file_path":"C:\\proj\\notes\\README.md","content":"x"}}'
$EDIT_DOCKER = '{"type":"assistant","name":"Edit","input":{"file_path":"C:\\proj\\Dockerfile","old_string":"a","new_string":"b"}}'
$EDIT_NB   = '{"type":"assistant","name":"NotebookEdit","input":{"notebook_path":"C:\\proj\\analysis.ipynb","new_source":"x"}}'
$RUN_PYTEST = '{"type":"assistant","name":"Bash","input":{"command":"python -m pytest tests/ -v"}}'
$RUN_PESTER = '{"type":"assistant","name":"PowerShell","input":{"command":"Invoke-Pester -Path tests"}}'
$RUN_CHAINED = '{"type":"assistant","name":"Bash","input":{"command":"cd src && pytest -q"}}'
$RUN_FAKE   = '{"type":"assistant","name":"Bash","input":{"command":"cat latest.log && echo contest"}}'
$MENTION_ONLY = '{"type":"assistant","name":"Bash","input":{"command":"echo pytest 稍後再跑 && rg pytest docs/"}}'
$DECLARED   = '{"type":"assistant","text":"變更完成。已修改、未驗證(無對應測試環境)。"}'

Describe 'verify-gate' {
  BeforeEach {
    $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $script:root | Out-Null
    New-KitDir -Root $script:root
    $script:tpath = Join-Path $script:root 'transcript.jsonl'
  }

  It '改了程式檔且無測試痕跡 → block' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_PS1)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.ExitCode | Should Be 0
    $r.StdOut | Should Match '"decision"\s*:\s*"block"'
  }

  It '改了程式檔但跑過 pytest → 放行' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_PS1, $RUN_PYTEST)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '改了程式檔但跑過 Invoke-Pester → 放行' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_PS1, $RUN_PESTER)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '繞過樣本:指令含 latest/contest 字樣不算測試 → 仍 block' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_PS1, $RUN_FAKE)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Match '"decision"\s*:\s*"block"'
  }

  It '只改 .md 文件 → 放行(不逼文件改動跑測試)' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_MD)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '已聲明「已修改、未驗證」 → 放行(誠實豁免)' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_PS1, $DECLARED)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It 'stop_hook_active=true → 放行(防無限迴圈)' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_PS1)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath $true) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '非 kit 專案 → 放行' {
    $bare = Join-Path $TestDrive ('bare-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $bare | Out-Null
    $tp = Join-Path $bare 't.jsonl'
    New-Transcript -Path $tp -Lines @($EDIT_PS1)
    $r = Invoke-Hook 'verify-gate.ps1' ((@{ transcript_path = $tp; stop_hook_active = $false } | ConvertTo-Json -Compress)) $bare
    $r.StdOut | Should Not Match 'block'
  }

  It 'transcript 不存在 → 放行(fail-open,不擋正常收尾)' {
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload (Join-Path $script:root 'no-such.jsonl')) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '無任何修改 → 放行' {
    New-Transcript -Path $script:tpath -Lines @($RUN_FAKE)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '順序判準:先測後改(測試在修改之前)→ 仍 block' {
    New-Transcript -Path $script:tpath -Lines @($RUN_PYTEST, $EDIT_PS1)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Match '"decision"\s*:\s*"block"'
  }

  It '假證據:echo pytest / rg pytest 只是提到測試字樣 → 仍 block' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_PS1, $MENTION_ONLY)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Match '"decision"\s*:\s*"block"'
  }

  It '鏈式指令:cd src && pytest(token 在分隔符後)→ 放行' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_PS1, $RUN_CHAINED)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Not Match 'block'
  }

  It '無副檔名程式檔:改 Dockerfile 無測試 → block' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_DOCKER)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Match '"decision"\s*:\s*"block"'
  }

  It 'NotebookEdit 也算程式修改 → 無測試則 block' {
    New-Transcript -Path $script:tpath -Lines @($EDIT_NB)
    $r = Invoke-Hook 'verify-gate.ps1' (New-Payload $script:tpath) $script:root
    $r.StdOut | Should Match '"decision"\s*:\s*"block"'
  }
}
