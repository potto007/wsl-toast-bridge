#!/usr/bin/env bash
# Installs the WSL toast bridge:
#   bin/*            -> ~/.local/bin
#   windows/focus.ps1 -> %LOCALAPPDATA%\herdr-toast (with this $HOME baked in)
#   herdr-focus:     -> HKCU protocol registration
#   icons            -> ~/.local/share/toast-icons (herdr logo fetched, warning drawn)
# Requires: pwsh7 + BurntToast on Windows, python3+PIL for the warning icon.
set -euo pipefail
cd "$(dirname "$0")"

PWSH="${TOAST_PWSH:-$(command -v pwsh.exe)}"
[ -n "$PWSH" ] || { echo "pwsh.exe not on PATH; set TOAST_PWSH" >&2; exit 1; }
"$PWSH" -NoProfile -Command "if (-not (Get-Module -ListAvailable BurntToast)) { Write-Error 'BurntToast not installed: Install-Module BurntToast -Scope CurrentUser'; exit 1 }" >/dev/null

install -Dm755 bin/toast bin/notify-send bin/herdr-focus-pane -t ~/.local/bin/

mkdir -p ~/.local/share/toast-icons
[ -f ~/.local/share/toast-icons/herdr.png ] || \
  curl -sf https://herdr.dev/assets/logo.png -o ~/.local/share/toast-icons/herdr.png || \
  echo "warn: could not fetch herdr logo; herdr toasts will be unbranded" >&2
[ -f ~/.local/share/toast-icons/warning.png ] || \
  python3 icons/make-warning-icon.py ~/.local/share/toast-icons/warning.png

WINHOME=$("$PWSH" -NoProfile -Command 'Write-Output $env:LOCALAPPDATA' | tr -d '\r')
HANDLER_DIR=$(wslpath "$WINHOME")/herdr-toast
mkdir -p "$HANDLER_DIR"
sed "s|__WSL_HOME__|$HOME|g" windows/focus.ps1 > "$HANDLER_DIR/focus.ps1"

"$PWSH" -NoProfile -Command '
$root = "HKCU:\Software\Classes\herdr-focus"
New-Item -Path "$root\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path $root -Name "(default)" -Value "URL:herdr-focus"
Set-ItemProperty -Path $root -Name "URL Protocol" -Value ""
$pwsh = "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"   # stable alias, survives pwsh updates
$handler = "$env:LOCALAPPDATA\herdr-toast\focus.ps1"
Set-ItemProperty -Path "$root\shell\open\command" -Name "(default)" -Value "`"$pwsh`" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$handler`" `"%1`""
' >/dev/null

echo "installed. try: toast \"Hello\" \"from the WSL toast bridge\""
