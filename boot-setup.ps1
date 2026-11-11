# boot-setup.ps1 - the two admin steps of "the store PC comes back by itself after a
# power cut" (11/11/2026). Run from an ELEVATED PowerShell:
#
#   powershell -ExecutionPolicy Bypass -File C:\claude-remote\boot-setup.ps1 -Step BitLocker
#   powershell -ExecutionPolicy Bypass -File C:\claude-remote\boot-setup.ps1 -Step Status
#   powershell -ExecutionPolicy Bypass -File C:\claude-remote\boot-setup.ps1 -Step AutoLogon
#
# The order is enforced HERE, in code, not in a document (Dror's rule since 29/09/2026,
# README.md: "no BitLocker - no automatic logon"): -Step AutoLogon refuses unless
#   1. C: is FullyEncrypted with protection On,
#   2. it has both a TPM protector and a recovery password, and
#   3. that recovery password was shown and typed back by a person (-Step BitLocker
#      records its protector ID - never the key itself - in logs\bitlocker-key-confirmed.txt).
# An automatic logon on an unencrypted disk means anyone who takes the box takes
# everything on it: .env, Comax password, WooCommerce keys, SSH key, WhatsApp session.
#
# The Windows password is never seen by this script or by the agent: Sysinternals
# Autologon asks for it in its own window and stores it as an LSA secret (no
# DefaultPassword in the registry).
#
# Comments and messages are in English on purpose - Windows PowerShell 5.1 reads a
# BOM-less .ps1 as ANSI, and the console shows Hebrew reversed.

param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('BitLocker', 'AutoLogon', 'Status')]
  [string]$Step
)

$ErrorActionPreference = 'Stop'
$root = 'C:\claude-remote'
$marker = Join-Path $root 'logs\bitlocker-key-confirmed.txt'
$autologonExe = Join-Path $root 'tools\Autologon64.exe'
$lockLnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\lock-after-boot.lnk'

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }
function Stop-With($msg) { Say "`nSTOPPED: $msg`n" Red; exit 1 }

$me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Stop-With 'run this from an elevated PowerShell (right-click > Run as administrator).'
}

function Get-RecoveryProtectors { @((Get-BitLockerVolume -MountPoint 'C:').KeyProtector | Where-Object KeyProtectorType -eq 'RecoveryPassword') }

function Show-Status {
  $v = Get-BitLockerVolume -MountPoint 'C:'
  $types = ($v.KeyProtector | ForEach-Object KeyProtectorType) -join ', '
  Say "`nBitLocker C:  status=$($v.VolumeStatus)  protection=$($v.ProtectionStatus)  encrypted=$($v.EncryptionPercentage)%  method=$($v.EncryptionMethod)"
  Say "              protectors: $(if ($types) { $types } else { '(none)' })"
  $w = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
  Say "Auto logon:   AutoAdminLogon=$($w.AutoAdminLogon)  user=$($w.DefaultUserName)  clear-text password in registry=$([bool]$w.DefaultPassword)"
  Say "Key marker:   $(if (Test-Path $marker) { Get-Content $marker -Raw } else { 'none - the recovery key was not confirmed yet' })"
  Say "Lock shortcut in Startup: $(Test-Path $lockLnk)`n"
  return $v
}

# ----------------------------------------------------------------------------- Status
if ($Step -eq 'Status') { Show-Status | Out-Null; exit 0 }

# ----------------------------------------------------------------------------- BitLocker
if ($Step -eq 'BitLocker') {
  $tpm = Get-Tpm
  if (-not $tpm.TpmPresent -or -not $tpm.TpmReady) { Stop-With "TPM not ready (present=$($tpm.TpmPresent) ready=$($tpm.TpmReady)). Enable fTPM in the BIOS first." }

  Say "`nBEFORE YOU CONTINUE" Yellow
  Say "  The BIOS setting 'Restore on AC Power Loss = Power On' should be set FIRST."
  Say "  Changing BIOS settings after BitLocker is on can make the next boot ask for the"
  Say "  recovery key (once). Not dangerous if the key is saved - just annoying."
  $ans = Read-Host "Is the BIOS power-loss setting already done? (y = continue / n = stop)"
  if ($ans -ne 'y') { Stop-With 'do the BIOS setting first, then run this again.' }

  $v = Get-BitLockerVolume -MountPoint 'C:'
  $hasTpm = @($v.KeyProtector | Where-Object KeyProtectorType -eq 'Tpm').Count -gt 0

  if ($v.VolumeStatus -eq 'FullyDecrypted' -and -not $hasTpm) {
    Say "`nTurning BitLocker on for C: (TPM, used space only, XTS-AES 128)..." Cyan
    Enable-BitLocker -MountPoint 'C:' -EncryptionMethod XtsAes128 -UsedSpaceOnly -TpmProtector -SkipHardwareTest | Out-Null
  } else {
    Say "`nBitLocker already started on C: ($($v.VolumeStatus)) - not starting it again." Cyan
    if (-not $hasTpm) { Add-BitLockerKeyProtector -MountPoint 'C:' -TpmProtector | Out-Null }
  }

  if ((Get-RecoveryProtectors).Count -eq 0) {
    Add-BitLockerKeyProtector -MountPoint 'C:' -RecoveryPasswordProtector | Out-Null
  }
  $rp = (Get-RecoveryProtectors)[0]
  $key = $rp.RecoveryPassword
  $blocks = $key -split '-'

  Say "`n================================================================" Yellow
  Say "  RECOVERY KEY - save it OUTSIDE this computer, now" Yellow
  Say "================================================================" Yellow
  Say "  Computer : $env:COMPUTERNAME (Beelink, store)"
  Say "  Key ID   : $($rp.KeyProtectorId)"
  Say ""
  Say "  $key" White
  Say ""
  Say "  Without it, a failed TPM / motherboard / some BIOS changes = the disk is lost."
  Say "  Good places (two of them): a photo or note in your password manager or phone,"
  Say "  and paper at home. NOT a file on C:, NOT only in Google Drive synced from here."
  Say "================================================================`n" Yellow

  $saveTo = Read-Host "Optional: drive letter of a USB stick to ALSO save a copy (e.g. D), or Enter to skip"
  if ($saveTo) {
    $letter = $saveTo.Trim().TrimEnd(':').ToUpper()
    if ($letter -eq 'C' -or -not (Test-Path "${letter}:\")) { Say "  Skipped: '$letter' is C: or does not exist." Red }
    else {
      $file = "${letter}:\BitLocker-Recovery-$env:COMPUTERNAME-$($rp.KeyProtectorId.Trim('{}').Substring(0,8)).txt"
      @("BitLocker recovery key", "Computer: $env:COMPUTERNAME", "Key ID: $($rp.KeyProtectorId)", "Saved: $(Get-Date -Format 'yyyy-MM-dd HH:mm')", '', $key) | Set-Content $file -Encoding ASCII
      Say "  Saved to $file - keep that stick away from the computer." Green
    }
  }

  # Proof that a person copied it: type back the first and the last block.
  for ($i = 1; $i -le 5; $i++) {
    $first = Read-Host "Type the FIRST block of 6 digits from where you saved it"
    $last = Read-Host "Type the LAST block of 6 digits"
    if ($first.Trim() -eq $blocks[0] -and $last.Trim() -eq $blocks[-1]) { break }
    Say "  Does not match - check what you saved and try again." Red
    if ($i -eq 5) { Stop-With 'the key was not confirmed. Encryption keeps running; run -Step BitLocker again to see the key.' }
  }

  New-Item -ItemType Directory -Force (Split-Path $marker) | Out-Null
  "confirmed $(Get-Date -Format 'yyyy-MM-dd HH:mm') by $env:USERNAME - protector $($rp.KeyProtectorId)" | Set-Content $marker -Encoding ASCII
  Say "`nKey confirmed. Encryption runs in the background; the computer can be used normally." Green
  Show-Status | Out-Null
  Say "NEXT: when status shows FullyEncrypted (usually minutes on this SSD), run -Step AutoLogon." Cyan
  exit 0
}

# ----------------------------------------------------------------------------- AutoLogon
if ($Step -eq 'AutoLogon') {
  $v = Show-Status
  $types = @($v.KeyProtector | ForEach-Object { "$($_.KeyProtectorType)" })
  if ($v.VolumeStatus -ne 'FullyEncrypted') { Stop-With "C: is $($v.VolumeStatus) ($($v.EncryptionPercentage)%). Wait for FullyEncrypted." }
  if ("$($v.ProtectionStatus)" -ne 'On') { Stop-With "BitLocker protection is $($v.ProtectionStatus), not On (suspended?). Resume-BitLocker -MountPoint C: first." }
  if ($types -notcontains 'Tpm' -or $types -notcontains 'RecoveryPassword') { Stop-With "protectors are '$($types -join ', ')' - need both Tpm and RecoveryPassword." }
  if (-not (Test-Path $marker)) { Stop-With 'the recovery key was never confirmed. Run -Step BitLocker (it shows the key again and asks you to type it back).' }
  $ids = (Get-RecoveryProtectors).KeyProtectorId
  if (-not ($ids | Where-Object { (Get-Content $marker -Raw) -match [regex]::Escape($_) })) {
    Stop-With 'the confirmed key is no longer on the disk (the recovery password changed). Run -Step BitLocker again.'
  }
  if (-not (Test-Path $lockLnk)) { Stop-With "lock-after-boot.lnk is missing from Startup - without it the screen stays open after the automatic logon." }

  # Windows 11 'only Windows Hello sign-in' (2) hides password logon; automatic logon needs 0.
  $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
  if ((Get-ItemProperty $pl -ErrorAction SilentlyContinue).DevicePasswordLessBuildVersion -ne 0) {
    Set-ItemProperty $pl -Name DevicePasswordLessBuildVersion -Value 0 -Type DWord
    Say "Set DevicePasswordLessBuildVersion=0 (password logon allowed)." Cyan
  }

  if (-not (Test-Path $autologonExe)) {
    New-Item -ItemType Directory -Force (Split-Path $autologonExe) | Out-Null
    Say "Downloading Sysinternals Autologon..." Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest 'https://live.sysinternals.com/Autologon64.exe' -OutFile $autologonExe -UseBasicParsing
  }
  $sig = Get-AuthenticodeSignature $autologonExe
  if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
    Remove-Item $autologonExe -Force
    Stop-With "Autologon64.exe signature is '$($sig.Status)' / '$($sig.SignerCertificate.Subject)' - deleted, not running it."
  }

  Say "`nA small 'Autologon' window opens now:" Yellow
  Say "  Username = user   Domain = $env:COMPUTERNAME   Password = your Windows password"
  Say "  then click ENABLE, then OK. (The password stays in that window - nobody else sees it.)"
  Start-Process $autologonExe -ArgumentList '/accepteula' -Wait

  $w = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
  if ($w.AutoAdminLogon -ne '1' -or $w.DefaultUserName -ne 'user') { Stop-With "automatic logon is not set (AutoAdminLogon=$($w.AutoAdminLogon), user=$($w.DefaultUserName)). Run -Step AutoLogon again and click Enable." }
  if ($w.DefaultPassword) { Stop-With 'a clear-text DefaultPassword is in the registry - remove it (Autologon > Disable, then Enable again).' }

  Say "`nDONE: automatic logon as 'user', password stored as an LSA secret, screen locks right after boot." Green
  Say "Next: restart once (Start > Power > Restart) and check that it comes back by itself, then: npm run boot-check" Cyan
  exit 0
}
