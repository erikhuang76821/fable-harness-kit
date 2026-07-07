# upstream-suggestions.ps1 的黑箱測試(Pester 3.4)
# 契約:只回流 [accepted] 且未標 [upstreamed]/[local] 的條目([accepted→已入法] 不符 regex 自動排除);
# 標記以行號定位——首行相同的兩條建議,成功一條只標一條,失敗那條保持 [accepted] 可重試。
# 斷言走檔案內容而非 stdout(子行程未設 OutputEncoding,中文經主控台碼頁會髒——碼頁教訓)。

$script:ScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\upstream-suggestions.ps1'

function Invoke-Upstream {
  # 子行程執行(腳本內有 exit,不可在測試行程內 dot-source);假 gh 目錄前置到 PATH
  param([string]$Root, [string]$FakeGhDir)
  $runner = Join-Path $Root 'runner.ps1'
  @(
    "`$env:Path = '$FakeGhDir;' + `$env:Path"
    "Set-Location '$Root'"
    "& '$script:ScriptPath' -Apply"
    "exit `$LASTEXITCODE"
  ) -join "`r`n" | Set-Content -Path $runner -Encoding utf8
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner *> $null
  return $LASTEXITCODE
}

Describe 'upstream-suggestions' {
  BeforeEach {
    $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force (Join-Path $script:root '.fable') | Out-Null
    $script:sug = Join-Path $script:root '.fable\KIT-SUGGESTIONS.md'
    $script:gh = Join-Path $script:root 'fake-gh'
    New-Item -ItemType Directory -Force $script:gh | Out-Null
  }

  It '判準過濾:只回流 [accepted];pending/upstreamed/local/已入法 不動;標記只落在該條首行' {
    $ghCmd = @'
@echo off
exit /b 0
'@
    Set-Content -Path (Join-Path $script:gh 'gh.cmd') -Value $ghCmd -Encoding ascii
    $fixture = @'
# KIT-SUGGESTIONS
- [accepted] 建議A(證據:x;2026-07-07)
  續行證據
- [pending] 建議B(證據:y;2026-07-07)
- [accepted][upstreamed] 建議C(證據:z;2026-07-07)
- [accepted][local] 建議D(證據:w;2026-07-07)
- [accepted→已入法 2026-07-07] 建議E(證據:v;2026-07-07)
'@
    Set-Content -Path $script:sug -Value $fixture -Encoding utf8
    # -Apply 路徑不斷言 exit code:腳本結束前不重設 $LASTEXITCODE,殘留的是最後一次 gh 呼叫的結果
    Invoke-Upstream $script:root $script:gh | Out-Null
    $after = @(Get-Content $script:sug -Encoding utf8)
    $after[1] | Should Match '^\-\s\[accepted\]\[upstreamed\]\s建議A'
    $after[2] | Should Be '  續行證據'
    $after[3] | Should Match '^\-\s\[pending\]'
    $after[5] | Should Match '^\-\s\[accepted\]\[local\]'
    $after[6] | Should Match '已入法'
    @($after | Where-Object { $_ -match '\[upstreamed\]' }).Count | Should Be 2
  }

  It '同名首行碰撞:成功一條只標一條,失敗那條保持 [accepted] 可重試' {
    # 假 gh:auth 恆成功;第一次 issue create 成功,之後全失敗
    $ghCmd = @'
@echo off
if "%1"=="auth" exit /b 0
if exist "%~dp0gh.flag" exit /b 1
echo x > "%~dp0gh.flag"
exit /b 0
'@
    Set-Content -Path (Join-Path $script:gh 'gh.cmd') -Value $ghCmd -Encoding ascii
    $fixture = @'
# KIT-SUGGESTIONS
- [accepted] 同名建議(證據:a;2026-07-07)
- [accepted] 同名建議(證據:a;2026-07-07)
'@
    Set-Content -Path $script:sug -Value $fixture -Encoding utf8
    Invoke-Upstream $script:root $script:gh | Out-Null
    $after = @(Get-Content $script:sug -Encoding utf8)
    $after[1] | Should Match '^\-\s\[accepted\]\[upstreamed\]\s同名建議'
    $after[2] | Should Match '^\-\s\[accepted\]\s同名建議'
    @($after | Where-Object { $_ -match '\[upstreamed\]' }).Count | Should Be 1
  }

  It '無可回流條目時 exit 0,檔案不動' {
    $ghCmd = @'
@echo off
exit /b 0
'@
    Set-Content -Path (Join-Path $script:gh 'gh.cmd') -Value $ghCmd -Encoding ascii
    $fixture = @'
# KIT-SUGGESTIONS
- [pending] 建議(證據:x;2026-07-07)
'@
    Set-Content -Path $script:sug -Value $fixture -Encoding utf8
    $before = (Get-Content $script:sug -Raw -Encoding utf8)
    Invoke-Upstream $script:root $script:gh | Should Be 0
    (Get-Content $script:sug -Raw -Encoding utf8) | Should Be $before
  }
}
