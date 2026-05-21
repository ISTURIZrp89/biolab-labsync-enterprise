Set WshShell = CreateObject("WScript.Shell")
Dim fso, path
Set fso = CreateObject("Scripting.FileSystemObject")
path = fso.GetParentFolderName(WScript.ScriptFullName)

' Ejecutar el servidor PowerShell en modo oculto
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & path & "\server.ps1""", 0, False

' Esperar 2 segundos para que el servidor inicie
WScript.Sleep 2000

' Abrir el navegador en la dirección local
WshShell.Run "http://localhost:8765", 1, False
