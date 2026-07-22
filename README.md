# wsl-toast-bridge

Native Windows toast notifications from WSL, with click-to-focus back to your
terminal and the exact [Herdr](https://herdr.dev) pane the notification came from.

```
herdr / any tool ──▶ notify-send shim ──▶ toast ──▶ BurntToast (pwsh7)
                                                        │
    Windows Terminal + herdr pane focused ◀── click ────┘
                (herdr-focus: protocol)
```

## What you get

- **`toast`** - fire a Windows toast from any WSL shell, script, cron job, or
  systemd unit: `toast [-i IMAGE] [-p HERDR_PANE] "Title" "Body"`.
- **`notify-send` shim** - anything that speaks freedesktop notifications
  (Herdr's `delivery = "system"`, CI scripts, other TUIs) lands on the Windows
  desktop instead of vanishing into a D-Bus daemon WSL doesn't have.
- **Click-to-focus** - clicking a toast focuses Windows Terminal instead of
  opening a stray PowerShell window. Toasts sent for a Herdr agent also jump
  Herdr to that agent's pane.
- **Branding** - Herdr-originated toasts get the Herdr logo automatically;
  pass `-i` for anything else. Images work from both Windows paths and WSL
  paths (`wslpath -w` conversion, `\\wsl.localhost` UNC renders fine).

## Requirements

- Windows 10/11, WSL2
- PowerShell 7 (`pwsh.exe` reachable from WSL PATH)
- [BurntToast](https://github.com/Windos/BurntToast):
  `Install-Module BurntToast -Scope CurrentUser`
- python3 + Pillow (only to draw the bundled warning icon)
- [Herdr](https://herdr.dev) for the pane-focus features (everything else
  works without it)

## Install

```bash
./install.sh
toast "Hello" "from the WSL toast bridge"
```

The installer copies `bin/` to `~/.local/bin`, stages the click handler to
`%LOCALAPPDATA%\herdr-toast\focus.ps1`, registers the `herdr-focus:` URL
protocol under HKCU (no admin), fetches the Herdr logo, and draws the warning
icon into `~/.local/share/toast-icons/`.

## Usage

```bash
toast "Build complete"
toast "Build failed" "Check the logs"
toast -i ~/.local/share/toast-icons/warning.png "[critical] GpuSpill" "VRAM spill active"
toast -p w6:p1 "Agent done" "clicking focuses that herdr pane"
TOAST_DRY_RUN=1 toast "Debug" "prints the PowerShell instead of firing"
```

With Herdr, set:

```toml
[ui.toast]
delivery = "system"
```

and its notifications route through the shim automatically - logo, pane
matching and all. The shim identifies Herdr by parent process and resolves the
target pane by matching notification text against `herdr agent list` titles
and repo directory names; if the match isn't unique it falls back to
focusing just the terminal (Herdr's `prefix+o` covers the rest).

## Hard-won details

Three failure modes are baked into the design; all were hit live:

1. **`wsl.exe` silently no-ops in a hidden window.** A protocol handler runs
   with no console, and `wsl.exe` exits 0 having done nothing. `focus.ps1`
   launches it with explicitly redirected stdio pipes, which makes it run.
2. **Bad image paths warn and exit 0.** BurntToast falls back to the default
   icon without failing, so nothing in the exit code tells you the logo is
   missing. `toast` converts WSL paths with `wslpath -w` and warns to stderr
   on non-files; every stage of the chain logs
   (`~/.local/state/notify-send-shim.log`, `~/.local/state/herdr-focus-pane.log`,
   `%LOCALAPPDATA%\herdr-toast\focus.log`).
3. **Registering the versioned pwsh path breaks on update.** The protocol
   registration uses the stable
   `%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe` alias, not the
   `WindowsApps\Microsoft.PowerShell_7.x...` package path that
   `(Get-Command pwsh).Source` returns.

Why not `New-BurntToastNotification`? It hardcodes toast activation to the
PowerShell AppId - clicking opens a PowerShell window. `toast` builds content
via `New-BTContent -ActivationType Protocol -Launch herdr-focus:...` so the
click dispatches to the registered handler instead.

## Docs

Full documentation lives in [`docs/`](docs/) and builds with Material for MkDocs:

```bash
python3 -m venv .venv-docs
.venv-docs/bin/pip install -r requirements-docs.txt
.venv-docs/bin/mkdocs serve     # http://127.0.0.1:8000
.venv-docs/bin/mkdocs build     # static site into site/
```

Pages: [overview](docs/index.md) · [install](docs/install.md) ·
[usage](docs/usage.md) · [architecture](docs/architecture.md) ·
[gotchas](docs/gotchas.md)
