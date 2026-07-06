# rule-guard.ps1 的黑箱測試(Pester 3.4)
# 契約:規則檔(CLAUDE.md / invariants.md / DECISION-CORE.md)被改 → append 留痕到 .fable/DECISIONS.md;
#       非規則檔、.fable 底下同名檔 → 不留痕。

. (Join-Path $PSScriptRoot 'TestHelper.ps1')

function New-EditPayload($filePath) {
  (@{ tool_name = 'Edit'; tool_input = @{ file_path = $filePath } } | ConvertTo-Json -Compress)
}

Describe 'rule-guard' {
  BeforeEach {
    $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $script:root | Out-Null
    $script:decisions = Join-Path $script:root '.fable\DECISIONS.md'
  }

  It '改 CLAUDE.md → DECISIONS.md 出現留痕' {
    $r = Invoke-Hook 'rule-guard.ps1' (New-EditPayload 'C:\proj\CLAUDE.md') $script:root
    $r.ExitCode | Should Be 0
    (Test-Path $script:decisions) | Should Be $true
    (Get-Content $script:decisions -Raw) | Should Match '規則檔變更'
  }

  It '改 docs\DECISION-CORE.md → 留痕(比對按檔名尾綴,搬進 docs/ 後仍有效)' {
    $r = Invoke-Hook 'rule-guard.ps1' (New-EditPayload 'C:\proj\docs\DECISION-CORE.md') $script:root
    (Test-Path $script:decisions) | Should Be $true
    (Get-Content $script:decisions -Raw) | Should Match 'DECISION-CORE'
  }

  It '改一般程式檔 → 不留痕' {
    $r = Invoke-Hook 'rule-guard.ps1' (New-EditPayload 'C:\proj\src\app.js') $script:root
    (Test-Path $script:decisions) | Should Be $false
  }

  It '改 .fable 底下的同名檔 → 不留痕(排除規則)' {
    $r = Invoke-Hook 'rule-guard.ps1' (New-EditPayload 'C:\proj\.fable\CLAUDE.md') $script:root
    (Test-Path $script:decisions) | Should Be $false
  }

  It '空 payload → 放行不留痕' {
    $r = Invoke-Hook 'rule-guard.ps1' '' $script:root
    $r.ExitCode | Should Be 0
    (Test-Path $script:decisions) | Should Be $false
  }
}
