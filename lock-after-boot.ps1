# Locks the workstation right after an automatic logon - but only when the
# machine booted less than 5 minutes ago, so a manual logon later in the day
# is not locked out from under the user.
#
# Boot time comes from the last Kernel-Boot event 27 in the System log, not
# from Win32_OperatingSystem.LastBootUpTime: Fast Startup is on here
# (HiberbootEnabled=1), and after a Fast Startup "shutdown" LastBootUpTime keeps
# the old date, while event 27 is written on every boot of either kind.
#
# Started from a shortcut in the user's Startup folder. Comments are in English
# on purpose - Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.

$log = 'C:\claude-remote\logs\lock.log'
$maxMinutes = 5

function Write-Log($msg) {
  $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $msg
  try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch {}
}

try {
  $boot = (Get-WinEvent -FilterHashtable @{
      LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Boot'; Id = 27
    } -MaxEvents 1 -ErrorAction Stop).TimeCreated
} catch {
  $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  Write-Log "event 27 unreadable, falling back to LastBootUpTime: $($_.Exception.Message)"
}

$minutes = [math]::Round(((Get-Date) - $boot).TotalMinutes, 1)

if ($minutes -lt $maxMinutes) {
  Write-Log "boot $boot ($minutes min ago) - locking"
  rundll32.exe user32.dll,LockWorkStation
} else {
  Write-Log "boot $boot ($minutes min ago) - not a fresh boot, leaving unlocked"
}
