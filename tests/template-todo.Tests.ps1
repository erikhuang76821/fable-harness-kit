# 模板 TODO 標記的契約測試(Pester 3.4)
# 契約:init.ps1 與 scripts/doctor.ps1 以 'TODO\(' 偵測模板未填;
# 因此四個被掃描的模板中,任何 TODO 字樣都必須是正典的 TODO( 形式——
# 不論寫成「TODO 範例:」「(TODO:」、裸 TODO、todo(、全形括號,都會被生產 regex 漏掉。
# (歷史事故:invariants 模板寫「TODO 範例:」導致 doctor 對未填模板誤報全綠,
#  2026-07-07 RedmineCatch 整合實證;跨模型審查再抓到 CONTEXT.md 表格的裸 TODO 同類殘留。)

$kitRoot = Split-Path $PSScriptRoot -Parent
$scanned = @('CLAUDE.md', 'CONTEXT.md', 'docs\invariants.md', 'docs\DECISION-CORE.md')

Describe 'template-todo' {
  It '掃描規則同步:init.ps1 與 doctor.ps1 都仍用 TODO\( 偵測' {
    (Get-Content (Join-Path $kitRoot 'init.ps1') -Raw) | Should Match "TODO\\\("
    (Get-Content (Join-Path $kitRoot 'scripts\doctor.ps1') -Raw) | Should Match "TODO\\\("
  }

  foreach ($rel in $scanned) {
    It "$rel 未填模板必須可被偵測(至少 1 個 TODO( 標記)" {
      $raw = Get-Content (Join-Path $kitRoot $rel) -Raw
      ([regex]::Matches($raw, 'TODO\(')).Count | Should BeGreaterThan 0
    }

    It "$rel 的每個 TODO 字樣都必須是正典 TODO( 形式(否則生產 regex 看不見)" {
      $raw = Get-Content (Join-Path $kitRoot $rel) -Raw
      $anyForm = ([regex]::Matches($raw, '(?i)todo')).Count
      $canonical = ([regex]::Matches($raw, 'TODO\(')).Count
      $anyForm | Should Be $canonical
    }
  }
}
