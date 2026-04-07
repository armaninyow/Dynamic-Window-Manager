; =============================================================================
;  Dynamic Window Manager (DWM) — AutoHotkey v2
;  Modern HTML table UI via ActiveX WebBrowser, INI database backend
;  Version : 3.3.0
; =============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ---------------------------------------------------------------------------
;  GLOBALS
; ---------------------------------------------------------------------------
global DB_FILE       := A_ScriptDir "\DWM_Rules.ini"
global APP_TITLE     := "Dynamic Window Manager"
global g_Rules       := Map()
global g_Applied     := Map()
global g_WB          := ""
global g_Doc         := ""
global g_WBCtrl      := ""
global g_ShowOnStart := true   ; default: show dashboard on launch

; ---------------------------------------------------------------------------
;  ENTRY POINT
; ---------------------------------------------------------------------------

; Re-launch as administrator if not already elevated.
; This is required to move/resize elevated windows (e.g. Task Manager)
; when running as a compiled .exe. The .ahk interpreter is typically already
; elevated, so this block only fires for compiled builds in practice.
if !A_IsAdmin {
    try {
        if A_IsCompiled
            Run '*RunAs "' A_ScriptFullPath '"'
        else
            Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
    }
    ExitApp
}

DB_Load()
Pref_Load()
DWM_WriteHTML()
DWM_BuildDashboard()
DWM_StartWatcher()


; ═══════════════════════════════════════════════════════════════════════════
;  DATABASE
; ═══════════════════════════════════════════════════════════════════════════

DB_Load() {
    g_Rules.Clear()
    if !FileExist(DB_FILE)
        return
    sections := IniRead(DB_FILE)
    loop parse, sections, "`n", "`r" {
        sec := Trim(A_LoopField)
        if (sec = "")
            continue
        try {
            proc    := IniRead(DB_FILE, sec, "ProcessName", "")
            w       := Integer(IniRead(DB_FILE, sec, "Width",    "800"))
            h       := Integer(IniRead(DB_FILE, sec, "Height",   "600"))
            hAnchor := IniRead(DB_FILE, sec, "HAnchor",  "Left")
            vAnchor := IniRead(DB_FILE, sec, "VAnchor",  "Top")
            mon     := Integer(IniRead(DB_FILE, sec, "Monitor",  "1"))
            if (proc != "")
                g_Rules[StrLower(proc)] := Map(
                    "ProcessName", proc,
                    "Width",       w,
                    "Height",      h,
                    "HAnchor",     hAnchor,
                    "VAnchor",     vAnchor,
                    "Monitor",     mon
                )
        }
    }
}

DB_Save() {
    ; Preserve the [Preferences] section before wiping the file.
    showVal := IniRead(DB_FILE, "Preferences", "ShowOnStart", "1")

    if FileExist(DB_FILE)
        FileDelete DB_FILE

    idx := 1
    for key, rule in g_Rules {
        sec := "Rule" idx
        IniWrite rule["ProcessName"], DB_FILE, sec, "ProcessName"
        IniWrite rule["Width"],       DB_FILE, sec, "Width"
        IniWrite rule["Height"],      DB_FILE, sec, "Height"
        IniWrite rule["HAnchor"],     DB_FILE, sec, "HAnchor"
        IniWrite rule["VAnchor"],     DB_FILE, sec, "VAnchor"
        IniWrite rule["Monitor"],     DB_FILE, sec, "Monitor"
        idx++
    }

    ; Re-write the preserved preference so it survives the rebuild.
    IniWrite showVal, DB_FILE, "Preferences", "ShowOnStart"
}

DB_Upsert(proc, w, h, hAnchor, vAnchor, mon) {
    g_Rules[StrLower(proc)] := Map(
        "ProcessName", proc,
        "Width",       w,
        "Height",      h,
        "HAnchor",     hAnchor,
        "VAnchor",     vAnchor,
        "Monitor",     mon
    )
    _ClearApplied(proc)
    DB_Save()
}

DB_Delete(proc) {
    g_Rules.Delete(StrLower(proc))
    _ClearApplied(proc)
    DB_Save()
}

_ClearApplied(proc) {
    for hwnd in g_Applied.Clone() {
        try {
            if (StrLower(WinGetProcessName("ahk_id " hwnd)) = StrLower(proc))
                g_Applied.Delete(hwnd)
        }
    }
}


; ═══════════════════════════════════════════════════════════════════════════
;  PREFERENCES  (stored in [Preferences] section of DWM_Rules.ini)
; ═══════════════════════════════════════════════════════════════════════════

Pref_Load() {
    global g_ShowOnStart
    raw := IniRead(DB_FILE, "Preferences", "ShowOnStart", "1")
    g_ShowOnStart := (raw = "1")
}

Pref_Save() {
    IniWrite (g_ShowOnStart ? "1" : "0"), DB_FILE, "Preferences", "ShowOnStart"
}


; ═══════════════════════════════════════════════════════════════════════════
;  WRITE HTML TO TEMP FILE
;  Avoids AHK v2 quote-escaping issues with inline HTML strings.
; ═══════════════════════════════════════════════════════════════════════════

DWM_WriteHTMLHeader() {
    html := "
(
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body {
    background: #222222;
    overflow: hidden;
    height: 100%;
    user-select: none;
    -webkit-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    cursor: default;
    font-family: 'Segoe UI', sans-serif;
}
::selection { background: transparent; }
::-moz-selection { background: transparent; }
table {
    width: calc(100% - 17px);
    border-collapse: collapse;
    table-layout: fixed;
}
th {
    padding: 9px 12px;
    text-align: left;
    font-family: 'Segoe UI', sans-serif;
    font-weight: 600;
    color: #7A8494;
    font-size: 11px;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    border-bottom: 1px solid #2E2E2E;
    user-select: none;
    -webkit-user-select: none;
    -ms-user-select: none;
    background: #222222;
    cursor: default;
}
th:nth-child(1) { width: 36%; }
th:nth-child(2) { width: 20%; }
th:nth-child(3) { width: 20%; }
th:nth-child(4) { width: calc(24% - 50px); }
th:nth-child(5) { width: 50px; min-width: 50px; max-width: 50px; padding: 0; text-align: center; }
.add-btn {
    display: block;
    width: 100%;
    height: 100%;
    background: none;
    border: none;
    color: #E0E0E0;
    font-family: 'Segoe UI Emoji', 'Segoe UI Symbol', sans-serif;
    font-size: 16px;
    cursor: pointer;
    padding: 0;
    line-height: 1;
    opacity: 0.7;
    transition: opacity 0.15s, background 0.15s;
}
.add-btn:hover { opacity: 1; background: #2C2C2C; }
.add-btn:active { background: #1A3350; }
th.add-th { padding: 0; border-left: 1px solid #2E2E2E; }
</style>
</head>
<body oncontextmenu="return false;">
<table>
  <thead>
    <tr>
      <th>Application (Process)</th>
      <th>Dimensions</th>
      <th>Anchor</th>
      <th>Monitor</th>
      <th class="add-th"><button class="add-btn" onclick="if(!formOpen){window.status='BTN:add';}" title="Add Rule">&#x2795;</button></th>
    </tr>
  </thead>
</table>
<script>
var formOpen = false;
function lockUI()   { formOpen = true;  }
function unlockUI() { formOpen = false; }
</script>
</body>
</html>
)"
    if FileExist(A_Temp "\DWM_Header.html")
        FileDelete A_Temp "\DWM_Header.html"
    FileAppend html, A_Temp "\DWM_Header.html", "UTF-8"
}

DWM_WriteHTMLBody() {
    html := "
(
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html {
    overflow: hidden;
    height: 100%;
}
body {
    background: #1C1C1C;
    color: #E0E0E0;
    font-family: 'Segoe UI', sans-serif;
    font-size: 13px;
    overflow-x: hidden;
    overflow-y: scroll;
    height: 100%;
    user-select: none;
    -webkit-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    -ms-overflow-style: scrollbar;
    cursor: default;
}
::selection { background: transparent; }
::-moz-selection { background: transparent; }
table {
    width: 100%;
    border-collapse: collapse;
    table-layout: fixed;
}
td {
    padding: 9px 12px;
    border-bottom: 1px solid #242424;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    color: #DADADA;
    text-align: left;
    direction: ltr;
    user-select: none;
    -webkit-user-select: none;
    -ms-user-select: none;
    cursor: default;
}
td:nth-child(1) { width: 36%; }
td:nth-child(2) { width: 20%; color: #909090; font-size: 12px; }
td:nth-child(3) { width: 20%; color: #8AAFC8; }
td:nth-child(4) { width: calc(24% - 50px); color: #909090; }
td:nth-child(5) { width: 50px; min-width: 50px; max-width: 50px; padding: 0; }
tbody tr { transition: background 0.08s; cursor: default; }
tbody tr:hover { background: #252525; }
tbody tr.selected { background: #1A3350 !important; }
tbody tr:last-child td { border-bottom: none; }
#ctx {
    display: none;
    position: fixed;
    background: #252525;
    border: 1px solid #383838;
    border-radius: 5px;
    padding: 4px 0;
    min-width: 110px;
    box-shadow: 0 6px 20px rgba(0,0,0,0.6);
    z-index: 999;
}
.ctx-item {
    padding: 7px 16px;
    cursor: pointer;
    font-size: 13px;
}
.ctx-item:hover { background: #2A3A4A; }
#ctx-del { color: #D05050; }
#ctx-del:hover { background: #2A1E1E; }
::-webkit-scrollbar { width: 17px; }
::-webkit-scrollbar-track { background: #1C1C1C; }
::-webkit-scrollbar-thumb { background: #363636; border-radius: 3px; }
</style>
</head>
<body>
<table><tbody id="tbody"></tbody></table>

<div id="ctx">
  <div id="ctx-edit" class="ctx-item">Edit</div>
  <div id="ctx-del"  class="ctx-item">Delete</div>
</div>

<script>
var selRow = -1;
var ctxRow = -1;
var ctx    = document.getElementById('ctx');

document.addEventListener('click', function(e) {
    if (!ctx.contains(e.target)) { ctx.style.display = 'none'; }
});

function rowClick(i) {
    var rows = document.getElementById('tbody').rows;
    for (var r = 0; r < rows.length; r++) { rows[r].className = ''; }
    if (i >= 0 && i < rows.length) { rows[i].className = 'selected'; }
    selRow = i;
}

function rowRClick(i, ev) {
    ev = ev || window.event;
    rowClick(i);
    ctxRow = i;
    ctx.style.left    = ev.clientX + 'px';
    ctx.style.top     = ev.clientY + 'px';
    ctx.style.display = 'block';
    ev.preventDefault ? ev.preventDefault() : (ev.returnValue = false);
    return false;
}

function ctxAction(action) {
    ctx.style.display = 'none';
    window.status = 'CTX:' + action + ':' + ctxRow;
}

document.getElementById('ctx-edit').onclick = function() { ctxAction('edit'); };
document.getElementById('ctx-del').onclick  = function() { ctxAction('del');  };
</script>
</body>
</html>
)"
    if FileExist(A_Temp "\DWM_Body.html")
        FileDelete A_Temp "\DWM_Body.html"
    FileAppend html, A_Temp "\DWM_Body.html", "UTF-8"
}

DWM_WriteHTML() {
    DWM_WriteHTMLHeader()
    DWM_WriteHTMLBody()
}


; ═══════════════════════════════════════════════════════════════════════════
;  COORDINATE MATH
; ═══════════════════════════════════════════════════════════════════════════

Calc_Position(hwnd, appW, appH, hAnchor, vAnchor, mon, &outX, &outY, &outW, &outH) {
    monCount := MonitorGetCount()
    monIdx   := (mon >= 1 && mon <= monCount) ? mon : 1
    MonitorGetWorkArea monIdx, &waL, &waT, &waR, &waB
    waW := waR - waL
    waH := waB - waT

    borderL := 0, borderT := 0, borderR := 0, borderB := 0
    try {
        buf := Buffer(16, 0)
        DllCall("dwmapi\DwmGetWindowAttribute",
            "Ptr", hwnd, "UInt", 9, "Ptr", buf, "UInt", 16, "Int")
        visL := NumGet(buf,  0, "Int")
        visT := NumGet(buf,  4, "Int")
        visR := NumGet(buf,  8, "Int")
        visB := NumGet(buf, 12, "Int")
        WinGetPos &fX, &fY, &fW, &fH, "ahk_id " hwnd
        borderL := visL - fX
        borderT := visT - fY
        borderR := (fX + fW) - visR
        borderB := (fY + fH) - visB
    }

    outW := appW + borderL + borderR
    outH := appH + borderT + borderB

    switch hAnchor {
        case "Left":   outX := waL - borderL
        case "Center": outX := waL + (waW - appW) // 2 - borderL
        case "Right":  outX := waR - appW - borderL
        default:       outX := waL - borderL
    }
    switch vAnchor {
        case "Top":    outY := waT - borderT
        case "Center": outY := waT + (waH - appH) // 2 - borderT
        case "Bottom": outY := waB - appH - borderT
        default:       outY := waT - borderT
    }
}


; ═══════════════════════════════════════════════════════════════════════════
;  WINDOW WATCHER
; ═══════════════════════════════════════════════════════════════════════════

DWM_StartWatcher() {
    SetTimer DWM_Tick, 500
}

; WS / WS_EX constants used for dialog detection
; A proper top-level application window must:
;   - Have WS_CAPTION (title bar)
;   - Have WS_SYSMENU (system menu / close button)
;   - NOT be WS_EX_DLGMODALFRAME (dialog frame)
;   - NOT be WS_EX_TOOLWINDOW (tool/floating palette)
;   - Have a non-empty title
;   - Be a top-level window (no owner), OR be an owned window that is itself
;     a main frame — we skip owned windows entirely to avoid dialogs, pickers,
;     save-as boxes, property sheets, etc.

DWM_IsAppWindow(hwnd) {
    ; Must have a title
    if (WinGetTitle("ahk_id " hwnd) = "")
        return false

    style   := WinGetStyle("ahk_id " hwnd)
    exStyle := WinGetExStyle("ahk_id " hwnd)

    ; Must have caption and system menu (real app window)
    WS_CAPTION  := 0x00C00000
    WS_SYSMENU  := 0x00080000
    if !(style & WS_CAPTION) || !(style & WS_SYSMENU)
        return false

    ; Skip tool windows (floating palettes, overlays)
    WS_EX_TOOLWINDOW := 0x00000080
    if (exStyle & WS_EX_TOOLWINDOW)
        return false

    ; Skip dialog-framed windows (property sheets, open/save dialogs, pickers)
    WS_EX_DLGMODALFRAME := 0x00000001
    if (exStyle & WS_EX_DLGMODALFRAME)
        return false

    ; Skip owned windows — dialogs, message boxes, pickers are always owned.
    ; A main application frame is never owned (GetWindow GW_OWNER = 0).
    GW_OWNER := 4
    owner := DllCall("GetWindow", "Ptr", hwnd, "UInt", GW_OWNER, "Ptr")
    if (owner != 0)
        return false

    ; Block known dialog window classes regardless of owner state.
    ; #32770 = standard dialog (Replace/Skip Files, Run, etc.)
    ; OperationStatusWindow = explorer progress/conflict dialogs
    ; Alternate = explorer Replace or Skip dialog (Win11)
    cls := WinGetClass("ahk_id " hwnd)
    static DialogClasses := ["#32770", "OperationStatusWindow",
                              "WorkerW", "Progman"]
    for dc in DialogClasses {
        if (cls = dc)
            return false
    }

    ; Additional heuristic: windows with no minimize/maximize buttons but
    ; with a close button are almost certainly dialogs (WS_MINIMIZEBOX = 0x20000,
    ; WS_MAXIMIZEBOX = 0x10000). Real app main windows always have both.
    WS_MINIMIZEBOX := 0x00020000
    WS_MAXIMIZEBOX := 0x00010000
    if !(style & WS_MINIMIZEBOX) || !(style & WS_MAXIMIZEBOX)
        return false

    return true
}

DWM_Tick() {
    for key, rule in g_Rules {
        proc  := rule["ProcessName"]
        hwnds := WinGetList("ahk_exe " proc)

        for hwnd in hwnds {
            if g_Applied.Has(hwnd)
                continue

            ; Only touch real top-level application windows
            if !DWM_IsAppWindow(hwnd)
                continue

            ; Skip windows we cannot interact with (e.g. elevated processes
            ; when DWM is not running as admin). Mark them applied so we don't
            ; keep retrying every tick — the window won't become accessible.
            try {
                minMax := WinGetMinMax("ahk_id " hwnd)
            } catch {
                g_Applied[hwnd] := 1
                continue
            }

            if (minMax = -1)   ; minimized — wait
                continue
            if (minMax = 1) {  ; maximized — restore first
                try WinRestore "ahk_id " hwnd
                Sleep 80
            }

            Calc_Position(hwnd,
                rule["Width"], rule["Height"],
                rule["HAnchor"], rule["VAnchor"], rule["Monitor"],
                &nx, &ny, &nw, &nh)

            try {
                WinMove nx, ny, nw, nh, "ahk_id " hwnd
            } catch {
                ; Window belongs to an elevated or protected process.
                ; Mark as applied so we stop retrying.
                g_Applied[hwnd] := 1
                continue
            }
            g_Applied[hwnd] := 1
        }
    }

    for hwnd in g_Applied.Clone() {
        if !WinExist("ahk_id " hwnd)
            g_Applied.Delete(hwnd)
    }
}


; ═══════════════════════════════════════════════════════════════════════════
;  DASHBOARD GUI
; ═══════════════════════════════════════════════════════════════════════════

DWM_BuildDashboard() {
    global g_Dash, g_WB, g_Doc, g_WBCtrl, g_WBHdr, g_DocHdr, g_WBHdrCtrl
    HDR_H := 36

    g_Dash := Gui("+Resize +MinSize640x300", APP_TITLE)
    g_Dash.BackColor := "1C1C1C"
    g_Dash.SetFont("s9 cE0E0E0", "Segoe UI")

    ; Fixed header WebBrowser — never scrolls
    g_WBHdrCtrl := g_Dash.Add("ActiveX", "x0 y0 w640 h" HDR_H, "Shell.Explorer.2")
    g_WBHdr     := g_WBHdrCtrl.Value
    g_WBHdr.Silent := true
    g_WBHdr.Navigate("file:///" StrReplace(A_Temp "\DWM_Header.html", "\", "/"))
    while (g_WBHdr.ReadyState != 4)
        Sleep 30
    g_DocHdr := g_WBHdr.Document

    ; Scrollable body WebBrowser — rows only
    g_WBCtrl := g_Dash.Add("ActiveX", "x0 y" HDR_H " w640 h304", "Shell.Explorer.2")
    g_WB     := g_WBCtrl.Value
    g_WB.Silent := true
    g_WB.Navigate("file:///" StrReplace(A_Temp "\DWM_Body.html", "\", "/"))
    while (g_WB.ReadyState != 4)
        Sleep 30
    g_Doc := g_WB.Document

    g_Dash.OnEvent("Close", (*) => g_Dash.Hide())
    g_Dash.OnEvent("Size",  DWM_OnResize)

    SetTimer DWM_PollWebClick, 150

    DWM_RefreshTable()
    if g_ShowOnStart
        g_Dash.Show("w640 h340")
}

DWM_RefreshTable() {
    if !IsObject(g_Doc)
        return
    tbody := g_Doc.getElementById("tbody")
    if !IsObject(tbody)
        return

    while (tbody.rows.length > 0)
        tbody.deleteRow(0)

    idx := 0
    for key, rule in g_Rules {
        row := tbody.insertRow(-1)
        row.setAttribute("data-idx", idx)

        c1 := row.insertCell(0) , c1.innerText := rule["ProcessName"]
        c2 := row.insertCell(1) , c2.innerText := rule["Width"] " x " rule["Height"]
        c3 := row.insertCell(2) , c3.innerText := rule["VAnchor"] " | " rule["HAnchor"]
        c4 := row.insertCell(3) , c4.innerText := rule["Monitor"]
        row.insertCell(4)   ; empty cell under the add-btn header column

        ; Attach JS handlers via the DOM (avoids any string-quoting in execScript)
        iStr := String(idx)
        g_Doc.parentWindow.execScript(
            "(function(){" .
            "var r=document.getElementById('tbody').rows[" iStr "];" .
            "r.onclick=function(){rowClick(" iStr ");};" .
            "r.oncontextmenu=function(e){return rowRClick(" iStr ",e||window.event);};" .
            "})()"
        )
        idx++
    }
}

DWM_PollWebClick() {
    if !IsObject(g_WB)
        return
    try {
        ; Check header doc first — that's where the ➕ button lives
        hdrStatus := g_WBHdr.Document.parentWindow.status
        if InStr(hdrStatus, "BTN:add") {
            g_WBHdr.Document.parentWindow.status := ""
            DWM_OpenForm()
            return
        }
    }
    try {
        status := g_WB.Document.parentWindow.status
        if InStr(status, "BTN:add") {
            g_WB.Document.parentWindow.status := ""
            DWM_OpenForm()
            return
        }
        if !InStr(status, "CTX:")
            return
        g_WB.Document.parentWindow.status := ""

        parts  := StrSplit(status, ":")
        action := parts[2]
        rowIdx := Integer(parts[3])
        proc   := DWM_ProcAtIndex(rowIdx)
        if (proc = "")
            return

        try {
            if (g_DocHdr.parentWindow.formOpen)
                return
        }

        if (action = "edit") {
            rule    := g_Rules[StrLower(proc)]
            DWM_OpenForm(proc,
                rule["Width"], rule["Height"],
                rule["HAnchor"], rule["VAnchor"],
                rule["Monitor"], 1)
        } else if (action = "del") {
            if MsgBox("Delete rule for `"" proc "`"?", APP_TITLE,
                      "YesNo Icon? 0x40000") = "Yes" {
                DB_Delete(proc)
                DWM_RefreshTable()
            }
        }
    }
}

DWM_ProcAtIndex(idx) {
    i := 0
    for key, rule in g_Rules {
        if (i = idx)
            return rule["ProcessName"]
        i++
    }
    return ""
}

DWM_OnResize(guiObj, minMax, width, height) {
    if (minMax = -1)
        return
    HDR_H := 36
    ; Header stays at top, fixed height
    g_WBHdrCtrl.Move(0, 0, width, HDR_H)
    ; Body fills the rest
    g_WBCtrl.Move(0, HDR_H, width, height - HDR_H)
}


; ═══════════════════════════════════════════════════════════════════════════
;  SPINNER HELPER
; ═══════════════════════════════════════════════════════════════════════════

SpinEdit(ctrl, delta, step := 1, minVal := 0) {
    val := Integer(ctrl.Value)
    val += delta * step
    if (val < minVal)
        val := minVal
    ctrl.Value := val
}


; ═══════════════════════════════════════════════════════════════════════════
;  ADD / EDIT FORM
; ═══════════════════════════════════════════════════════════════════════════

DWM_OpenForm(proc := "", w := "800", h := "600",
             hAnchor := "Left", vAnchor := "Top", mon := 1, editRow := 0) {

    isEdit := (editRow > 0)
    fTitle := isEdit ? "Edit Rule" : "Add Rule"

    frm := Gui("+Owner" g_Dash.Hwnd " +ToolWindow", fTitle)
    frm.BackColor := "1C1C1C"
    frm.SetFont("s9 cE0E0E0", "Segoe UI")

    frm.Add("Text", "x15 y15 w280 h18", "Process Name  (e.g. chrome.exe)")
    edProc := frm.Add("Edit", "x15 y35 w225 h24 Background2A2A2A cFFFFFF", proc)
    if isEdit
        edProc.Opt("+ReadOnly")
    btnBrowse := frm.Add("Button", "x245 y34 w65 h26", "Browse")
    btnBrowse.OnEvent("Click", DWM_Browse)

    frm.Add("Text", "x15 y72 w80 h18", "Width (px)")
    edW   := frm.Add("Edit", "x15 y92 w62 h24 Background2A2A2A cFFFFFF Number", w)
    btnWU := frm.Add("Button", "x79 y92 w20 h12", Chr(0x25B2))
    btnWD := frm.Add("Button", "x79 y104 w20 h12", Chr(0x25BC))
    btnWU.OnEvent("Click", (*) => SpinEdit(edW,  1))
    btnWD.OnEvent("Click", (*) => SpinEdit(edW, -1))

    frm.Add("Text", "x108 y72 w80 h18", "Height (px)")
    edH   := frm.Add("Edit", "x108 y92 w62 h24 Background2A2A2A cFFFFFF Number", h)
    btnHU := frm.Add("Button", "x172 y92 w20 h12", Chr(0x25B2))
    btnHD := frm.Add("Button", "x172 y104 w20 h12", Chr(0x25BC))
    btnHU.OnEvent("Click", (*) => SpinEdit(edH,  1))
    btnHD.OnEvent("Click", (*) => SpinEdit(edH, -1))

    frm.Add("Text", "x201 y72 w60 h18", "Monitor")
    edMon := frm.Add("Edit", "x201 y92 w45 h24 Background2A2A2A cFFFFFF Number", mon)
    btnMU := frm.Add("Button", "x248 y92 w20 h12", Chr(0x25B2))
    btnMD := frm.Add("Button", "x248 y104 w20 h12", Chr(0x25BC))
    btnMU.OnEvent("Click", (*) => SpinEdit(edMon,  1, 1))
    btnMD.OnEvent("Click", (*) => SpinEdit(edMon, -1, 1))

    frm.Add("Text", "x15 y128 w120 h18", "Horizontal Anchor")
    ddH := frm.Add("DropDownList",
        "x15 y148 w120 h80 Background2A2A2A cFFFFFF Choose1",
        ["Left", "Center", "Right"])
    ddH.Choose(hAnchor)

    frm.Add("Text", "x150 y128 w120 h18", "Vertical Anchor")
    ddV := frm.Add("DropDownList",
        "x150 y148 w120 h80 Background2A2A2A cFFFFFF Choose1",
        ["Top", "Center", "Bottom"])
    ddV.Choose(vAnchor)

    btnSave   := frm.Add("Button", "x15 y195 w90 h28 Default", isEdit ? "Save" : "Add")
    btnSave.SetFont("s9 Bold")
    btnCancel := frm.Add("Button", "x115 y195 w80 h28", "Cancel")

    btnSave.OnEvent("Click",   DWM_FormSave)
    btnCancel.OnEvent("Click", (*) => CloseForm())
    frm.OnEvent("Close", (*) => CloseForm())

    closing := false
    CloseForm() {
        if closing
            return
        closing := true
        try g_DocHdr.parentWindow.execScript("unlockUI()")
        g_Dash.Opt("-Disabled")
        frm.Destroy()
        ; Re-focus the dashboard so WebBrowser controls accept input again
        WinActivate "ahk_id " g_Dash.Hwnd
        ControlFocus g_WBCtrl.Hwnd, "ahk_id " g_Dash.Hwnd
    }

    g_Dash.Opt("+Disabled")
    frm.Show("w325 h238")
    try g_DocHdr.parentWindow.execScript("lockUI()")

    DWM_Browse(*) {
        chosen := FileSelect(, , "Select an executable", "Executables (*.exe)")
        if (chosen != "") {
            SplitPath chosen, &exeName
            edProc.Value := exeName
        }
    }

    DWM_FormSave(*) {
        pName  := Trim(edProc.Value)
        wVal   := Integer(Trim(edW.Value))
        hVal   := Integer(Trim(edH.Value))
        monVal := Integer(Trim(edMon.Value))
        hAnc   := ddH.Text
        vAnc   := ddV.Text

        if (pName = "") {
            MsgBox "Process name cannot be empty.", fTitle, "Icon!"
            return
        }
        if (wVal < 100 || hVal < 100) {
            MsgBox "Width and Height must be at least 100 px.", fTitle, "Icon!"
            return
        }
        if (monVal < 1) {
            MsgBox "Monitor number must be 1 or greater.", fTitle, "Icon!"
            return
        }
        if !InStr(pName, ".") {
            if MsgBox("Process name doesn't contain a dot.`n" .
                      "Did you mean `"" pName ".exe`"?`n`nContinue anyway?",
                      fTitle, "YesNo Icon?") = "No"
                return
        }

        DB_Upsert(pName, wVal, hVal, hAnc, vAnc, monVal)
        DWM_RefreshTable()
        CloseForm()
    }
}


; ═══════════════════════════════════════════════════════════════════════════
;  TRAY
; ═══════════════════════════════════════════════════════════════════════════

A_TrayMenu.Delete()
A_TrayMenu.Add("Show Dashboard", (*) => g_Dash.Show())
A_TrayMenu.Add()
A_TrayMenu.Add("Show on Startup", Tray_ToggleShowOnStart)
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show Dashboard"

; Reflect the loaded preference in the checkmark immediately
if g_ShowOnStart
    A_TrayMenu.Check("Show on Startup")
else
    A_TrayMenu.Uncheck("Show on Startup")

Tray_ToggleShowOnStart(*) {
    global g_ShowOnStart
    g_ShowOnStart := !g_ShowOnStart
    if g_ShowOnStart
        A_TrayMenu.Check("Show on Startup")
    else
        A_TrayMenu.Uncheck("Show on Startup")
    Pref_Save()
}

A_IconTip := APP_TITLE
if A_IsCompiled
    TraySetIcon(A_ScriptFullPath, 1)
else if FileExist(A_ScriptDir "\icon.ico")
    TraySetIcon(A_ScriptDir "\icon.ico")

