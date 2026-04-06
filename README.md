# ↔️ Dynamic Window Manager

![Dashboard](https://i.imgur.com/placeholder.png)

A FancyZones-style window placement tool for Windows. Define rules that automatically position and resize application windows the moment they open — by process name, anchor position, dimensions, and monitor.

---

## Features

- **Rule-based placement**: assign a position and size to any application by its `.exe` process name
- **9-point anchor system**: place windows at any corner, edge midpoint, or center of the screen
- **Multi-monitor support**: target any monitor by number
- **Apply once, move freely**: rules fire only on first appearance; you can move the window afterward without interference
- **Dialog filtering**: only real application windows are touched; file pickers, property sheets, progress dialogs, and system overlays are left alone
- **Persistent rules**: all rules are saved to a plain `.ini` file and reloaded on startup
- **Modern HTML table UI**: dark-themed dashboard rendered via an embedded WebBrowser control
- **Minimize to tray**: closing the dashboard hides it; the watcher keeps running in the background

---

## Usage

### Dashboard

| Control | Action |
|---|---|
| **➕ button** (top-right of header row) | Open the Add Rule form |
| **Right-click a row** | Edit or Delete that rule |
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

**Database**: rules are stored in `DWM_Rules.ini` next to the executable. Each section is one rule and the file is plain text, so you can hand-edit it if needed.

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

## Known Limitations

- There may be a brief moment (~500 ms) where a new window appears at its default position before being moved.
- Rules target all windows of a given process. If an application opens multiple windows (e.g. File Explorer), each new window is positioned independently on first appearance.

---

## File Structure

```
Main Folder
├── DynamicWindowManager.exe   ← the application
└── DWM_Rules.ini              ← auto-created on first rule save
```

Two temporary HTML files are written to `%TEMP%` on each launch for the dashboard UI. They are recreated automatically and can be ignored.

---

## Installation

1. Download the latest `.exe`. from Releases.
2. Place it anywhere you like.
3. Double-click to run.

The dashboard opens immediately. Rules are saved to `DWM_Rules.ini` in the same folder as the executable.

---

## Requirements

* **Operating System**: Windows 10 or Windows 11.
* **Standalone**: No installation or external assets required.

---

## License

### CC0 1.0 Universal
This project is licensed under the **Creative Commons Legal Code CC0 1.0 Universal**. 

To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide. This software is distributed without any warranty.
