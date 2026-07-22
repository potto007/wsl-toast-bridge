# Usage

## `toast`

```
toast [-i IMAGE] [-p HERDR_PANE_ID] <title> [body]
```

| Flag | Meaning |
| --- | --- |
| `-i`, `--image` | App logo. Windows or WSL path — converted with `wslpath -w`. |
| `-p`, `--pane` | Herdr pane id (e.g. `w6:p1`); clicking the toast focuses it. |
| `TOAST_DRY_RUN=1` | Print the PowerShell command instead of firing. |
| `TOAST_PWSH` | Override `pwsh.exe` autodetection. |

```bash
toast "Build complete"
toast "Build failed" "Check the logs"
toast -i ~/.local/share/toast-icons/warning.png "[critical] GpuSpill" "VRAM spill active"
toast -p w6:p1 "Agent done" "clicking focuses that herdr pane"
```

Exit codes: `0` fired, `2` usage error, `1` no `pwsh.exe`.

!!! warning "A missing image never fails the toast"
    BurntToast falls back to the default icon and still exits `0`. `toast`
    warns on stderr when the path isn't a WSL-visible file — don't discard it.

## In scripts

=== "Shell"

    ```bash
    if make build; then
      toast "Build success" "$(git rev-parse --short HEAD)"
    else
      toast -i ~/.local/share/toast-icons/warning.png "Build failed" "see logs"
    fi
    ```

=== "systemd unit"

    ```ini
    [Service]
    ExecStart=/home/you/bin/long-job.sh
    ExecStopPost=/home/you/.local/bin/toast "Job finished" "%n"
    ```

=== "Prometheus alert poller"

    ```bash
    "$TOAST" -i "$HOME/.local/share/toast-icons/warning.png" \
      "[$sev] $name" "Firing alert ($extra)"
    ```

## `notify-send` shim

Drop-in for the freedesktop CLI. Accepts and ignores the flags that have no
Windows equivalent (`-u`, `-t`, `-c`, `--hint`, `--print-id`, …) so existing
callers work unmodified.

```bash
notify-send "Summary" "Body"
notify-send -i /path/icon.png "With icon" "Body"
```

Themed icon **names** (`dialog-error`, `dialog-information`) are dropped rather
than passed through — Windows has no icon theme to resolve them against.

Every invocation is logged to `~/.local/state/notify-send-shim.log`, which is
how you find out what a tool actually sent:

```
2026-07-22T07:59:40-06:00 argv: -- Agent\ update claude\ needs\ attention\ in\ prehend
```

## Pane targeting

Herdr's notification carries text but no pane id. The shim closes the gap at
send time:

1. Identify Herdr as the caller — `ps -o comm= -p $PPID`.
2. Match the notification text against `herdr agent list`: each agent's
   terminal title and repo directory name.
3. Exactly one hit → pass `-p <pane_id>`. Zero or several → no pane, the click
   just focuses the terminal.

The conservative fallback is deliberate: focusing the *wrong* pane is worse
than focusing none, and Herdr's ++ctrl+b++ ++o++ already jumps to the
notification target.

## Icons

Bundled in `~/.local/share/toast-icons/`:

| File | Used by |
| --- | --- |
| `herdr.png` | Herdr notifications (applied automatically) |
| `warning.png` | alerts — pass explicitly with `-i` |

Regenerate the warning triangle with `python3 icons/make-warning-icon.py out.png`.
