# git-guard.ps1 的黑箱測試(Pester 3.4):危險指令 exit 2 + stderr 訊息;安全指令 exit 0
# 含旗標位置變形與繞過樣本——regex 閘門是 best-effort,這些案例定義它「至少要擋住什麼」

. (Join-Path $PSScriptRoot 'TestHelper.ps1')

function New-CmdPayload($cmd) {
  (@{ tool_name = 'Bash'; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress)
}

Describe 'git-guard 危險指令(必須 exit 2)' {
  $dangerous = @(
    'git push --force',
    'git push -f origin main',
    'git push origin main --force-with-lease',
    'git -C C:\repo push -f',
    'git reset --hard HEAD~3',
    'git clean -fd',
    'git branch -D feature-x',
    'git checkout -- .',
    'git stash drop',
    'git stash clear',
    'git rebase -i HEAD~5',
    'rm -rf /etc/config',
    'rm -fr ~/project',
    'rm -rf C:/Users/x/repo',
    'Remove-Item -Recurse -Force C:\repo',
    'Remove-Item -Recurse -Force -WhatIf:$false C:\repo',   # 顯式關掉 dry-run = 真刪,不得豁免
    'rd /s C:\repo'
  )
  foreach ($cmd in $dangerous) {
    It "擋:$cmd" {
      $r = Invoke-Hook 'git-guard.ps1' (New-CmdPayload $cmd)
      $r.ExitCode | Should Be 2
      $r.StdErr | Should Match 'BLOCKED'
    }
  }
}

Describe 'git-guard 安全指令(必須 exit 0)' {
  $safe = @(
    'git push origin main',
    'git reset --soft HEAD~1',
    'git branch -d merged-branch',   # 小寫 -d(刪已合併)是安全的,不可與 -D 混判
    'git checkout main',
    'git stash list',
    'git rebase main',
    'rm -r ./local-tmp',             # 無 -f
    'rm -f single-file.txt',         # 無 -r 且非根路徑
    'Remove-Item -Recurse .\tmp',    # 無 -Force
    'Remove-Item -Recurse -Force -WhatIf C:\repo',        # dry-run 合法
    'Remove-Item -Recurse -Force -WhatIf:$true C:\repo',  # 顯式 dry-run 亦合法
    'Remove-Item -Recurse -Force .\build',                # 相對路徑
    'git status'
  )
  foreach ($cmd in $safe) {
    It "放:$cmd" {
      $r = Invoke-Hook 'git-guard.ps1' (New-CmdPayload $cmd)
      $r.ExitCode | Should Be 0
    }
  }
}

Describe 'git-guard 邊界' {
  It '空 payload → 放行' {
    $r = Invoke-Hook 'git-guard.ps1' ''
    $r.ExitCode | Should Be 0
  }
  It '非 JSON → 放行(fail-open,防 hook 自身壞掉癱瘓工具)' {
    $r = Invoke-Hook 'git-guard.ps1' 'not-json'
    $r.ExitCode | Should Be 0
  }
  It '無 command 欄位 → 放行' {
    $r = Invoke-Hook 'git-guard.ps1' ((@{ tool_name = 'Bash'; tool_input = @{} } | ConvertTo-Json -Compress))
    $r.ExitCode | Should Be 0
  }
}
