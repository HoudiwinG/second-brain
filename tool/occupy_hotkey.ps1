# Тестовый helper для ручного сценария R02-009: занимает глобальную
# комбинацию через Win32 RegisterHotKey и держит её, пока процесс жив.
# В продакшене не используется.
#
# Пример:
#   powershell -ExecutionPolicy Bypass -File tool\occupy_hotkey.ps1 -Key B -Ctrl -Alt -ReadyFile .\build\hotkey_ready.txt
#
# Остановить: Close/Stop-Process по PID, указанному в ReadyFile.

param(
    [string]$Key = "B",
    [switch]$Ctrl,
    [switch]$Alt,
    [switch]$Shift,
    [switch]$Win,
    [string]$ReadyFile
)

$ErrorActionPreference = "Stop"

if (-not ($Ctrl -or $Alt -or $Shift -or $Win)) {
    $Ctrl = $true
    $Alt = $true
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class SecondBrainHotkeyProbe
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
"@

$modifiers = [uint32]0
if ($Ctrl) { $modifiers = $modifiers -bor 0x0002 }   # MOD_CONTROL
if ($Alt) { $modifiers = $modifiers -bor 0x0001 }    # MOD_ALT
if ($Shift) { $modifiers = $modifiers -bor 0x0004 }  # MOD_SHIFT
if ($Win) { $modifiers = $modifiers -bor 0x0008 }    # MOD_WIN

$trimmed = $Key.Trim().ToUpperInvariant()
if ($trimmed.Length -ne 1 -or -not ($trimmed -match "^[A-Z0-9]$")) {
    throw "Поддерживается одна буква A-Z или цифра 0-9, получено: '$Key'"
}
$virtualKey = [uint32][char]$trimmed

$hotkeyId = 0x5EC0  # произвольный id, не пересекается с hotkey_manager
if (-not [SecondBrainHotkeyProbe]::RegisterHotKey([IntPtr]::Zero, $hotkeyId, $modifiers, $virtualKey)) {
    $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "RegisterHotKey не удался (Win32 error $code). Комбинация уже занята?"
}

try {
    Write-Host "Занято: $trimmed (modifiers=$modifiers), PID=$PID"
    if ($ReadyFile) {
        Set-Content -Path $ReadyFile -Value $PID -Encoding utf8
    }
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    [void][SecondBrainHotkeyProbe]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId)
    if ($ReadyFile -and (Test-Path $ReadyFile)) {
        Remove-Item $ReadyFile -Force
    }
}
