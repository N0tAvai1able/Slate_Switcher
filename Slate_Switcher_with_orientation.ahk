#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent 

if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
    }
    ExitApp()
}

SetupTray()

SetupTray() {
    RotationMenu := Menu()
    RotationMenu.Add("0° (Landscape)", (*) => SetDisplayRotation(0))
    RotationMenu.Add("90° (Portrait)", (*) => SetDisplayRotation(1))
    RotationMenu.Add("180° (Landscape Flipped)", (*) => SetDisplayRotation(2))
    RotationMenu.Add("270° (Portrait Flipped)", (*) => SetDisplayRotation(3))

    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add("Toggle Slate Mode", (*) => ToggleMode())
    Tray.Add("Orientation", RotationMenu)
    Tray.Add()
    Tray.Add("Exit", (*) => ExitApp())

    Tray.Default := "Toggle Slate Mode"
    Tray.ClickCount := 1
    A_IconTip := "System Controls"
}

ToggleMode() {
    key := "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl"
    try {
        currentVal := RegRead(key, "ConvertibleSlateMode")
        newVal := (currentVal = 1) ? 0 : 1
        RunWait('reg add "' key '" /v ConvertibleSlateMode /t REG_DWORD /d ' newVal ' /f', , "Hide")
        SoundBeep(newVal ? 1000 : 500, 100)
    }
}

SetDisplayRotation(Orientation := 0) {
    ; Create a 220-byte buffer for the DEVMODEW structure
    dm := Buffer(220, 0)
    NumPut("Short", 220, dm, 68) ; dmSize

    ; Get current settings. -1 is the default monitor.
    if !DllCall("EnumDisplaySettingsW", "Ptr", 0, "Int", -1, "Ptr", dm)
        return

    ; Check if current orientation matches target to prevent redundant processing
    if NumGet(dm, 84, "Int") = Orientation
        return

    ; Get current dimensions
    width := NumGet(dm, 172, "UInt")
    height := NumGet(dm, 176, "UInt")

    ; Determine if we need to flip the resolution
    ; 0/2 are Landscape, 1/3 are Portrait
    isCurrentPortrait := (NumGet(dm, 84, "Int") = 1 || NumGet(dm, 84, "Int") = 3)
    isTargetPortrait := (Orientation = 1 || Orientation = 3)

    if (isCurrentPortrait != isTargetPortrait) {
        NumPut("UInt", height, dm, 172) ; Swap width
        NumPut("UInt", width, dm, 176)  ; Swap height
    }

    ; Set the fields we are changing: DM_PELSWIDTH (0x40000), DM_PELSHEIGHT (0x80000), DM_DISPLAYORIENTATION (0x800000)
    NumPut("UInt", 0x8C0000, dm, 40) 
    NumPut("Int", Orientation, dm, 84)

    ; Perform the update
    result := DllCall("ChangeDisplaySettingsW", "Ptr", dm, "UInt", 0)
    
    if (result != 0) {
        ; Fallback: Try changing orientation WITHOUT forcing width/height if driver rejected it
        NumPut("UInt", 0x800000, dm, 40)
        DllCall("ChangeDisplaySettingsW", "Ptr", dm, "UInt", 0)
    }
}