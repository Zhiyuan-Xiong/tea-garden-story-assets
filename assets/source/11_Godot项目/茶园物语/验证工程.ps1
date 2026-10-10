$teaProject = $PSScriptRoot
$teaGodot = 'D:\下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $teaGodot --headless --path $teaProject res://tests/test_runner.tscn --log-file (Join-Path $teaProject 'logs\verification.log')
if ($LASTEXITCODE -ne 0) { throw '玩法或文字检查失败，请查看验证报告。' }
$teaRuntimeIssues = Select-String -LiteralPath (Join-Path $teaProject 'logs\verification.log') -Pattern 'SCRIPT ERROR:|^ERROR:|^WARNING:'
if ($teaRuntimeIssues) { throw '引擎运行日志包含问题，请查看 verification.log。' }
& $teaGodot --headless --path $teaProject res://tests/restart_runner.tscn --log-file (Join-Path $teaProject 'logs\restart.log')
if ($LASTEXITCODE -ne 0) { throw '重新启动读档验证失败。' }
Write-Host '玩法、布局与重新启动读档检查通过。'
