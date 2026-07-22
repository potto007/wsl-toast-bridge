# Install

## Prerequisites

BurntToast must be installed for **PowerShell 7** specifically — PowerShell 5.1
uses a different module path and won't find it:

```powershell
Install-Module BurntToast -Scope CurrentUser
```

## Run the installer

```bash
git clone https://github.com/ClearBridgeRIP/wsl-toast-bridge
cd wsl-toast-bridge
./install.sh
toast "Hello" "from the WSL toast bridge"
```

## What it does

| Step | Destination |
| --- | --- |
| Copies `bin/*` | `~/.local/bin/` |
| Stages the click handler (rewrites `$HOME`) | `%LOCALAPPDATA%\herdr-toast\focus.ps1` |
| Registers the `herdr-focus:` URL protocol | `HKCU\Software\Classes` — no admin |
| Fetches the Herdr logo, draws the warning icon | `~/.local/share/toast-icons/` |

!!! note "Why `~/.local/bin` and not a shell function"
    An executable is visible everywhere a function isn't: non-interactive
    shells, Claude Code hooks, cron, systemd units. A shell function defined in
    `.zshrc` is visible only to your interactive zsh.

The installer is idempotent — re-run it to pick up changes after `git pull`.

## Herdr integration

Set this in `~/.config/herdr/config.toml`:

```toml
[ui.toast]
delivery = "system"
```

Herdr then spawns `notify-send`, which the shim intercepts. Logo and pane
matching are automatic; no further configuration.

## Verify

```bash
toast "Test" "should appear bottom-right"          # (1)!
TOAST_DRY_RUN=1 toast -p w1:p1 "Dry" "run"         # (2)!
herdr notification show "Herdr test" --body "via shim"   # (3)!
```

1. A toast appears. Clicking it focuses Windows Terminal, no PowerShell window.
2. Prints the PowerShell command instead of firing — the fastest way to check
   quoting and path conversion.
3. End-to-end through the shim. Check `~/.local/state/notify-send-shim.log` to
   confirm the call arrived.

## Uninstall

```bash
rm ~/.local/bin/{toast,notify-send,herdr-focus-pane}
rm -rf ~/.local/share/toast-icons "$(wslpath "$(pwsh.exe -NoProfile -Command 'Write-Output $env:LOCALAPPDATA' | tr -d '\r')")/herdr-toast"
pwsh.exe -NoProfile -Command "Remove-Item -Recurse 'HKCU:\Software\Classes\herdr-focus'"
```
