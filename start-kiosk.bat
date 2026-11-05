@echo off
setlocal

set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if not exist "%CHROME%" (
  echo Google Chrome was not found.
  echo Edit this file and set CHROME to the location of chrome.exe.
  pause
  exit /b 1
)

set "PROFILE=%~dp0chrome-profile"
start "" "%CHROME%" --kiosk --no-first-run --disable-session-crashed-bubble --disable-infobars --user-data-dir="%PROFILE%" "%~dp0index.html"
endlocal
