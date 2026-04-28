' This script ensures Microsoft Word and Excel are always running, preventing memory leaks when running invisibly in the background.
' It targets PCs with Windows build 26100 or higher (Win 11 24H2) and 32-bit Microsoft Office.
' 1. GetWindowsBuild: Reads the Windows build number from the registry. Returns the build as an integer, or 0 if invalid.
' 2. IsOffice32BitInstalled: Checks if 32-bit Office is installed by looking for a specific registry key. Returns True or False.
' 3. IsProcessRunning: Uses WMI to verify if a specified process (e.g., Word or Excel) is running. Returns True or False.
' 4. LaunchApplication: Starts Word or Excel using their ProgID if not already active and sets them to run invisibly. 
' 5. GetProcessMemoryUsage: Monitors memory usage (in MB) of Word/Excel by querying WMI for their memory details.  
' 6. SafeQuit: Closes the application if running invisibly and exceeding the memory limit.  
' Main Logic:  
' - Verifies Windows build and ensures 32-bit Office is installed.  
' - If both conditions are met, the script enters a loop that checks and launches Word and Excel every second if not running.  
' - If memory usage exceeds the limit and the app is invisibly running in the background, it will be closed and relaunched in the next loop.
'
Function GetWindowsBuild()
    On Error Resume Next
    Dim objShell, build
    Set objShell = CreateObject("WScript.Shell")
    build = objShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CurrentBuild")
    If IsNumeric(build) Then
        GetWindowsBuild = CInt(build)
    Else
        GetWindowsBuild = 0
    End If
    On Error GoTo 0
End Function

Function IsOffice32BitInstalled()
    On Error Resume Next
    Dim objShell, path
    Set objShell = CreateObject("WScript.Shell")
    path = objShell.RegRead("HKLM\SOFTWARE\WOW6432Node\Microsoft\Office\16.0\Common\InstallRoot\Path")
    If path <> "" Then
        IsOffice32BitInstalled = True
    Else
        IsOffice32BitInstalled = False
    End If
    On Error GoTo 0
End Function

Function GetProcessMemoryUsage(processName)
    On Error Resume Next
    Dim objWMI, processes, process
    Set objWMI = GetObject("winmgmts:\\.\root\cimv2")
    Set processes = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & processName & "'")
    For Each process In processes
        GetProcessMemoryUsage = process.WorkingSetSize / 1024 / 1024
        Exit Function
    Next
    GetProcessMemoryUsage = 0
    On Error GoTo 0
End Function

Function GetExistingApp(progID)
    On Error Resume Next
    Dim app
    Set app = GetObject(, progID)
    If app Is Nothing Then
        Set app = CreateObject(progID)
    End If
    Set GetExistingApp = app
    On Error GoTo 0
End Function

Sub SafeQuit(ByRef appObject)
    On Error Resume Next
    If Not appObject Is Nothing Then
        appObject.Quit
        Set appObject = Nothing
    End If
    On Error GoTo 0
End Sub

Sub CloseInvisibleAppIfOverMemoryLimit(ByRef appObject, processName, memoryLimit)
    On Error Resume Next
    If Not appObject Is Nothing Then
        If Not appObject.Visible Then
            If GetProcessMemoryUsage(processName) > memoryLimit Then
                SafeQuit appObject
            End If
        End If
    End If
    On Error GoTo 0
End Sub

Dim windowsBuild, isOffice32Bit, wordApp, excelApp
Dim memoryLimit : memoryLimit = 150

windowsBuild = GetWindowsBuild()
isOffice32Bit = IsOffice32BitInstalled()

If windowsBuild >= 26100 And isOffice32Bit Then
    Do
        Set wordApp = GetExistingApp("Word.Application")
        Set excelApp = GetExistingApp("Excel.Application")

        If Not wordApp Is Nothing Then
            CloseInvisibleAppIfOverMemoryLimit wordApp, "WINWORD.EXE", memoryLimit
        End If

        If Not excelApp Is Nothing Then
            CloseInvisibleAppIfOverMemoryLimit excelApp, "EXCEL.EXE", memoryLimit
        End If

        WScript.Sleep 1000
    Loop
End If