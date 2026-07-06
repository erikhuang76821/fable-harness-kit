python -m pytest -q *> $null
if ($LASTEXITCODE -ne 0) { Write-Host 'FAIL: pytest'; exit 1 }
if (-not (Test-Path 'validators.py')) { Write-Host 'FAIL: validators.py 不存在'; exit 1 }
if (-not (Select-String -Path 'validators.py' -Pattern 'def is_valid_email' -Quiet)) { Write-Host 'FAIL: validators.py 缺 is_valid_email'; exit 1 }
foreach ($f in @('users.py', 'orders.py')) {
  if (-not (Select-String -Path $f -Pattern 'from validators import|import validators' -Quiet)) { Write-Host "FAIL: $f 未改用 validators"; exit 1 }
}
Write-Host 'PASS'; exit 0
