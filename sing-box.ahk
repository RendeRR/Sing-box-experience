#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Принудительно устанавливаем кодировку UTF-8 для логов
FileEncoding "UTF-8"

; Запрос прав администратора
if not A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp
}

; --- Настройки путей ---
SingBoxExe := "C:\sing-box\sing-box.exe"
ConfigDir  := "C:\sing-box"
ConfigFile := "config.json"
LogFile    := A_ScriptDir "\ahk_debug.log"

; --- Ваши иконки ---
IconOn  := A_ScriptDir "\icon_on.ico"
IconOff := A_ScriptDir "\icon_off.ico"

; --- Получение версии ---
SBVersion := "sing-box"
try {
    RunWait(A_ComSpec ' /c ""' SingBoxExe '" version > "' A_Temp '\sb_ver.txt""',, "Hide")
    versionText := FileRead(A_Temp "\sb_ver.txt")
    SBVersion := StrSplit(versionText, "`n")[1]
}

Tray := A_TrayMenu
Global LastState := -1 

SetTimer(UpdateMenu, 1000)
UpdateMenu()

; --- Логика обновления меню ---
UpdateMenu() {
    Global LastState
    currentState := ProcessExist("sing-box.exe") ? 1 : 0
    
    if (currentState == LastState)
        return
        
    LastState := currentState
    Tray.Delete()
    
    if (currentState) {
        if FileExist(IconOn)
            TraySetIcon(IconOn)
            
        ; Пункт меню активен, клик ничего не делает
        Tray.Add("Статус: Подключен", (*) => "")
        if FileExist(IconOn)
            Tray.SetIcon("Статус: Подключен", IconOn)
        
        Tray.Add("Отключить VPN", ToggleVPN)
    } else {
        if FileExist(IconOff)
            TraySetIcon(IconOff)
            
        ; Пункт меню активен, клик ничего не делает
        Tray.Add("Статус: Отключен", (*) => "")
        if FileExist(IconOff)
            Tray.SetIcon("Статус: Отключен", IconOff)
        
        Tray.Add("Включить VPN", ToggleVPN)
    }
    
    Tray.Add() ; Разделитель
    
    ; Версию можно оставить заблокированной, там нет иконки
    Tray.Add(SBVersion, (*) => "")
    Tray.Disable(SBVersion)
    
    Tray.Add("Выход", QuitApp)
}

; --- Логика переключения ---
ToggleVPN(*) {
    if ProcessExist("sing-box.exe") {
        FileAppend(A_Now " - Останавливаем процесс...`n", LogFile)
        ProcessClose("sing-box.exe")
    } else {
        FileAppend(A_Now " - Пытаемся запустить...`n", LogFile)
        try {
            Run('"' SingBoxExe '" run -c "' ConfigFile '"', ConfigDir, "Hide")
            FileAppend(A_Now " - Команда Run отправлена успешно`n", LogFile)
        } catch as err {
            FileAppend(A_Now " - ОШИБКА AHK: " err.Message "`n", LogFile)
        }
    }
    UpdateMenu()
}

QuitApp(*) {
    if ProcessExist("sing-box.exe") {
        ProcessClose("sing-box.exe")
    }
    ExitApp()
}
