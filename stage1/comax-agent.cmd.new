@echo off
rem "יוני קומקס" - Remote Control server for C:\AGENT-COMAX-CLOAD (source: C:\claude-remote).
rem chcp 65001 must come first: cmd reads the rest of this file in the active
rem code page, and the Hebrew --name below is UTF-8.
rem --capacity 2: one session per phone; --permission-mode auto: Comax runs
rem without asking (Dror, 30/09/2026). Deny rules come in stage 6.
rem --chrome: Claude in Chrome (Dror's own Chrome) for site/PIM work; the Comax
rem Chrome (CDP 9222) stays for Comax only.
rem --spawn=same-dir only - never worktree: runs\.lock, data\ and content\ do
rem not exist in a worktree copy.
chcp 65001 >nul
cd /d C:\AGENT-COMAX-CLOAD
claude remote-control --name "יוני קומקס" --spawn=same-dir --capacity 2 --permission-mode auto --chrome --debug-file C:\claude-remote\logs\yoni-debug.log
