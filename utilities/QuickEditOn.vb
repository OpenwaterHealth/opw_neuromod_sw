Imports System
Imports System.IO
Imports System.Runtime.InteropServices
Imports Microsoft.Win32

Public Module MyApplication 

    Public Declare Function GetStdHandle Lib "kernel32" Alias "GetStdHandle" (ByVal nStdHandle As Long) As Long
    Public Declare Function GetConsoleMode Lib "kernel32" (ByVal hConsoleHandle As IntPtr, ByRef lpMode As Integer) As Integer
    Public Declare Function SetConsoleMode Lib "kernel32" (ByVal hConsoleHandle As Long, ByVal dwMode As Integer) As Integer

    Public Const STD_ERROR_HANDLE = -12&
    Public Const STD_INPUT_HANDLE = -10&
    Public Const STD_OUTPUT_HANDLE = -11&

    'Input
    Public Const ENABLE_EXTENDED_FLAGS = &h0080
    Public Const ENABLE_ECHO_INPUT = &h0004
    Public Const ENABLE_INSERT_MODE = &h0020
    Public Const ENABLE_LINE_INPUT = &h0002
    Public Const ENABLE_MOUSE_INPUT = &h0010
    Public Const ENABLE_PROCESSED_INPUT = &h0001
    Public Const ENABLE_QUICK_EDIT_MODE = &h0040
    Public Const ENABLE_WINDOW_INPUT = &h0008
    Public Const ENABLE_VIRTUAL_TERMINAL_INPUT = &h0200
    'Output
    Public Const ENABLE_PROCESSED_OUTPUT = &h0001
    Public Const ENABLE_WRAP_AT_EOL_OUTPUT = &h0002
    Public Const ENABLE_VIRTUAL_TERMINAL_PROCESSING = &h0004
    Public Const DISABLE_NEWLINE_AUTO_RETURN = &h0008
    Public Const ENABLE_LVB_GRID_WORLDWIDE = &h0010

Sub Main()
    Dim hIn as IntPtr
    Dim Ret as Integer
    hIn  = GetStdHandle(STD_INPUT_HANDLE)
    Ret = SetConsoleMode(hIn, 199)
        If Ret = 0 Then Console.WriteLine(Hex(Ret) & " - " & err.lastdllerror) Else Console.WriteLine("QuickEdit On")
    End Sub
End Module