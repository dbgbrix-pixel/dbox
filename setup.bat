@echo off
setlocal EnableDelayedExpansion

:: 1. Auto-request Administrator privileges (required for DISM)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: 2. Force 640x480 window size & disable scrollbars (80 cols x 30 rows)
mode con: cols=80 lines=30
powershell -NoProfile -Command ^
  "$w = (Get-Host).UI.RawUI;" ^
  "$b = $w.BufferSize; $b.Width = 80; $b.Height = 30; $w.BufferSize = $b;" ^
  "$s = $w.WindowSize; $s.Width = 80; $s.Height = 30; $w.WindowSize = $s;"

:: Set Deep Blue background (1) and Bright White text (F)
color 1F
title Windows Setup

:: Verify dbox.wim exists before starting
set "BASE_DIR=%~dp0"
set "WIM_FILE=%BASE_DIR%dbox.wim"
set "TARGET_DIR=%BASE_DIR%dbox_sys"

if not exist "%WIM_FILE%" (
    color 4F
    cls
    echo.
    echo   [ERROR] Could not find dbox.wim next to setup.bat!
    pause
    exit /b
)

:: ============================================================================
:: PHASE 1: 20-second "Please wait..." with centered loading bar
:: ============================================================================
set "BAR="
for /L %%i in (1,1,20) do (
    set "BAR=!BAR!#"
    set "EMPTY="
    set /a REM=20-%%i
    for /L %%j in (1,1,!REM!) do set "EMPTY=!EMPTY!-"
    
    cls
    for /L %%n in (1,1,12) do echo.
    echo                                  Please wait...
    echo.
    echo                            [!BAR!!EMPTY!]
    timeout /t 1 /nobreak >nul
)

:: ============================================================================
:: PHASE 2: 10 seconds black screen ("configuring" appears after 1 second)
:: ============================================================================
color 07
cls
timeout /t 1 /nobreak >nul

cls
for /L %%n in (1,1,13) do echo.
echo                                  configuring
timeout /t 9 /nobreak >nul

:: ============================================================================
:: PHASE 3: Deep blue console, DBOX Title, Bahnschrift Light font
:: ============================================================================
color 1F
title DBOX

:: Switch console font to Bahnschrift Light (applies to classic conhost.exe)
reg add "HKCU\Console" /v "FaceName" /t REG_SZ /d "Bahnschrift Light" /f >nul 2>&1
powershell -NoProfile -Command ^
  "$code = '[DllImport(\"kernel32.dll\", SetLastError=true)] public static extern IntPtr GetStdHandle(int nStdHandle); [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct CONSOLE_FONT_INFOEX { public uint cbSize; public uint nFont; public short dwFontSizeX; public short dwFontSizeY; public int FontFamily; public int FontWeight; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string FaceName; } [DllImport(\"kernel32.dll\", SetLastError=true)] public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFOEX lpConsoleCurrentFontEx);';" ^
  "$t = Add-Type -MemberDefinition $code -Name 'FontHelper' -Namespace 'Win32' -PassThru;" ^
  "$h = $t::GetStdHandle(-11);" ^
  "$f = New-Object Win32.FontHelper+CONSOLE_FONT_INFOEX;" ^
  "$f.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($f);" ^
  "$f.dwFontSizeY = 16; $f.FontWeight = 300; $f.FaceName = 'Bahnschrift Light';" ^
  "$t::SetCurrentConsoleFontEx($h, $false, [ref]$f) | Out-Null;"

cls
for /L %%n in (1,1,12) do echo.
echo                                      DBOX
echo.
echo                       Please wait while we're getting ready

:: Prepare extraction folder
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

:: Start DISM extraction silently in the background & enforce at least 10s wait
powershell -NoProfile -Command ^
  "$sw = [System.Diagnostics.Stopwatch]::StartNew();" ^
  "$p = Start-Process -FilePath 'dism.exe' -ArgumentList '/Apply-Image','/ImageFile:\"%WIM_FILE%\"','/Index:1','/ApplyDir:\"%TARGET_DIR%\"' -WindowStyle Hidden -PassThru;" ^
  "$p.WaitForExit();" ^
  "$rem = 10000 - $sw.ElapsedMilliseconds;" ^
  "if ($rem -gt 0) { Start-Sleep -Milliseconds $rem }"

:: ============================================================================
:: PHASE 4: 3 seconds "Setting up BIOS"
:: ============================================================================
cls
for /L %%n in (1,1,12) do echo.
echo                                      DBOX
echo.
echo                                Setting up BIOS
timeout /t 3 /nobreak >nul

:: ============================================================================
:: PHASE 5: Create auto_create.bin and launch dbox_sys\dbox.exe (WITHOUT Admin)
:: ============================================================================
echo DBOX_AUTO_CREATE_TRIGGER=1>"%TARGET_DIR%\auto_create.bin"

if exist "%TARGET_DIR%\dbox.exe" (
    cd /d "%TARGET_DIR%"
    runas /trustlevel:0x20000 "%TARGET_DIR%\dbox.exe" >nul 2>&1
) else (
    color 4F
    cls
    echo.
    echo   [ERROR] Extraction finished, but dbox_sys\dbox.exe was not found!
    pause
)

exit /b

