# Gotchas

Three failure modes are baked into the design. All were hit live while building
this; each cost real debugging time.

## 1. `wsl.exe` silently no-ops in a hidden window

A URL protocol handler runs with **no console**. From there, bare `wsl.exe`
exits `0` having run nothing at all — no error, no output, no clue.

??? failure "The symptom"
    The Windows-side log showed the handler firing and Windows Terminal coming
    to the front, but the WSL helper's log stayed empty. The same `wsl.exe`
    command run from a visible console worked every time.

    ```
    2026-07-22T08:05:13 uri=herdr-focus:w4:p1
    2026-07-22T08:05:14 focused WT pid=23512
    2026-07-22T08:05:15 pane=w4:p1 wsl=          ← empty, exit 0
    ```

Give it stdio handles explicitly:

```powershell
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName  = "$env:SystemRoot\System32\wsl.exe"
$psi.Arguments = "-- /home/you/.local/bin/herdr-focus-pane $target"
$psi.UseShellExecute        = $false
$psi.RedirectStandardOutput = $true   # (1)!
$psi.RedirectStandardError  = $true
$psi.CreateNoWindow         = $true
$p = [System.Diagnostics.Process]::Start($psi)
```

1. The redirection is the fix, not an afterthought for logging. Without a pipe
   to attach to, `wsl.exe` has nowhere to put its stdio and quietly does
   nothing.

## 2. A bad image path warns and exits 0

BurntToast checks the file, prints a warning, and **succeeds anyway**:

```
WARNING: The image source '/mnt/c/Windows/...' doesn't exist, failed back to icon.
```

A `/mnt/c/...` path is invisible to Windows — the image must be a Windows path.
`toast` converts with `wslpath -w`, which handles both cases:

| You pass | Windows sees |
| --- | --- |
| `/mnt/c/foo/bar.png` | `C:\foo\bar.png` |
| `~/pics/bar.png` | `\\wsl.localhost\Ubuntu\home\you\pics\bar.png` |

!!! success "UNC paths render fine"
    `\\wsl.localhost\...` was verified working as an `AppLogo` — no need to
    stage WSL-side images into a Windows temp directory.

## 3. The versioned pwsh path breaks on update

`(Get-Command pwsh).Source` resolves to the versioned package path:

```
C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.4.0_x64__8wekyb3d8bbwe\pwsh.exe
```

Register that in the protocol handler and the click silently stops working
after the next Store update. Use the stable alias instead:

```
%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe
```

## The pattern behind all three

Every one is a **silent success**: exit code `0`, no exception, nothing in a
log you were watching. The system is built defensively as a result — each hop
writes its own log, and `toast` deliberately does *not* redirect stderr to
`/dev/null`.

!!! quote "The incident that set the rule"
    A GPU VRAM spill corrupted an in-flight eval run and no notification
    appeared. Every stage of the alert chain worked except the last inch: the
    toast call ran inside a Docker container, which cannot exec a Windows
    binary. The exception was caught and swallowed, so the failure was
    invisible exactly when it mattered.

    A `check=False` or a swallowed `except` at the last inch hides the failure
    precisely when you need it most.
