# herdr-focus: protocol handler. Invoked when a BurntToast notification is
# clicked. Focuses the Windows Terminal window, then (if the URI names a herdr
# pane) asks herdr inside WSL to focus that pane.
param([string]$Uri = 'herdr-focus:')

$log = "$env:LOCALAPPDATA\herdr-toast\focus.log"
"$(Get-Date -Format o) uri=$Uri" | Add-Content -Path $log

$target = $Uri -replace '^herdr-focus:', '' -replace '/+$', ''

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
}
"@

# ponytail: first WT window wins; disambiguate by MainWindowTitle if a second
# Windows Terminal window ever becomes part of the workflow
$wt = Get-Process WindowsTerminal -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if ($wt) {
  if ([WinAPI]::IsIconic($wt.MainWindowHandle)) {
    [WinAPI]::ShowWindowAsync($wt.MainWindowHandle, 9) | Out-Null  # SW_RESTORE
  }
  [WinAPI]::SetForegroundWindow($wt.MainWindowHandle) | Out-Null
  "$(Get-Date -Format o) focused WT pid=$($wt.Id)" | Add-Content -Path $log
} else {
  "$(Get-Date -Format o) no WindowsTerminal window found" | Add-Content -Path $log
}

if ($target) {
  # bare wsl.exe silently no-ops in a hidden window (no console); explicit
  # redirected pipes give it stdio handles and make it run (observed 2026-07-22)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "$env:SystemRoot\System32\wsl.exe"
  $psi.Arguments = "-- __WSL_HOME__/.local/bin/herdr-focus-pane $target"
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  $p = [System.Diagnostics.Process]::Start($psi)
  $p.WaitForExit(10000) | Out-Null
  "$(Get-Date -Format o) pane=$target wsl exit=$($p.ExitCode) err=$($p.StandardError.ReadToEnd())" | Add-Content -Path $log
}
