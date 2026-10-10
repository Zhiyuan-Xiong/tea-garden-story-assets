$teaProject = $PSScriptRoot
$teaGodot = 'D:\下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $teaGodot)) { throw '未找到 Godot，请使用 Godot 4.7.2 导入此目录的 project.godot。' }
Start-Process -FilePath $teaGodot -ArgumentList @('--editor', '--path', ('"' + $teaProject + '"'), 'res://scenes/areas/home.tscn') -WorkingDirectory $teaProject -WindowStyle Normal
