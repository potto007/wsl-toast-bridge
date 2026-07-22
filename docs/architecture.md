# Architecture

Two independent halves: sending a toast (WSL → Windows) and handling a click
(Windows → WSL). They meet at a URI string embedded in the notification.

## Outbound: WSL to the Windows desktop

```mermaid
sequenceDiagram
  autonumber
  participant H as herdr (WSL)
  participant N as notify-send shim (WSL)
  participant T as toast (WSL)
  participant P as pwsh7 + BurntToast (Windows)

  H->>N: notify-send -- SUMMARY BODY
  Note over N: parent is herdr →<br/>add logo, resolve pane
  N->>T: toast -i herdr.png -p w6:p1 "…" "…"
  Note over T: wslpath -w on the image
  T->>P: Submit-BTNotification<br/>-ActivationType Protocol<br/>-Launch herdr-focus:w6:p1
  P-->>P: toast appears
```

## Inbound: click to terminal and pane

```mermaid
sequenceDiagram
  autonumber
  participant U as You
  participant W as Windows shell
  participant F as focus.ps1 (hidden pwsh)
  participant L as herdr-focus-pane (WSL)
  participant HD as herdr server

  U->>W: click the toast
  W->>F: dispatch herdr-focus:w6:p1 (HKCU)
  F->>F: SetForegroundWindow(WindowsTerminal)
  Note over F: SW_RESTORE first if minimized
  F->>L: wsl.exe (redirected stdio)
  L->>HD: herdr agent focus w6:p1
  HD-->>U: pane focused
```

## Components

| File | Side | Role |
| --- | --- | --- |
| `bin/toast` | WSL | Builds and submits the notification |
| `bin/notify-send` | WSL | freedesktop shim; branding + pane matching |
| `bin/herdr-focus-pane` | WSL | Wraps `herdr agent focus`, logs (caller is windowless) |
| `windows/focus.ps1` | Windows | `herdr-focus:` handler: foreground WT, call back into WSL |
| `install.sh` | — | Deploys bins, stages handler, registers protocol, makes icons |

## Why not `New-BurntToastNotification`?

It pins toast activation to the PowerShell AppId — the click *is* "launch
PowerShell". The fix is one layer down in the same module:

```powershell
$c = @(New-BTText -Text 'Title'; New-BTText -Text 'Body')
$b = New-BTBinding -Children $c -AppLogoOverride (New-BTImage -Source $img -AppLogoOverride)
Submit-BTNotification -Content (New-BTContent `
  -Visual (New-BTVisual -BindingGeneric $b) `
  -ActivationType Protocol `
  -Launch 'herdr-focus:w6:p1')      # (1)!
```

1. Any registered URL protocol works here. That single string is the entire
   contract between the two halves of the system.

Same toast, same images, controllable click.

## Observability

Every hop logs, because the failure mode of this system is silence — a hidden
window and a `0` exit code.

| Log | Written by |
| --- | --- |
| `~/.local/state/notify-send-shim.log` | shim (full argv, quoted) |
| `~/.local/state/herdr-focus-pane.log` | WSL focus helper + herdr's JSON reply |
| `%LOCALAPPDATA%\herdr-toast\focus.log` | Windows handler: URI, WT pid, wsl exit |

## Design constraints

!!! info "Host-side only"
    A Docker container has no WSL interop and cannot exec a Windows binary,
    even with `/mnt/c` mounted — the file is visible but `exec` fails. Anything
    routing notifications from a container must hand off to a host-side process
    first. (See local-ai ADR-0009, the incident this rule came from.)
