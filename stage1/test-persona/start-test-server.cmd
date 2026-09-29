@echo off
rem Stage 1.3 - does a session opened from the phone inherit the server's
rem environment? Run by hand in a visible window; Ctrl+C to stop.
rem Works only in C:\claude-remote\test-persona (trusted 29/09/2026).
chcp 65001 >nul
set ARENA_PERSONA=test-yaniv
cd /d C:\claude-remote\test-persona
claude remote-control --name "בדיקה – שמות" --spawn=same-dir --capacity 1 --permission-mode default --debug-file C:\claude-remote\logs\test-persona-debug.log
