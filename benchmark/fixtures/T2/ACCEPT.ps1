python -m pytest -q *> $null
if ($LASTEXITCODE -ne 0) { Write-Host 'FAIL: pytest'; exit 1 }
Write-Host 'PASS'; exit 0
