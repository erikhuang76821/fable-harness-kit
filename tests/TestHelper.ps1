# 測試共用:以子行程執行 hook(hooks 讀 [Console]::In,必須真的餵 stdin),回傳 exit code 與輸出
# Pester 3.4 相容(Windows PowerShell 5.1 內建版)

$script:HooksDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.claude\hooks'

function Invoke-Hook {
  param(
    [Parameter(Mandatory = $true)][string]$HookName,             # 例:'git-guard.ps1'
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$StdinJson,  # 餵給 hook 的 payload(空字串合法:測 fail-open)
    [string]$WorkingDir = (Get-Location).Path          # hooks 用相對路徑,cwd 決定行為
  )
  $hookPath = Join-Path $script:HooksDir $HookName
  if (-not (Test-Path $hookPath)) { throw "hook 不存在:$hookPath" }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'powershell.exe'
  $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$hookPath`""
  $psi.WorkingDirectory = $WorkingDir
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

  $p = [System.Diagnostics.Process]::Start($psi)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $writer = New-Object System.IO.StreamWriter($p.StandardInput.BaseStream, $utf8NoBom)
  $writer.Write($StdinJson)
  $writer.Close()
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  return @{ ExitCode = $p.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

function New-KitDir {
  # 在指定位置佈一個最小 kit 標記(hooks 以 .claude/workflows/fable-emu.js 判定 kit 專案)
  param([Parameter(Mandatory = $true)][string]$Root)
  New-Item -ItemType Directory -Force (Join-Path $Root '.claude\workflows') | Out-Null
  Set-Content -Path (Join-Path $Root '.claude\workflows\fable-emu.js') -Value '// marker' -Encoding utf8
}

function New-Transcript {
  # 產生假 transcript(JSONL,單行 tool_use 假設與正式格式一致)
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$Lines
  )
  Set-Content -Path $Path -Value ($Lines -join "`n") -Encoding utf8
}
