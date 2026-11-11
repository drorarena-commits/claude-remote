@echo off
rem "יוני קומקס" - Remote Control server for C:\AGENT-COMAX-CLOAD (source: C:\claude-remote).
rem chcp 65001 must come first: cmd reads the rest of this file in the active
rem code page, and the Hebrew --name below is UTF-8.
rem --capacity 4: up to 4 phone sessions at once (Dror, 24/10/2026; was 3 from 14/10, 2
rem since 30/09 - a 3rd session opened in the cloud); --permission-mode auto: Comax runs
rem without asking (Dror, 30/09/2026). Deny rules come in stage 6.
rem --chrome: Claude in Chrome (Dror's own Chrome) for site/PIM work; the Comax
rem Chrome (CDP 9222) stays for Comax only.
rem --spawn=same-dir only - never worktree: runs\.lock, data\ and content\ do
rem not exist in a worktree copy.
rem
rem Power-cut recovery (11/11/2026): after a power cut the Wi-Fi can come up AFTER
rem the automatic logon, and a server that starts with no network may simply exit -
rem leaving the phone with nothing to talk to until someone is at the desk. So:
rem   1. wait up to ~5 minutes for api.anthropic.com before starting;
rem   2. if the server exits for any reason, start it again after 30 seconds.
rem Closing this window still stops it for good (the loop dies with the window).
rem Ctrl+C asks "Terminate batch job (Y/N)?" - Y stops, N restarts.
chcp 65001 >nul
cd /d C:\AGENT-COMAX-CLOAD

:wait_net
set /a tries=0
:wait_loop
curl.exe -s -o nul --max-time 5 https://api.anthropic.com >nul 2>&1 && goto run
set /a tries+=1
if %tries% geq 60 goto run
timeout /t 5 /nobreak >nul
goto wait_loop

:run
echo %date% %time% start (network waits: %tries%)>> C:\claude-remote\logs\yoni-start.log
claude remote-control --name "יוני קומקס" --spawn=same-dir --capacity 4 --permission-mode auto --chrome --debug-file C:\claude-remote\logs\yoni-debug.log
echo %date% %time% exited with code %errorlevel% - restarting in 30s>> C:\claude-remote\logs\yoni-start.log
timeout /t 30 /nobreak >nul
goto wait_net
