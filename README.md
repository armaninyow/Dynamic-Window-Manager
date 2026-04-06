# ↔️ Dynamic Window Manager

A FancyZones-style window placement tool for Windows. Define rules that automatically position and resize application windows the moment they open — by process name, anchor position, dimensions, and monitor.

![Dashboard](https://i.imgur.com/placeholder.png)

---

## Features

- **Rule-based placement** — assign a position and size to any application by its `.exe` process name
- **9-point anchor system** — place windows at any corner, edge midpoint, or center of the screen
- **Multi-monitor support** — target any monitor by number
- **Apply once, move freely** — rules fire only on first appearance; you can move the window afterward without interference
- **Maximized window handling** — if a window opens maximized, it is automatically restored before placement
- **Dialog filtering** — only real application windows are touched; file pickers, property sheets, progress dialogs, and system overlays are left alone
- **Persistent rules** — all rules are saved to a plain `.ini` file and reloaded on startup
- **Modern HTML table UI** — dark-themed dashboard rendered via an embedded WebBrowser control
- **Minimize to tray** — closing the dashboard hides it; the watcher keeps running in the background

---

## Requirements

- Windows 10 or 11

No installer, no AutoHotkey, no additional dependencies needed.

---

## Installation

1. Download `DynamicWindowManager.exe`.
2. Place it anywhere you like.
3. Double-click to run.

The dashboard opens immediately. Rules are saved to `DWM_Rules.ini` in the same folder as the executable.

To have it start with Windows, add a shortcut to `DynamicWindowManager.exe` in your Startup folder (`Win + R` → `shell:startup`).

---

## Usage

### Dashboard

| Control | Action |
|---|---|
| **➕ button** (top-right of header row) | Open the Add Rule form |
| **Right-click a row** | Edit or Delete that rule |
| **Win + Shift + W** | Toggle the dashboard on/off |
| **Tray icon → Show Dashboard** | Bring the dashboard back |
| **Tray icon → Exit** | Quit completely |

Closing the dashboard window minimizes it to the system tray — the watcher keeps running.

### Adding a Rule

Click **➕** or right-click a row and choose **Edit**.

| Field | Description |
|---|---|
| **Process Name** | The `.exe` filename of the target application (e.g. `chrome.exe`). Use **Browse** to pick an executable from disk — only the filename is extracted. |
| **Width / Height** | The desired visible window size in pixels. Use the ▲▼ buttons to nudge values. Minimum is 100 px. |
| **Monitor** | Which monitor to place the window on (1 = primary). |
| **Horizontal Anchor** | `Left`, `Center`, or `Right` — where the window sits horizontally within the work area. |
| **Vertical Anchor** | `Top`, `Center`, or `Bottom` — where the window sits vertically within the work area. |

Click **Add** (or **Save** when editing) to apply immediately.

> Editing a rule resets its applied state, so the updated position fires on the next open window of that process.

### Anchor Reference

The work area is the usable screen area, excluding the taskbar.

|  | Left | Center | Right |
|---|---|---|---|
| **Top** | Top-left corner | Top edge center | Top-right corner |
| **Center** | Left edge center | Screen center | Right edge center |
| **Bottom** | Bottom-left corner | Bottom edge center | Bottom-right corner |

---

## How It Works

**Window watcher** — a timer checks all open windows against your rules every 500 ms. When a matching window is seen for the first time it is moved and resized. Its handle is then recorded so the same window is never touched again, letting you reposition it freely afterward.

**Pixel-perfect placement** — Windows 10/11 windows have invisible DWM border padding that extends a few pixels beyond the visible edge. The app measures this per-window using `DwmGetWindowAttribute` and compensates so the visible edge lands exactly flush with the work area boundary — no gap on Left, Right, or Bottom anchors.

**Dialog filtering** — before touching any window the app verifies:
- Has a title, caption bar, and system menu (real app window)
- Does not carry `WS_EX_TOOLWINDOW` or `WS_EX_DLGMODALFRAME` extended styles
- Has both minimize and maximize buttons (dialogs typically lack these)
- Is not an owned window (dialogs are always owned by their parent)
- Is not a known shell class (`#32770`, `OperationStatusWindow`, `WorkerW`, `Progman`)

**Database** — rules are stored in `DWM_Rules.ini` next to the executable. Each section is one rule and the file is plain text, so you can hand-edit it if needed.

```ini
[Rule1]
ProcessName=chrome.exe
Width=1280
Height=720
HAnchor=Left
VAnchor=Top
Monitor=1
```

---

## File Structure

```
DynamicWindowManager.exe   ← the application
DWM_Rules.ini              ← auto-created on first rule save
```

Two temporary HTML files are written to `%TEMP%` on each launch for the dashboard UI. They are recreated automatically and can be ignored.

---

## Known Limitations

- There may be a brief moment (~500 ms) where a new window appears at its default position before being moved.
- Rules target all windows of a given process. If an application opens multiple windows (e.g. File Explorer), each new window is positioned independently on first appearance.

---

## License

MIT — do whatever you want with it.
