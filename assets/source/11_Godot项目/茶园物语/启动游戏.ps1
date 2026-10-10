$teaProject = $PSScriptRoot
$teaGodot = 'D:\下载\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $teaGodot)) { throw '未找到 Godot，请使用 Godot 4.7.2 导入工程并按 F5。' }
Start-Process -FilePath $teaGodot -ArgumentList @('--path', ('"' + $teaProject + '"')) -WorkingDirectory $teaProject -WindowStyle Normal
